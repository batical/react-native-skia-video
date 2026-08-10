//
//  VideoFrame.h
//  azzapp-react-native-skia-video
//
//  Created by François de Campredon on 22/05/2024.
//

#pragma once
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <jsi/jsi.h>

namespace RNSkiaVideo {
using namespace facebook;

/**
 * A decoded frame handed to JS. The frame OWNS its pixels: it retains the
 * decoder's CVPixelBuffer and exposes a zero-copy Metal texture view over
 * its IOSurface — no per-frame blit, no CPU/GPU sync. Everything is
 * released when the frame is destroyed (replaced and garbage-collected).
 */
class JSI_EXPORT VideoFrame : public jsi::HostObject {
public:
  VideoFrame(CVPixelBufferRef pixelBuffer, double width, double height,
             int rotation);
  ~VideoFrame() override;

  std::vector<jsi::PropNameID> getPropertyNames(jsi::Runtime& rt) override;
  jsi::Value get(jsi::Runtime&, const jsi::PropNameID& name) override;

private:
  CVPixelBufferRef pixelBuffer = NULL;
  CVMetalTextureRef cvMetalTexture = NULL;
  id<MTLTexture> mtlTexture;
  double width;
  double height;
  int rotation;
};

} // namespace RNSkiaVideo
