/**
 * @file src/platform/macos/session.h
 * @brief macOS 推流期间的桌面设置及恢复。
 */
#pragma once

// standard includes
#include <memory>

// local includes
#include "src/platform/common.h"

namespace platf::session {
  /** @brief 启动桌面设置线程，并在退出时停止及恢复。 */
  std::unique_ptr<deinit_t> init();
  /** @brief 设置是否正在推流，由首个连接及最后一个断开的回调调用。 */
  void set_streaming(bool active);
}  // namespace platf::session
