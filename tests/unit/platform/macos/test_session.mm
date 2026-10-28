/**
 * @file tests/unit/platform/macos/test_session.mm
 * @brief 显式启用的真实桌面恢复检查；默认不改变开发者桌面。
 */

// test includes
#include "../../../tests_common.h"

// standard includes
#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <thread>

// platform includes
#import <Cocoa/Cocoa.h>
#include <dlfcn.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

// local includes
#include "src/config.h"
#include "src/platform/macos/session.h"

/** @brief 空闲桌面上验证真实系统 API，不允许干扰正在推流的会话。 */
TEST(MacSessionNativeTest, RestoresRealDesktopWhenExplicitlyEnabled) {
  if (!std::getenv("SUNSHINE_MOD_DESKTOP_TEST")) {
    GTEST_SKIP() << "真实桌面检查需显式设置 SUNSHINE_MOD_DESKTOP_TEST=1";
  }
  @autoreleasepool {
    CFDictionaryRef assertions = nullptr;
    ASSERT_EQ(IOPMCopyAssertionsByProcess(&assertions), kIOReturnSuccess);
    bool capturing = false;
    for (NSArray *items in [(__bridge NSDictionary *) assertions allValues]) {
      for (NSDictionary *item in items) {
        if ([item[(__bridge NSString *) kIOPMAssertionNameKey] isEqual:@"Sunshine display capture"]) {
          capturing = true;
        }
      }
    }
    CFRelease(assertions);
    if (capturing || !CGCursorIsVisible()) {
      GTEST_SKIP() << "当前存在采集或其他程序隐藏了指针，保留用户桌面";
    }
    void *library = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY);
    ASSERT_NE(library, nullptr);
    auto get = reinterpret_cast<void (*)(int *, int *)>(dlsym(library, "CoreDockGetOrientationAndPinning"));
    ASSERT_NE(get, nullptr);
    int original = 0, pin = 0;
    get(&original, &pin);
    auto config_path = config::sunshine.config_file;
    auto hide = config::video.macos_hide_cursor;
    auto dock = config::video.macos_dock_position;
    auto directory = std::filesystem::temp_directory_path() / "sunshine-mod-native-desktop-test";
    std::filesystem::create_directories(directory);
    config::sunshine.config_file = (directory / "sunshine.conf").string();
    config::video.macos_hide_cursor = true;
    config::video.macos_dock_position = original == 4 ? 3 : 4;
    bool hidden = false, moved = false;
    {
      auto guard = platf::session::init();
      platf::session::set_streaming(true);
      for (int i = 0; i < 20; ++i) {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        int position = 0, alignment = 0;
        get(&position, &alignment);
        hidden = !CGCursorIsVisible();
        moved = position == config::video.macos_dock_position;
        if (hidden && moved) {
          break;
        }
      }
      platf::session::set_streaming(false);
      std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
    int restored = 0, restored_pin = 0;
    get(&restored, &restored_pin);
    bool visible = CGCursorIsVisible();
    bool state_removed = !std::filesystem::exists(directory / "session-dock.plist");
    config::sunshine.config_file = config_path;
    config::video.macos_hide_cursor = hide;
    config::video.macos_dock_position = dock;
    dlclose(library);
    EXPECT_TRUE(hidden);
    EXPECT_TRUE(moved);
    EXPECT_TRUE(visible);
    EXPECT_EQ(restored, original);
    EXPECT_EQ(restored_pin, pin);
    EXPECT_TRUE(state_removed);
    if (state_removed) {
      std::filesystem::remove(directory);
    }
  }
}
