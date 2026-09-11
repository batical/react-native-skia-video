#pragma once

#import "RNSVHostObject.h"
#import "VideoComposition.h"
#import <AVFoundation/AVFoundation.h>
#import <jsi/jsi.h>
#import <map>

namespace RNSkiaVideo {
using namespace facebook;

class JSI_EXPORT VideoEncoderHostObject : public RNSVHostObject {
public:
  VideoEncoderHostObject(std::string outPath, int width, int height,
                         int frameRate, int bitRate, std::string codec,
                         int audioBitRate, int audioSampleRate,
                         int audioChannelCount,
                         std::shared_ptr<VideoComposition> composition,
                         bool directEncoder);

  /**
   * Whether the device has an encoder for the given codec ("h264" or "hevc").
   * H.264 is guaranteed; HEVC needs an A10 or later.
   */
  static bool isCodecSupported(const std::string& codec);
  jsi::Value get(jsi::Runtime&, const jsi::PropNameID& name) override;
  std::vector<jsi::PropNameID> getPropertyNames(jsi::Runtime& rt) override;

private:
  std::string outPath;
  int width;
  int height;
  int bitRate;
  int frameRate;
  std::string codec;
  int audioBitRate;
  int audioSampleRate;
  int audioChannelCount;
  std::shared_ptr<VideoComposition> composition;
  // `encoderMode: 'direct'` blits the rendered texture straight into the
  // encoder's pixel buffer on the GPU. `'copy'` (the default) goes through a
  // CPU readable texture and getBytes, as before.
  bool directEncoder = false;
  id<MTLDevice> device;
  id<MTLCommandQueue> commandQueue;
  // Copy mode only: the CPU readable staging texture every frame goes through.
  id<MTLTexture> cpuAccessibleTexture;
  AVAssetWriter* assetWriter;
  AVAssetWriterInput* assetWriterInput;
  CVPixelBufferPoolRef pixelBufferPool = NULL;

  AVAssetWriterInput* audioWriterInput;
  AVAssetReader* audioReader;
  AVAssetReaderAudioMixOutput* audioMixOutput;
  dispatch_queue_t audioQueue;
  dispatch_semaphore_t audioCompletionSemaphore;
  NSMutableArray<NSError*>* audioErrorHolder;

  void prepare();
  void encodeFrame(id<MTLTexture> mlTexture, CMTime time);
  void fillPixelBufferDirect(id<MTLTexture> mlTexture,
                             CVPixelBufferRef pixelBuffer);
  void fillPixelBufferCopy(id<MTLTexture> mlTexture,
                           CVPixelBufferRef pixelBuffer);
  void setupAudio();
  void startWritingAudio();
  void finish();
  void release();
};

} // namespace RNSkiaVideo
