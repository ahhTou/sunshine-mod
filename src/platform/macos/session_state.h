/**
 * @file src/platform/macos/session_state.h
 * @brief 可用替身验证的桌面会话状态机。
 */
#pragma once

namespace platf::session {
  /** @brief 桌面操作的可替换接口。 */
  struct desktop_t {
    /** @brief 释放桌面操作对象。 */
    virtual ~desktop_t() = default;
    /** @brief 隐藏一次指针；返回系统是否接受。 */
    virtual bool hide_cursor() = 0;
    /** @brief 指针当前是否可见。 */
    virtual bool cursor_visible() = 0;
    /** @brief 配平本会话持有的一次隐藏计数。 */
    virtual void show_cursor() = 0;
    /** @brief 先持久保存原位置，再调整程序坞。 */
    virtual void move_dock(int position) = 0;
    /** @brief 恢复程序坞；失败时保留恢复记录。 */
    virtual void restore_dock() = 0;
  };

  /** @brief 保证只恢复本会话拥有的指针计数及程序坞状态。 */
  class state_t {
  public:
    /** @brief 绑定系统操作，不立即改变桌面。 */
    explicit state_t(desktop_t &desktop):
        desktop_(desktop) {}

    /** @brief 推流开始，重复通知不会覆盖原位置或累加隐藏计数。 */
    void start(bool hide, int dock) {
      if (active_) {
        return;
      }
      active_ = true;
      hide_ = hide;
      if (dock >= 2 && dock <= 4) {
        desktop_.move_dock(dock);
      }
      tick();
    }

    /** @brief 处理其他程序重新显示指针的情况，记录本进程每次成功隐藏。 */
    void tick() {
      if (active_ && hide_ && (hidden_ == 0 || desktop_.cursor_visible())) {
        if (desktop_.hide_cursor()) {
          ++hidden_;
        }
      }
    }

    /** @brief 最后一个连接结束或程序退出时恢复，重复调用安全。 */
    void stop() {
      if (!active_) {
        return;
      }
      while (hidden_ > 0) {
        desktop_.show_cursor();
        --hidden_;
      }
      desktop_.restore_dock();
      active_ = false;
    }

  private:
    desktop_t &desktop_;  ///< 系统操作。
    bool active_ = false;  ///< 是否已经应用本轮设置。
    bool hide_ = false;  ///< 本轮是否启用本机隐藏。
    unsigned hidden_ = 0;  ///< 本进程成功持有的隐藏计数。
  };
}  // namespace platf::session
