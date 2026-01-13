#import "VideoRawDataController.h"
#include "VideoProcessing.hpp"
#import <AgoraRtcKit/AgoraRtcKit.h>
#import <Foundation/Foundation.h>

@interface VideoRawDataController () <AgoraRtcEngineDelegate,
                                      AgoraVideoFrameDelegate>

@property(nonatomic, strong) AgoraRtcEngineKit *agoraRtcEngine;

@end

@implementation VideoRawDataController

- (instancetype)initWith:(NSString *)appId {
  self = [super init];
  if (self) {
    AgoraRtcEngineConfig *config = [[AgoraRtcEngineConfig alloc] init];
    config.appId = appId;
    self.agoraRtcEngine = [AgoraRtcEngineKit sharedEngineWithConfig:config
                                                           delegate:self];
    [self.agoraRtcEngine setVideoFrameDelegate:self];
  }

  return self;
}

- (intptr_t)getNativeHandle {
  return (intptr_t)[self.agoraRtcEngine getNativeHandle];
}

- (void)dispose {
  [self.agoraRtcEngine setVideoFrameDelegate:NULL];
  [AgoraRtcEngineKit destroy];
}

// MARK: - AgoraVideoFrameDelegate
- (BOOL)onCaptureVideoFrame:(AgoraOutputVideoFrame *)videoFrame
                 sourceType:(AgoraVideoSourceType)sourceType {
  VideoProcessing::applySepiaFilter(
      (uint8_t *)videoFrame.yBuffer, (uint8_t *)videoFrame.uBuffer,
      (uint8_t *)videoFrame.vBuffer, videoFrame.yStride, videoFrame.uStride,
      videoFrame.vStride, videoFrame.width, videoFrame.height);
  return YES;
}

- (AgoraVideoFormat)getVideoFormatPreference {
  return AgoraVideoFormatI420;
}

- (AgoraVideoFrameProcessMode)getVideoFrameProcessMode {
  return AgoraVideoFrameProcessModeReadWrite;
}

@end
