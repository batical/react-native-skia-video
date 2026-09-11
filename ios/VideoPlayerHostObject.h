#pragma once

#include "RNSVEventEmitter.h"
#include "RNSVHostObject.h"
#include "RNSVVideoPlayer.h"
#include "VideoFrame.h"

using namespace facebook;

@interface RNSVSkiaVideoPlayerDelegateImpl : NSObject <RNSVVideoPlayerDelegate>

- (instancetype)initWithHost:(RNSkiaVideo::EventEmitter*)host
                     runtime:(jsi::Runtime*)runtime;
- (void)dispose;

@end

namespace RNSkiaVideo {

class JSI_EXPORT VideoPlayerHostObject : public RNSVHostObject, EventEmitter {
public:
  VideoPlayerHostObject(jsi::Runtime& runtime,
                        std::shared_ptr<react::CallInvoker> callInvoker,
                        NSURL* url, CGSize resolution, bool directTexture);
  ~VideoPlayerHostObject();
  jsi::Value get(jsi::Runtime&, const jsi::PropNameID& name) override;
  void set(jsi::Runtime&, const jsi::PropNameID& name,
           const jsi::Value& value) override;
  std::vector<jsi::PropNameID> getPropertyNames(jsi::Runtime& rt) override;

  void readyToPlay(float width, float height, int rotation);
  void frameAvailableEventHandler(CMTime time);

private:
  RNSVVideoPlayer* player;
  RNSVSkiaVideoPlayerDelegateImpl* playerDelegate;
  std::shared_ptr<VideoFrame> currentFrame;
  // Bounds the lifetime of the frames handed to JS in direct mode; never
  // depends on the JS garbage collector (see VideoFrame.h). Unused in copy
  // mode, where the frames own nothing.
  VideoFrameRing frameRing;
  // Copy mode (the default): every decoded frame is copied into this one
  // texture, which the player owns for its whole life.
  bool directTexture = false;
  id<MTLTexture> persistentTexture;
  std::shared_ptr<VideoFrame> makeFrame(CVPixelBufferRef buffer);
  CMTime lastFrameAvailable = kCMTimeInvalid;
  CMTime lastFrameDrawn = kCMTimeInvalid;
  float width;
  float height;
  int rotation;
  std::atomic_flag released = ATOMIC_FLAG_INIT;
  void release();
};
} // namespace RNSkiaVideo
