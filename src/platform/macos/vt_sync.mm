/** @file vt_sync.mm @brief 将每帧完成策略编入程序，消除硬件输入的批量等待。 */
#import <VideoToolbox/VideoToolbox.h>
#include <dlfcn.h>
#include <atomic>
#include <cstdlib>
#include <cstdio>

/** @brief 保留系统提交函数，完成到本帧 PTS 后再交回 FFmpeg；不会终止会话。 */
extern "C" OSStatus VTCompressionSessionEncodeFrame(VTCompressionSessionRef session, CVImageBufferRef image,
    CMTime pts, CMTime duration, CFDictionaryRef properties, void *source, VTEncodeInfoFlags *flags) {
  using Encode = OSStatus (*)(VTCompressionSessionRef,CVImageBufferRef,CMTime,CMTime,CFDictionaryRef,void *,VTEncodeInfoFlags *);
  static Encode original = reinterpret_cast<Encode>(dlsym(RTLD_NEXT, "VTCompressionSessionEncodeFrame"));
  if (!original) return kVTInvalidSessionErr;
  OSStatus result = original(session,image,pts,duration,properties,source,flags);
  const char *setting = std::getenv("SUNLILT_VT_SYNC");
  if (result || (setting && setting[0] == '0')) return result;
  result = VTCompressionSessionCompleteFrames(session,pts);
  static std::atomic<bool> announced{false};
  if (!announced.exchange(true)) std::fprintf(stderr,"[Sunlilt] 当前帧同步完成，状态=%d\n",(int)result);
  return result;
}
