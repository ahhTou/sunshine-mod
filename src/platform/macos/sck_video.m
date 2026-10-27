/** @file sck_video.m @brief 将 SCStream 的 IOSurface 帧交给 Sunshine 现有编码链路。 */
#import "sck_video.h"
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <QuartzCore/QuartzCore.h>
#import <ApplicationServices/ApplicationServices.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

/** @brief 一次独立采集的状态，所有可变状态只在串行队列访问。 */
@interface SCKRun : NSObject <SCStreamOutput, SCStreamDelegate>
@property(nonatomic, readonly) dispatch_semaphore_t signal; ///< 采集彻底停止后通知 Sunshine。
/** @brief 创建采集轮次并异步启动，回调返回 false 时停止。 */
- (id)initWithDisplay:(CGDirectDisplayID)display width:(int)width height:(int)height
              format:(OSType)format interval:(CMTime)interval callback:(FrameCallbackBlock)callback;
@end

@implementation SCKRun {
  SCStream *_stream; ///< 当前 SCK 流。
  dispatch_queue_t _queue; ///< 串行控制与回调队列。
  dispatch_source_t _timer; ///< 静止画面的保活与启动超时检查。
  dispatch_semaphore_t _signal; ///< 停止完成信号。
  FrameCallbackBlock _callback; ///< 上游持有图像的回调。
  CMSampleBufferRef _latest; ///< 静止画面时重复交付的最后一帧。
  BOOL _finished; ///< 已进入停止流程。
  double _started, _lastDelivered; ///< 单调时钟，单位秒。
  double _interval; ///< 请求帧间隔。
  IOPMAssertionID _powerAssertion; ///< 沿用 moonsession 识别的推流断言。
}
@synthesize signal = _signal;

/** @brief 清理流后再发信号，避免调用方析构时仍有帧回调。 */
- (void)finish:(NSString *)reason {
  if (_finished) return;
  _finished = YES;
  if (reason) NSLog(@"[SCK] %@", reason);
  dispatch_source_cancel(_timer);
  dispatch_source_set_event_handler(_timer, nil);
  dispatch_release(_timer); _timer = NULL;
  void (^cleanup)(void) = ^{
    if (self->_powerAssertion) { IOPMAssertionRelease(self->_powerAssertion); self->_powerAssertion = 0; }
    if (self->_latest) { CFRelease(self->_latest); self->_latest = NULL; }
    [self->_callback release]; self->_callback = nil;
    [self->_stream release]; self->_stream = nil;
    dispatch_semaphore_signal(self->_signal);
  };
  if (_stream) {
    [_stream stopCaptureWithCompletionHandler:^(NSError *error) {
      dispatch_async(self->_queue, cleanup);
    }];
  } else cleanup();
}

/** @brief 即时交付新帧；静止时的重复帧同样让 Sunshine 有机会结束会话。 */
- (void)deliver:(CMSampleBufferRef)sample {
  if (_finished) return;
  _lastDelivered = CACurrentMediaTime();
  if (!_callback(sample)) [self finish:nil];
}

- (id)initWithDisplay:(CGDirectDisplayID)display width:(int)width height:(int)height
              format:(OSType)format interval:(CMTime)interval callback:(FrameCallbackBlock)callback {
  if (!(self = [super init])) return nil;
  _signal = dispatch_semaphore_create(0);
  _queue = dispatch_queue_create("wang.ahhtou.sunshine.sck", DISPATCH_QUEUE_SERIAL);
  _callback = [callback copy]; _started = CACurrentMediaTime();
  IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep, kIOPMAssertionLevelOn,
                            CFSTR("Sunshine display capture"), &_powerAssertion);
  _interval = MAX(1.0/240.0, CMTimeGetSeconds(interval));
  _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
  dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, _interval*NSEC_PER_SEC), _interval*NSEC_PER_SEC, NSEC_PER_MSEC);
  dispatch_source_set_event_handler(_timer, ^{
    if (self->_finished) return;
    double elapsed = CACurrentMediaTime()-self->_lastDelivered;
    if (self->_latest && elapsed >= self->_interval*1.5) {
      [self deliver:self->_latest];
    } else if (!self->_latest && CACurrentMediaTime()-self->_started > 8) {
      [self finish:@"启动后 8 秒没有有效图像，结束采集"];
    }
  });
  dispatch_resume(_timer);
  [SCShareableContent getShareableContentExcludingDesktopWindows:NO onScreenWindowsOnly:YES completionHandler:^(SCShareableContent *content, NSError *error) {
    dispatch_async(self->_queue, ^{
      if (self->_finished) return;
      SCDisplay *selected = nil;
      for (SCDisplay *d in content.displays) if (d.displayID == display) selected = d;
      if (!selected) { [self finish:[NSString stringWithFormat:@"找不到屏幕 %u：%@", display, error]]; return; }
      SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:selected excludingWindows:@[]];
      SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
      config.width = width; config.height = height; config.pixelFormat = format;
      config.minimumFrameInterval = interval; config.queueDepth = 2; config.showsCursor = NO;
      self->_stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:self];
      [filter release]; [config release];
      NSError *addError = nil;
      if (![self->_stream addStreamOutput:self type:SCStreamOutputTypeScreen sampleHandlerQueue:self->_queue error:&addError]) {
        [self finish:addError.description]; return;
      }
      NSLog(@"[SCK] 屏幕 %u → %dx%d，像素格式 %u，queueDepth=2", display, width, height, (unsigned)format);
      [self->_stream startCaptureWithCompletionHandler:^(NSError *startError) {
        if (startError) dispatch_async(self->_queue, ^{ [self finish:startError.description]; });
      }];
    });
  }];
  return self;
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sample ofType:(SCStreamOutputType)type {
  if (_finished || type != SCStreamOutputTypeScreen || !CMSampleBufferDataIsReady(sample)) return;
  NSArray *attachments = (NSArray *)CMSampleBufferGetSampleAttachmentsArray(sample, NO);
  if (![attachments.firstObject[SCStreamFrameInfoStatus] isEqual:@(SCFrameStatusComplete)] || !CMSampleBufferGetImageBuffer(sample)) return;
  if (_latest) CFRelease(_latest);
  _latest = (CMSampleBufferRef)CFRetain(sample);
  [self deliver:sample];
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
  dispatch_async(_queue, ^{ [self finish:error.description]; });
}

- (void)dealloc {
  if (_latest) CFRelease(_latest);
  [_callback release]; [_stream release];
  if (_timer) dispatch_release(_timer);
  dispatch_release(_queue); dispatch_release(_signal);
  [super dealloc];
}
@end

@implementation SCKVideo {
  NSMutableArray *_runs; ///< 持有轮次，保证等待停止信号期间对象仍在。
}
- (id)initWithDisplay:(CGDirectDisplayID)displayID frameRate:(int)frameRate {
  if (!(self = [super init])) return nil;
  CGDisplayModeRef mode = CGDisplayCopyDisplayMode(displayID);
  if (!mode || frameRate <= 0) { if (mode) CFRelease(mode); [self release]; return nil; }
  self.displayID = displayID; self.pixelFormat = kCVPixelFormatType_32BGRA;
  self.frameWidth = (int)CGDisplayModeGetPixelWidth(mode);
  self.frameHeight = (int)CGDisplayModeGetPixelHeight(mode);
  self.minFrameDuration = CMTimeMake(1, frameRate);
  CFRelease(mode); _runs = [[NSMutableArray alloc] init];
  return self;
}
- (dispatch_semaphore_t)capture:(FrameCallbackBlock)callback {
  SCKRun *run = [[SCKRun alloc] initWithDisplay:self.displayID width:self.frameWidth height:self.frameHeight
                                     format:self.pixelFormat interval:self.minFrameDuration callback:callback];
  @synchronized(self) { [_runs addObject:run]; }
  dispatch_semaphore_t signal = run.signal; [run release]; return signal;
}
- (void)dealloc { [_runs release]; [super dealloc]; }
@end

/** @brief 自检写文件供外部读取，不启动 Sunshine 服务或弹授权框。 */
int sunshine_sck_diagnostic(const char *mode) {
  @autoreleasepool {
    BOOL permission = CGPreflightScreenCaptureAccess();
    BOOL input = AXIsProcessTrusted();
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:@{
      @"screenCapture":@(permission), @"accessibility":@(input), @"mode":@(mode)
    }];
    int status = permission ? 0 : 1;
    if (permission && strcmp(mode, "--sck-self-test") == 0) {
      uint32_t count = 0; CGDirectDisplayID displays[16];
      CGGetActiveDisplayList(16, displays, &count);
      CGDirectDisplayID display = CGMainDisplayID();
      for (uint32_t i=0; i<count; ++i) if (!CGDisplayIsBuiltin(displays[i])) { display = displays[i]; break; }
      NSMutableArray *tests = [NSMutableArray array];
      OSType formats[] = {kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_32BGRA};
      for (int round=0; round<3; ++round) {
        OSType expectedFormat = formats[round%2];
        SCKVideo *video = [[SCKVideo alloc] initWithDisplay:display frameRate:60];
        video.frameWidth = 1920; video.frameHeight = 1080; video.pixelFormat = expectedFormat;
        __block int frames = 0; __block BOOL valid = YES;
        dispatch_semaphore_t signal = [video capture:^bool(CMSampleBufferRef sample) {
          CVPixelBufferRef pixel = CMSampleBufferGetImageBuffer(sample);
          valid &= pixel && CVPixelBufferGetWidth(pixel)==1920 && CVPixelBufferGetHeight(pixel)==1080
                   && CVPixelBufferGetPixelFormatType(pixel)==expectedFormat;
          return ++frames < 12;
        }];
        // 主线程保持运行循环，避免系统采集服务等待主队列导致假死。
        double until = CACurrentMediaTime()+12; BOOL stopped = NO;
        while (CACurrentMediaTime()<until) {
          if (dispatch_semaphore_wait(signal, DISPATCH_TIME_NOW)==0) { stopped=YES; break; }
          [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        }
        [tests addObject:@{@"round":@(round+1), @"frames":@(frames), @"valid":@(valid), @"stopped":@(stopped)}];
        if (!stopped || !valid || frames!=12) status=2;
        if (stopped) [video release]; // 超时则保留对象直到诊断进程退出。
      }
      result[@"tests"] = tests;
    }
    result[@"status"] = @(status);
    NSData *data = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:@"/private/tmp/sunlilt-diagnostic.json" atomically:YES];
    fprintf(stdout, "%s\n", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] UTF8String]);
    return status;
  }
}
