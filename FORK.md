# 派生与维护说明

2026-10-27 · SunshineMod 0.1.0 开发版。

- 上游：LizardByte/Sunshine。
- 基线：v2026.914.233613，提交 `63d35f702ee9e362e43263742981836ec0710384`。
- 本地分支：codex/sunshine-mod；upstream 指向官方仓库，origin 指向 https://github.com/ahhTou/sunshine-mod。
- 保留上游 Git 提交与 GPL 许可证、各子模块原始许可。已从上游补齐基线之前的提交历史。

## 本次移入

`src/platform/macos/sck_video.*` 提供 SCK 采集；`sunshine_mod_capture.h` 选择 8-bit 默认路径；`vt_sync.mm` 将每帧同步完成策略编入可执行文件，并通过 RTLD_NEXT 调用系统原函数。

`sunshine-mod/` 放派生版构建、回归测试与验证记录，不依赖个人站点仓库或 /tmp 中的源码。

未移入个人站点的三端监控、分段日志、服务器配置、账户、令牌、配对资料、运行目录或二进制。当前正在使用的远控服务不因代码迁移而切换。

## 升级与限制

- 合并上游前重点复核 AVVideo 回调契约、VideoToolbox / FFmpeg 帧输出方式与 PTS。
- 同步完成会阻塞当前编码调用；在更高分辨率 / 帧率上必须重新验证吞吐。
- 10-bit / HDR 尚未迁到 SCK；保留原采集。
- 现有上游 UI、协议路径和配置文件名不做全局替换。
- 新 app 签名身份与旧版不同，授权和实际部署应在原远程连接仍可用时安排。
