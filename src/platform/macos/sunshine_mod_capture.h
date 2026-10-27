/** @file sunshine_mod_capture.h @brief 派生版的采集选择，保留上游兼容回退。 */
#pragma once
#include <string_view>
namespace sunshine_mod {
  /** @brief 只有默认 / 显式 SCK 的 8-bit 流使用新采集；其余交还上游。 */
  constexpr bool use_sck(std::string_view capture, int depth) {
    return depth == 8 && (capture.empty() || capture == "sck");
  }
}
