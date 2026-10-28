/** @file sck_frame_copy.h @brief 把 SCK 帧拷到自有缓冲池，原始帧立即还给系统。 */
#pragma once
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

/**
 * @brief SCK 只有 queueDepth 个画面缓冲，Sunshine 的图像槽会一直持有交出去的帧直到复用（闲置 3 秒才回收），
 * 切窗口等突发时缓冲被占满，SCK 交不出新帧。这里用 GPU 拷一份交给下游，SCK 的缓冲当场释放。
 */
@interface SCKFrameCopier: NSObject
/** @brief 环境变量 SUNSHINE_MOD_SCK_COPY=0 关闭，其余情况开启。 */
+ (BOOL)enabled;
/** @brief 返回 +1 引用的拷贝；失败返回 NULL，调用方退回原帧。 */
- (CMSampleBufferRef)copySample:(CMSampleBufferRef)sample CF_RETURNS_RETAINED;
@end
