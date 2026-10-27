/** @file sck_video.h @brief Sunshine 的可选 ScreenCaptureKit 采集器。 */
#pragma once
#import "av_video.h"

/** @brief 保留 AVVideo 对外接口，编码与输入路径沿用上游实现。 */
@interface SCKVideo: AVVideo
@end

/** @brief 无监听端口的权限检查与采集生命周期自检入口。 */
int sunshine_sck_diagnostic(const char *mode);
