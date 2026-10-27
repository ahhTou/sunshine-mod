# 0.1.0 验证记录

2026-10-27，本机 Apple Silicon M5 / macOS 27.0.1 / Xcode SDK 27。

## 内置编码策略 A/B/A

同一可执行文件直接链接 `src/platform/macos/vt_sync.mm`，没有 DYLD 加载变量。
使用同版本 FFmpeg 的硬件像素缓冲输入，1920×1080 / 60fps / H.264 / 7Mbps / 无 B 帧 / realtime / low_delay。
每轮完整输出 180 帧，首尾预热与排空不计，统计 155 帧。

| 模式 | 中位 | P95 | 输出帧 / 关键帧 |
|---|---:|---:|---:|
| 关闭同步完成 | 49.969 ms | 53.583 ms | 180 / 1 |
| 内置同步完成 | 4.770 ms | 4.894 ms | 180 / 1 |
| 再关闭 | 50.058 ms | 53.377 ms | 180 / 1 |

具体数据见 `tests/baseline-m5.json`。这是构建时记录，不代表所有机器或端到端输入延迟。
测试命令：`sh sunlilt/test-macos.sh`；结果写入忽略的构建目录。

## 其他验证

- 默认 / 显式 SCK、AVFoundation 回退、10-bit 回退的编译期断言通过。
- SCK 实现来自已实测的原型，之前验证 NV12 → BGRA → NV12 三轮生命周期正常。
- 本派生使用新 app 身份，未替用户授权或切换运行服务；新身份的录屏与输入功能要在实际部署授权后复核。
- 尚未运行完整上游测试套件，也未验证 Windows / Linux 或高分辨率高帧率吞吐。

## 完整项目构建与首次运行

- 完整 CMake 与 Web UI 构建通过，产物为 `Sunlilt.app`，bundle ID 为 `wang.ahhtou.sunlilt`。
- 首次运行资源核查发现上游开发构建缺少 macOS apps.json，已补入 POST_BUILD 资源复制；`Sunlilt --version` 正常输出 0.1.0。
- 内置编码入口已验证链接进主程序；从新项目自身运行 `sh sunlilt/test-macos.sh` 完整通过，复测约 50.0 → 4.7 → 50.0 ms。
- 构建时复用的是相同版本的 FFmpeg / Boost 缓存，通过 CMake 可选参数传入；仓库默认脚本会自行取得锁定依赖，不依赖该缓存路径。
