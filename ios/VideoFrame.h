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
#import <mutex>

namespace RNSkiaVideo {
using namespace facebook;

/**
 * How many recently issued zero-copy frames a producer keeps alive before
 * releasing the oldest one's buffer.
 *
 * Why a count is sound here: eviction is indexed on the *issuance* of new
 * frames, i.e. on the drawing tick, and issuance cannot outrun the GPU by
 * more than the Metal drawable pool lets it (CAMetalLayer allows at most
 * maxDrawableCount = 3 frames in flight before the render loop blocks).
 * A depth of maxDrawableCount + 1 therefore guarantees a frame is only
 * released once the GPU can no longer have sampling work queued on it,
 * even under full GPU backlog — without needing a completion fence, which
 * would require hooks into RN Skia's internal command buffers.
 */
static constexpr size_t kIssuedFrameRingDepth = 4;

/**
 * A decoded frame handed to JS. The frame OWNS its pixels: it retains the
 * decoder's CVPixelBuffer and exposes a zero-copy Metal texture view over
 * its IOSurface — no per-frame blit, no CPU/GPU sync.
 *
 * Lifetime is deterministic, NOT garbage-collector driven: the producer
 * (decoder or player) keeps a small ring of recently issued frames and
 * calls releaseBuffer() on the oldest one as new frames are issued, so the
 * decoder pools never starve and memory stays bounded no matter how lazily
 * the JS runtime collects the wrapper objects. A released frame's `texture`
 * getter returns undefined.
 */
class JSI_EXPORT VideoFrame : public jsi::HostObject {
public:
  VideoFrame(CVPixelBufferRef pixelBuffer, double width, double height,
             int rotation);
  ~VideoFrame() override;

  /**
   * Returns the pixel buffer and its texture view early, without waiting
   * for the JS wrapper to be collected. Idempotent.
   */
  void releaseBuffer();

  std::vector<jsi::PropNameID> getPropertyNames(jsi::Runtime& rt) override;
  jsi::Value get(jsi::Runtime&, const jsi::PropNameID& name) override;

private:
  std::mutex mutex;
  CVPixelBufferRef pixelBuffer = NULL;
  CVMetalTextureRef cvMetalTexture = NULL;
  id<MTLTexture> mtlTexture;
  double width;
  double height;
  int rotation;
};

} // namespace RNSkiaVideo
