#include "VideoCompositionItemDecoder.h"

#import "AVAssetTrackUtils.h"
#import "MTLTextureUtils.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

namespace RNSkiaVideo {

VideoCompositionItemDecoder::VideoCompositionItemDecoder(
    std::shared_ptr<VideoCompositionItem> item, bool realTime,
    AVURLAsset* sharedAsset)
    // The sync (export) consumer flushes the GPU before asking for the next
    // frame, so retiring a frame the moment it is replaced is safe and keeps
    // one decoded buffer alive per item instead of four — at 4K that is
    // ~100MB less per item during an export.
    : frameRing(realTime ? kPreviewFrameRingDepth : 1) {
  this->item = item;
  this->realTime = realTime;
  this->directTexture = item->directTexture;
  lock = [[NSObject alloc] init];
  NSString* path =
      [NSString stringWithCString:item->path.c_str()
                         encoding:[NSString defaultCStringEncoding]];
  asset = sharedAsset
              ?: [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path]
                                     options:nil];
  videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
  if (!videoTrack) {
    throw [NSError
        errorWithDomain:@"com.azzapp.rnskv"
                   code:0
               userInfo:@{
                 NSLocalizedDescriptionKey : [NSString
                     stringWithFormat:@"No video track for path: %@", path]
               }];
  }
  segments = videoTrack.segments;
  width = videoTrack.naturalSize.width;
  height = videoTrack.naturalSize.height;
  rotation = AVAssetTrackUtils::GetTrackRotationInDegree(videoTrack);
  currentFrame = nullptr;
  this->setupReader(kCMTimeZero);
}

void VideoCompositionItemDecoder::setupReader(CMTime initialTime) {
  NSError* error = nil;
  assetReader = [AVAssetReader assetReaderWithAsset:asset error:&error];
  if (error) {
    throw error;
  }

  auto startTime = CMTimeMakeWithSeconds(item->startTime, NSEC_PER_SEC);
  auto position = CMTimeMakeWithSeconds(
      MAX((CMTimeGetSeconds(initialTime) - item->compositionStartTime), 0),
      NSEC_PER_SEC);
  assetReader.timeRange = CMTimeRangeMake(
      CMTimeAdd(startTime, position),
      CMTimeSubtract(CMTimeMakeWithSeconds(item->duration, NSEC_PER_SEC),
                     position));

  NSDictionary* pixBuffAttributes = @{
    (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
    (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
    (id)kCVPixelBufferMetalCompatibilityKey : @YES
  };
  CGSize resolution = item->resolution;
  /*
   * No explicit size asked for, but a cap on the longest side: scale the
   * track's own dimensions to fit it.
   *
   * This is the size the frames are *decoded* at, so it is what the preview's
   * four-deep frame ring costs. Left uncapped, a 4K clip is 33 MB a frame in
   * BGRA — 133 MB of ring to fill a stage a few hundred points wide, which the
   * OS watchdog terminates the app over.
   *
   * `naturalSize` is the encoded size, before the display matrix, which is why
   * the cap is resolved here: a caller holding only display dimensions cannot
   * tell a portrait clip from a rotated landscape one, and asking for the
   * transpose would hand back a squashed picture. Even dimensions because
   * hardware scalers dislike odd ones.
   */
  if (!(resolution.width > 0 && resolution.height > 0) && item->maxLongSide > 0) {
    CGSize natural = videoTrack.naturalSize;
    CGFloat longest = MAX(natural.width, natural.height);
    if (longest > item->maxLongSide) {
      CGFloat scale = item->maxLongSide / longest;
      resolution = CGSizeMake(MAX(2, round(natural.width * scale / 2) * 2),
                              MAX(2, round(natural.height * scale / 2) * 2));
    }
  }
  if (resolution.width > 0 && resolution.height > 0) {
    pixBuffAttributes =
        [NSMutableDictionary dictionaryWithDictionary:pixBuffAttributes];
    [pixBuffAttributes setValue:@(resolution.width)
                         forKey:(id)kCVPixelBufferWidthKey];
    [pixBuffAttributes setValue:@(resolution.height)
                         forKey:(id)kCVPixelBufferHeightKey];
    width = resolution.width;
    height = resolution.height;
  }

  AVAssetReaderOutput* assetReaderOutput =
      [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack
                                       outputSettings:pixBuffAttributes];
  [assetReader addOutput:assetReaderOutput];
  [assetReader startReading];
}

// Slow-motion videos (e.g. those recorded by the iPhone camera) store every
// frame in the short *source* (media) timeline but expose a stretched
// presentation duration through the track's segment time mappings. The raw
// AVAssetReaderTrackOutput hands us samples with their source timestamps and
// ignores those mappings, so we remap each sample into the *target*
// (presentation) timeline that the composition uses. For regular videos the
// single segment is an identity mapping and this is a no-op.
double VideoCompositionItemDecoder::mapSourceTimeToTarget(CMTime sourceTime) {
  if (segments == nil || segments.count == 0) {
    return CMTimeGetSeconds(sourceTime);
  }
  AVAssetTrackSegment* matching = nil;
  for (AVAssetTrackSegment* segment in segments) {
    if (segment.empty) {
      continue;
    }
    CMTimeRange source = segment.timeMapping.source;
    if (!CMTIMERANGE_IS_VALID(source) || source.duration.value == 0) {
      continue;
    }
    if (CMTimeCompare(sourceTime, source.start) >= 0) {
      // Keep the latest segment starting at or before the sample so that
      // samples falling past a segment's end extrapolate from the nearest
      // mapping instead of desyncing back to an identity timeline.
      matching = segment;
      if (CMTimeCompare(sourceTime, CMTimeRangeGetEnd(source)) < 0) {
        break;
      }
    } else if (matching == nil) {
      matching = segment;
      break;
    }
  }
  if (matching == nil) {
    return CMTimeGetSeconds(sourceTime);
  }
  CMTime target = CMTimeMapTimeFromRangeToRange(
      sourceTime, matching.timeMapping.source, matching.timeMapping.target);
  return CMTimeGetSeconds(target);
}

#define DECODER_INPUT_TIME_ADVANCE 0.1

void VideoCompositionItemDecoder::advanceDecoder(CMTime currentTime) {
  @synchronized(lock) {
    CMTime startTime = CMTimeMakeWithSeconds(item->startTime, NSEC_PER_SEC);
    CMTime compositionStartTime =
        CMTimeMakeWithSeconds(item->compositionStartTime, NSEC_PER_SEC);
    CMTime position =
        CMTimeAdd(startTime, CMTimeSubtract(currentTime, compositionStartTime));
    CMTime inputPosition =
        realTime
            ? CMTimeAdd(position, CMTimeMakeWithSeconds(
                                      DECODER_INPUT_TIME_ADVANCE, NSEC_PER_SEC))
            : position;
    CMTime duration = CMTimeMakeWithSeconds(item->duration, NSEC_PER_SEC);
    CMTime endTime = CMTimeAdd(startTime, duration);

    if (realTime && CMTimeCompare(endTime, inputPosition) < 0 && !hasLooped) {
      setupReader(kCMTimeZero);
      hasLooped = true;
      // we will loop so we want to decode the first frames of the next loop
      inputPosition =
          CMTimeAdd(position, CMTimeMakeWithSeconds(DECODER_INPUT_TIME_ADVANCE,
                                                    NSEC_PER_SEC));
    }

    auto framesQueue = hasLooped ? &nextLoopFrames : &decodedFrames;
    CMTime latestSampleTime = kCMTimeInvalid;
    if (framesQueue->size() > 0) {
      latestSampleTime =
          CMTimeMakeWithSeconds(framesQueue->back().first, NSEC_PER_SEC);
    }

    while (!CMTIME_IS_VALID(latestSampleTime) ||
           (CMTimeCompare(latestSampleTime, inputPosition) < 0 &&
            CMTimeCompare(endTime, inputPosition) >= 0)) {
      if (assetReader.status != AVAssetReaderStatusReading) {
        break;
      }
      AVAssetReaderOutput* assetReaderOutput =
          [assetReader.outputs firstObject];
      CMSampleBufferRef sampleBuffer = [assetReaderOutput copyNextSampleBuffer];
      if (!sampleBuffer) {
        break;
      }
      if (CMSampleBufferGetNumSamples(sampleBuffer) == 0) {
        CFRelease(sampleBuffer);
        continue;
      }
      auto timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
      double targetSeconds = this->mapSourceTimeToTarget(timeStamp);
      auto buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
      if (buffer) {
        framesQueue->push_back(std::make_pair(targetSeconds, sampleBuffer));
      } else {
        CFRelease(sampleBuffer);
      }

      latestSampleTime = CMTimeMakeWithSeconds(targetSeconds, NSEC_PER_SEC);
    }
  }
}

std::shared_ptr<VideoFrame>
VideoCompositionItemDecoder::acquireFrameForTime(CMTime currentTime,
                                                 bool force) {
  CMSampleBufferRef nextFrame = nil;
  // advanceDecoder appends to the frame lists from a decoding thread while
  // this runs on the UI thread: every access to the lists goes through the
  // decoder lock. The texture upload below happens outside of it so the
  // decoding thread is not held back by the GPU.
  @synchronized(lock) {
    if (hasLooped && CMTIME_IS_VALID(lastRequestedTime) &&
        CMTimeCompare(currentTime, lastRequestedTime) < 0) {
      hasLooped = false;
      for (const auto& frame : decodedFrames) {
        CFRelease(frame.second);
      }
      decodedFrames = nextLoopFrames;
      nextLoopFrames.clear();
    }
    lastRequestedTime = currentTime;

    CMTime position = CMTimeAdd(
        CMTimeMakeWithSeconds(item->startTime, NSEC_PER_SEC),
        CMTimeMakeWithSeconds(
            MAX((CMTimeGetSeconds(currentTime) - item->compositionStartTime),
                0),
            NSEC_PER_SEC));

    auto it = decodedFrames.begin();
    while (it != decodedFrames.end()) {
      auto timestamp = CMTimeMakeWithSeconds(it->first, NSEC_PER_SEC);
      if (CMTimeCompare(timestamp, position) <= 0 ||
          (force && nextFrame == nullptr)) {
        if (nextFrame != nullptr) {
          CFRelease(nextFrame);
        }
        nextFrame = it->second;
        it = decodedFrames.erase(it);
      } else {
        break;
      }
    }
  }
  if (nextFrame) {
    CVPixelBufferRef buffer = CMSampleBufferGetImageBuffer(nextFrame);
    auto frame = makeFrame(buffer);
    CFRelease(nextFrame);
    return frame;
  }
  return nullptr;
}

std::shared_ptr<VideoFrame>
VideoCompositionItemDecoder::makeFrame(CVPixelBufferRef buffer) {
  if (directTexture) {
    // Zero-copy: the frame wraps the decoder's pixel buffer directly (and
    // retains it); no intermediate texture, no blit, no CPU/GPU sync.
    auto frame = std::make_shared<VideoFrame>(buffer, width, height, rotation);
    // Deterministic lifetime (see VideoFrame.h): frames older than the ring
    // lose their texture immediately, and their buffer returns to the pool as
    // soon as nothing reads it anymore. Stale JS wrappers see an undefined
    // texture instead of pinning a decoder buffer until garbage collection.
    frameRing.push(frame);
    return frame;
  }
  // Copy mode (default): the pixels go into one texture this decoder owns, so
  // a frame stays readable until the next one overwrites it and the decoder's
  // buffer goes straight back to its pool.
  if (!persistentTexture) {
    persistentTexture = [MTLTextureUtils
        createPersistentTextureOfSize:CGSizeMake(width, height)];
    if (!persistentTexture) {
      throw std::runtime_error("Failed to create persistent Metal texture!");
    }
  }
  [MTLTextureUtils copyPixelBuffer:buffer intoTexture:persistentTexture];
  return std::make_shared<VideoFrame>(persistentTexture, width, height,
                                      rotation);
}

void VideoCompositionItemDecoder::seekTo(CMTime currentTime) {
  @synchronized(lock) {
    release();
    setupReader(currentTime);
  }
}

void VideoCompositionItemDecoder::release() {
  @synchronized(lock) {
    if (assetReader) {
      [assetReader cancelReading];
      assetReader = nullptr;
    }
    for (const auto& frame : decodedFrames) {
      CFRelease(frame.second);
    }
    decodedFrames.clear();
    for (const auto& frame : nextLoopFrames) {
      CFRelease(frame.second);
    }
    nextLoopFrames.clear();
    frameRing.releaseAll();
    hasLooped = false;
    lastRequestedTime = kCMTimeInvalid;
    currentFrame = nullptr;
  }
}

VideoCompositionItemDecoder::~VideoCompositionItemDecoder() {
  @synchronized(lock) {
    // Copy mode only: hand the texture's memory back without waiting for ARC
    // to get around to it.
    if (persistentTexture) {
      [persistentTexture setPurgeableState:MTLPurgeableStateEmpty];
      persistentTexture = nil;
    }
  }
}

} // namespace RNSkiaVideo
