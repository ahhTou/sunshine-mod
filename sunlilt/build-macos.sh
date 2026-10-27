#!/bin/sh
# 只构建独立 Sunlilt.app，不触碰正在运行的远控服务。
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
git submodule update --init --depth 1 third-party/build-deps third-party/lizardbyte-common \
  third-party/libdisplaydevice third-party/libvirtualhid third-party/moonlight-common-c \
  third-party/Simple-Web-Server third-party/TPCircularBuffer
git -C third-party/moonlight-common-c submodule update --init --depth 1 enet nanors
BRANCH=sunlilt BUILD_VERSION=0.1.0 cmake -S . -B cmake-build-sunlilt -G Ninja \
  -DBUILD_DOCS=OFF -DBUILD_TESTS=OFF -DSUNSHINE_ENABLE_TRAY=OFF -DCMAKE_BUILD_TYPE=Release \
  -DOPENSSL_ROOT_DIR="$(brew --prefix openssl)" -DOpus_ROOT_DIR="$(brew --prefix opus)" \
  -DSUNSHINE_PUBLISHER_NAME=ahhTou -DSUNSHINE_PUBLISHER_WEBSITE=https://ahhtou.wang \
  -DSUNSHINE_PUBLISHER_ISSUE_URL=https://github.com/ahhTou/sunlilt/issues "$@"
cmake --build cmake-build-sunlilt --target web-ui
cmake --build cmake-build-sunlilt --target sunshine -j "${SUNLILT_BUILD_JOBS:-4}"
codesign --force --sign - cmake-build-sunlilt/Sunlilt.app
printf '已构建：%s/cmake-build-sunlilt/Sunlilt.app\n' "$ROOT"
