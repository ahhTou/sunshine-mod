# Sunshine Mod

Sunshine 的个人小改版，主要优化 macOS 屏幕采集与编码延迟，让远程桌面更跟手。

基于 [LizardByte/Sunshine](https://github.com/LizardByte/Sunshine) `master` 提交 `d0b4a88e`（原始改版基于 `v2026.914.233613`），保留完整主机端源码与上游 Git 关系。它是 Moonlight 协议的被控端，可搭配 Moonlight 或 moonlight-web 使用。

## 主要改动

- **ScreenCaptureKit 采集**：8-bit 默认用 SCK，按编码端所需尺寸直接出 NV12，queueDepth=2；10-bit 暂保留上游 AVFoundation。
- **当前帧同步完成**：VideoToolbox 提交后完成到当前 PTS 再交回 FFmpeg，避免硬件像素输入路径积累后续帧等待。策略编入程序，不需要额外 dylib 或 DYLD 环境。
- **可回退**：配置 `capture = avfoundation` 使用原采集；环境变量 `SUNSHINE_MOD_VT_SYNC=0` 关闭当前帧同步完成。
- **独立身份**：`SunshineMod.app` / `wang.ahhtou.sunshine-mod`；macOS 配置目录 `~/.config/sunshine-mod/`，配置文件名继续使用 `sunshine.conf`。
- **采集自检**：保留不启动服务的权限检查与 NV12 / BGRA 连续启停自检。

## 当前验证范围

Apple Silicon、macOS 27、1080p / 60fps H.264，源屏幕可为 4K HiDPI。其他平台继承上游源码，但本派生改动没有在 Windows / Linux 验证；不把这些平台标为已支持的新发行版。

此前生产试用的 4793 帧分段计时中，编码提交到取包的中位数由约 **52ms 降到 6.5ms**；这是特定设备的编码链路数据，不是对所有设备的端到端延迟承诺。迁入本仓库后另有内置实现的硬件输入 A/B/A 基准，见 [验证记录](sunshine-mod/VALIDATION.md)。

## 构建

```sh
brew install cmake ninja pkgconf miniupnpc openssl opus
sh sunshine-mod/build-macos.sh
```

需要 Xcode 或 Command Line Tools、Node.js 22.16 以上。首次构建会下载锁定的子模块、Boost 与 FFmpeg；Boost 使用上游锁定版本，避免 Homebrew 静态库的附带链接差异。

产物：`cmake-build-sunshine-mod/SunshineMod.app`。脚本只构建，不安装、重启或覆盖正在使用的 Sunshine。

首次使用在 macOS「隐私与安全性」中为 SunshineMod 分别授予「屏幕与系统录音」和「辅助功能」。SunshineMod 与 Sunshine 使用相同默认端口，不要同时正常启动两者。

```sh
# 不监听端口，不修改配对
open -W -n cmake-build-sunshine-mod/SunshineMod.app --args --sck-permissions
open -W -n cmake-build-sunshine-mod/SunshineMod.app --args --sck-self-test
cat /private/tmp/sunshine-mod-diagnostic.json
# 默认配置目录中的配置项；新程序不会自动复制旧的用户或配对文件
# capture = avfoundation
```

本次升级建议使用独立构建缓存：

```sh
SUNSHINE_MOD_BUILD_DIR=cmake-build-sunshine-mod-upgrade sh sunshine-mod/build-macos.sh
SUNSHINE_MOD_BUILD_DIR=cmake-build-sunshine-mod-upgrade sh sunshine-mod/test-macos.sh
```

升级内容与验证范围见 [升级记录](sunshine-mod/UPGRADE-20261027.md)。

## 回归测试

```sh
sh sunshine-mod/test-macos.sh
```

开发构建仍动态依赖本机 Homebrew 库，当前没有发布可分发的签名安装包。

## 来源与许可

这是独立维护的派生版，原作者为 LizardByte 与 Sunshine 贡献者，不代表上游官方发行。
保留原版权与 [GPL-3.0-only 许可证](LICENSE)。上游介绍见 [README.upstream.md](README.upstream.md)，差异和维护边界见 [FORK.md](FORK.md)。

上游发布工作流归档在 `docs/upstream-workflows/`，不会在新仓库自动触发上游的多平台发布。管理页面的部分上游名称与技术标识保留，以维持兼容性。
