/** @file sck_frame_copy.m @brief 把 SCK 帧拷到自有缓冲池，原始帧立即还给系统。 */
#import "sck_frame_copy.h"

#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>

@implementation SCKFrameCopier {
  VTPixelTransferSessionRef _session;  ///< GPU 拷贝，NV12 / BGRA 都能直接搬。
  CVPixelBufferPoolRef _pool;  ///< 按当前尺寸和格式建的 IOSurface 池，尺寸变了重建。
  size_t _width, _height;
  OSType _format;
}

+ (BOOL)enabled {
  const char *v = getenv("SUNSHINE_MOD_SCK_COPY");
  return !(v && v[0] == '0');
}

- (BOOL)preparePoolFor:(CVPixelBufferRef)src {
  size_t w = CVPixelBufferGetWidth(src), h = CVPixelBufferGetHeight(src);
  OSType f = CVPixelBufferGetPixelFormatType(src);
  if (_pool && w == _width && h == _height && f == _format) {
    return YES;
  }
  if (_pool) {
    CVPixelBufferPoolRelease(_pool);
    _pool = NULL;
  }
  NSDictionary *attrs = @{
    (id) kCVPixelBufferWidthKey: @(w),
    (id) kCVPixelBufferHeightKey: @(h),
    (id) kCVPixelBufferPixelFormatTypeKey: @(f),
    (id) kCVPixelBufferIOSurfacePropertiesKey: @{},
    (id) kCVPixelBufferMetalCompatibilityKey: @YES,
  };
  if (CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (CFDictionaryRef) attrs, &_pool) != kCVReturnSuccess) {
    _pool = NULL;
    return NO;
  }
  _width = w;
  _height = h;
  _format = f;
  NSLog(@"[SCK] 帧拷贝池：%zux%zu，像素格式 %u", w, h, (unsigned) f);
  return YES;
}

- (CMSampleBufferRef)copySample:(CMSampleBufferRef)sample {
  CVPixelBufferRef src = CMSampleBufferGetImageBuffer(sample);
  if (!src || ![self preparePoolFor:src]) {
    return NULL;
  }
  if (!_session && VTPixelTransferSessionCreate(kCFAllocatorDefault, &_session) != noErr) {
    _session = NULL;
    return NULL;
  }
  CVPixelBufferRef dst = NULL;
  if (CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _pool, &dst) != kCVReturnSuccess) {
    return NULL;
  }
  CMSampleBufferRef out = NULL;
  CMVideoFormatDescriptionRef desc = NULL;
  CMSampleTimingInfo timing;
  if (VTPixelTransferSessionTransferImage(_session, src, dst) == noErr) {
    CVBufferPropagateAttachments(src, dst);  // 带上色彩空间等附件，编码端按原样识别
    if (CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, dst, &desc) == noErr &&
        CMSampleBufferGetSampleTimingInfo(sample, 0, &timing) == noErr) {
      CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, dst, desc, &timing, &out);
    }
  }
  if (desc) {
    CFRelease(desc);
  }
  CVPixelBufferRelease(dst);
  return out;
}

- (void)dealloc {
  if (_session) {
    VTPixelTransferSessionInvalidate(_session);
    CFRelease(_session);
  }
  if (_pool) {
    CVPixelBufferPoolRelease(_pool);
  }
  [super dealloc];
}

@end
