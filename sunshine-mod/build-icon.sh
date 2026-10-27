#!/bin/sh
# 使用 Apple 资产编译器生成分层图标及旧版 macOS 的 ICNS。
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${1:-$ROOT/cmake-build-sunshine-mod}"
mkdir -p "$BUILD_DIR/icon-compiled"
xcrun actool "$ROOT/src_assets/macos/SunshineMod.icon" \
  --compile "$BUILD_DIR/icon-compiled" --platform macosx \
  --minimum-deployment-target 14.0 --app-icon SunshineMod \
  --output-partial-info-plist "$BUILD_DIR/icon-compiled/partial.plist" \
  --output-format human-readable-text --warnings --notices
