/**
 * @file src/platform/macos/session.mm
 * @brief 随 Sunshine 推流连接应用、恢复本机指针与程序坞设置。
 */

// standard includes
#include <chrono>
#include <condition_variable>
#include <filesystem>
#include <mutex>
#include <thread>

// platform includes
#import <Cocoa/Cocoa.h>
#include <dlfcn.h>

// local includes
#include "session.h"
#include "session_state.h"
#include "src/config.h"
#include "src/logging.h"

namespace platf::session {
  namespace {
    /** @brief macOS 桌面操作；私有符号不可用时记录错误，不阻止推流。 */
    class native_desktop_t: public desktop_t {
    public:
      /** @brief 解析私有 API，并使用当前配置目录存储恢复记录。 */
      native_desktop_t() {
        sky_ = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
        services_ = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY);
        if (sky_) {
          connection_ = reinterpret_cast<connection_fn>(dlsym(sky_, "_CGSDefaultConnection"));
          property_ = reinterpret_cast<property_fn>(dlsym(sky_, "CGSSetConnectionProperty"));
        }
        if (services_) {
          get_dock_ = reinterpret_cast<get_dock_fn>(dlsym(services_, "CoreDockGetOrientationAndPinning"));
          set_dock_ = reinterpret_cast<set_dock_fn>(dlsym(services_, "CoreDockSetOrientationAndPinning"));
        }
        auto path = std::filesystem::path(config::sunshine.config_file).parent_path() / "session-dock.plist";
        path_ = [[NSString alloc] initWithUTF8String:path.c_str()];
      }

      /** @brief 释放动态库；指针与程序坞已由状态机恢复。 */
      ~native_desktop_t() override {
        [path_ release];
        if (services_) {
          dlclose(services_);
        }
        if (sky_) {
          dlclose(sky_);
        }
      }

      bool hide_cursor() override {
        if (!connection_ || !property_) {
          return false;
        }
        int c = connection_();
        if (property_(c, c, CFSTR("SetsCursorInBackground"), kCFBooleanTrue) != kCGErrorSuccess) {
          return false;
        }
        return CGDisplayHideCursor(kCGDirectMainDisplay) == kCGErrorSuccess;
      }

      bool cursor_visible() override {
        return CGCursorIsVisible();
      }

      void show_cursor() override {
        CGDisplayShowCursor(kCGDirectMainDisplay);
      }

      void move_dock(int position) override {
        if (!get_dock_ || !set_dock_) {
          BOOST_LOG(warning) << "程序坞私有 API 不可用，保持原位置";
          return;
        }
        // 启动后残留的记录必须先恢复，不能覆盖最初的位置。
        restore_dock();
        if ([[NSFileManager defaultManager] fileExistsAtPath:path_]) {
          BOOST_LOG(warning) << "程序坞恢复记录尚未清除，本轮不修改位置";
          return;
        }
        int orientation = 0, pinning = 0;
        get_dock_(&orientation, &pinning);
        if (orientation == position) {
          return;
        }
        if (orientation < 1 || orientation > 4 || pinning < 1 || pinning > 3) {
          BOOST_LOG(warning) << "程序坞返回无效位置，保持原设置";
          return;
        }
        NSDictionary *saved = @{@"orientation": @(orientation),
                                @"pinning": @(pinning)};
        if (![saved writeToFile:path_ atomically:YES]) {
          BOOST_LOG(warning) << "无法保存程序坞恢复记录，保持原位置";
          return;
        }
        set_dock_(position, 0);
        BOOST_LOG(info) << "推流程序坞位置已调整为 " << position;
      }

      void restore_dock() override {
        if (!get_dock_ || !set_dock_) {
          return;
        }
        NSDictionary *saved = [NSDictionary dictionaryWithContentsOfFile:path_];
        if (!saved) {
          return;
        }
        int orientation = [saved[@"orientation"] intValue];
        int pinning = [saved[@"pinning"] intValue];
        if (orientation < 1 || orientation > 4 || pinning < 1 || pinning > 3) {
          return;
        }
        set_dock_(orientation, pinning);
        // CoreDock 更新是异步的，不能在设置后的第一次查询就判定恢复失败。
        for (int attempt = 0; attempt < 40; ++attempt) {
          int actual = 0, actual_pin = 0;
          get_dock_(&actual, &actual_pin);
          if (actual == orientation && actual_pin == pinning) {
            [[NSFileManager defaultManager] removeItemAtPath:path_ error:nil];
            return;
          }
          std::this_thread::sleep_for(std::chrono::milliseconds(25));
        }
        BOOST_LOG(warning) << "程序坞恢复未完成，保留记录供下次启动重试";
      }

    private:
      using connection_fn = int (*)();  ///< 默认窗口服务器连接。
      using property_fn = CGError (*)(int, int, CFStringRef, CFTypeRef);  ///< 连接属性设置。
      using get_dock_fn = void (*)(int *, int *);  ///< 查询程序坞位置。
      using set_dock_fn = void (*)(int, int);  ///< 设置程序坞位置。
      void *sky_ = nullptr;  ///< SkyLight 动态库。
      void *services_ = nullptr;  ///< ApplicationServices 动态库。
      connection_fn connection_ = nullptr;  ///< 连接函数。
      property_fn property_ = nullptr;  ///< 属性函数。
      get_dock_fn get_dock_ = nullptr;  ///< 查询函数。
      set_dock_fn set_dock_ = nullptr;  ///< 设置函数。
      NSString *path_ = nil;  ///< 原程序坞位置恢复记录。
    };

    std::mutex mutex;  ///< 串行化连接通知与停止请求。
    std::condition_variable changed;  ///< 唤醒桌面设置线程。
    bool streaming = false;  ///< 是否至少存在一个推流会话。
    bool quitting = false;  ///< 是否正在退出。

    /** @brief 生命周期由平台初始化对象持有，不依赖采集器或电源断言。 */
    class guard_t: public deinit_t {
    public:
      /** @brief 启动唯一的桌面设置线程。 */
      guard_t():
          worker_([] {
            @autoreleasepool {
              native_desktop_t desktop;
              state_t state(desktop);
              desktop.restore_dock();
              std::unique_lock lock(mutex);
              bool applied = false;
              while (!quitting) {
                if (streaming && !applied) {
                  state.start(config::video.macos_hide_cursor, config::video.macos_dock_position);
                } else if (!streaming && applied) {
                  state.stop();
                }
                applied = streaming;
                state.tick();
                changed.wait_for(lock, std::chrono::milliseconds(250));
              }
              state.stop();
            }
          }) {}

      /** @brief 正常退出时同步恢复桌面，等待线程结束。 */
      ~guard_t() override {
        {
          std::lock_guard lock(mutex);
          quitting = true;
        }
        changed.notify_all();
        worker_.join();
      }

    private:
      std::thread worker_;  ///< 桌面设置线程。
    };
  }  // namespace

  std::unique_ptr<deinit_t> init() {
    {
      std::lock_guard lock(mutex);
      streaming = false;
      quitting = false;
    }
    return std::make_unique<guard_t>();
  }

  void set_streaming(bool active) {
    {
      std::lock_guard lock(mutex);
      streaming = active;
    }
    changed.notify_all();
  }
}  // namespace platf::session
