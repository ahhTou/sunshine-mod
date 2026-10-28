/**
 * @file tests/unit/test_macos_session.cpp
 * @brief 本机桌面会话恢复的回归测试，不改变真实桌面。
 */

// test includes
#include "../tests_common.h"

// local includes
#include "src/platform/macos/session_state.h"

namespace {
  /** @brief 记录桌面操作并模拟指针被其他程序重新显示。 */
  struct desktop_t: platf::session::desktop_t {
    bool visible = true;  ///< 模拟系统可见状态。
    bool hide_succeeds = true;  ///< 模拟 API 失败。
    int hides = 0;  ///< 隐藏调用次数。
    int shows = 0;  ///< 显示调用次数。
    int moves = 0;  ///< 程序坞调整次数。
    int restores = 0;  ///< 程序坞恢复次数。
    int position = 0;  ///< 目标位置。

    bool hide_cursor() override {
      ++hides;
      if (hide_succeeds) {
        visible = false;
      }
      return hide_succeeds;
    }

    bool cursor_visible() override {
      return visible;
    }

    void show_cursor() override {
      ++shows;
    }

    void move_dock(int target) override {
      ++moves;
      position = target;
    }

    void restore_dock() override {
      ++restores;
    }
  };
}  // namespace

/** @brief 多次开始或停止通知不应重复更改桌面。 */
TEST(MacSessionTest, RepeatedNotificationsPreserveOriginalState) {
  desktop_t desktop;
  platf::session::state_t state(desktop);
  state.stop();
  state.start(true, 4);
  state.start(true, 3);
  state.tick();
  EXPECT_EQ(desktop.hides, 1);
  EXPECT_EQ(desktop.moves, 1);
  EXPECT_EQ(desktop.position, 4);
  state.stop();
  state.stop();
  EXPECT_EQ(desktop.shows, 1);
  EXPECT_EQ(desktop.restores, 1);
}

/** @brief 全部关闭时不隐藏指针、不调整程序坞，下轮可使用不同选项。 */
TEST(MacSessionTest, DisabledSettingsAndReconnect) {
  desktop_t desktop;
  platf::session::state_t state(desktop);
  state.start(false, 0);
  state.tick();
  state.stop();
  EXPECT_EQ(desktop.hides, 0);
  EXPECT_EQ(desktop.moves, 0);
  EXPECT_EQ(desktop.shows, 0);
  for (int position : {2, 3, 4}) {
    state.start(true, position);
    EXPECT_EQ(desktop.position, position);
    state.stop();
  }
  EXPECT_EQ(desktop.moves, 3);
  EXPECT_EQ(desktop.hides, 3);
  EXPECT_EQ(desktop.shows, 3);
}

/** @brief 外部显示指针后再次隐藏，结束只配平自己持有的次数。 */
TEST(MacSessionTest, RehidesVisibleCursorAndBalancesOwnCalls) {
  desktop_t desktop;
  platf::session::state_t state(desktop);
  state.start(true, 0);
  desktop.visible = true;
  state.tick();
  state.tick();
  state.stop();
  EXPECT_EQ(desktop.hides, 2);
  EXPECT_EQ(desktop.shows, 2);
  state.tick();
  EXPECT_EQ(desktop.hides, 2);
}

/** @brief 系统拒绝隐藏时不调用反向显示，不接受无效程序坞位置。 */
TEST(MacSessionTest, FailedHideAndInvalidDockDoNotClaimState) {
  desktop_t desktop;
  desktop.hide_succeeds = false;
  platf::session::state_t state(desktop);
  state.start(true, 1);
  state.tick();
  state.stop();
  EXPECT_EQ(desktop.hides, 2);
  EXPECT_EQ(desktop.shows, 0);
  EXPECT_EQ(desktop.moves, 0);
}
