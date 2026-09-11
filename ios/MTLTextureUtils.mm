//
//  MTLTextureUtils.m
//  azzapp-react-native-skia-video
//
//  Created by François de Campredon on 02/12/2024.
//

#import "MTLTextureUtils.h"
#import <Metal/Metal.h>
#import <stdexcept>

@implementation MTLTextureUtils

+ (nullable id<MTLDevice>)device {
  static id<MTLDevice> device = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    device = MTLCreateSystemDefaultDevice();
  });
  return device;
}

// The cache is reached from the decoder queues, the render thread and the
// export thread, sometimes concurrently, and CVMetalTextureCache makes no
// thread-safety promise, so every access to it goes through this class and is
// serialized on it.
static CVMetalTextureCacheRef metalTextureCache = NULL;

// Callers must hold the class lock.
+ (nullable CVMetalTextureCacheRef)cacheLocked {
  if (!metalTextureCache) {
    CVReturn status = CVMetalTextureCacheCreate(
        kCFAllocatorDefault, NULL, [self device], NULL, &metalTextureCache);
    if (status != kCVReturnSuccess) {
      NSLog(@"Failed to create CVMetalTextureCache: %d", status);
      metalTextureCache = NULL;
    }
  }
  return metalTextureCache;
}

+ (nullable CVMetalTextureRef)createTextureViewForPixelBuffer:
    (CVPixelBufferRef)pixelBuffer {
  size_t width = CVPixelBufferGetWidth(pixelBuffer);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);

  CVMetalTextureRef cvMetalTexture = NULL;
  @synchronized(self) {
    CVMetalTextureCacheRef cache = [self cacheLocked];
    if (!cache) {
      return NULL;
    }
    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(
        kCFAllocatorDefault, cache, pixelBuffer, NULL, MTLPixelFormatBGRA8Unorm,
        width, height, 0, &cvMetalTexture);
    if (status != kCVReturnSuccess && cvMetalTexture) {
      CFRelease(cvMetalTexture);
      cvMetalTexture = NULL;
    }
  }
  return cvMetalTexture;
}

+ (nullable id<MTLTexture>)createPersistentTextureOfSize:(CGSize)size {
  MTLTextureDescriptor* descriptor = [[MTLTextureDescriptor alloc] init];
  descriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
  descriptor.width = size.width;
  descriptor.height = size.height;
  descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
  descriptor.storageMode = MTLStorageModePrivate;
  return [[self device] newTextureWithDescriptor:descriptor];
}

+ (id<MTLCommandQueue>)copyQueue {
  static id<MTLCommandQueue> queue = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    queue = [[self device] newCommandQueue];
  });
  return queue;
}

+ (void)copyPixelBuffer:(CVPixelBufferRef)pixelBuffer
            intoTexture:(id<MTLTexture>)texture {
  @autoreleasepool {
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    if (width > texture.width || height > texture.height) {
      throw std::runtime_error(
          "Pixel buffer dimensions exceed texture dimensions!");
    }

    CVMetalTextureRef source =
        [self createTextureViewForPixelBuffer:pixelBuffer];
    if (!source) {
      throw std::runtime_error(
          "Failed to create Metal texture from CVPixelBuffer!");
    }

    id<MTLCommandBuffer> commandBuffer = [[self copyQueue] commandBuffer];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    [blitEncoder copyFromTexture:CVMetalTextureGetTexture(source)
                     sourceSlice:0
                     sourceLevel:0
                    sourceOrigin:MTLOriginMake(0, 0, 0)
                      sourceSize:MTLSizeMake(width, height, 1)
                       toTexture:texture
                destinationSlice:0
                destinationLevel:0
               destinationOrigin:MTLOriginMake(0, 0, 0)];
    [blitEncoder endEncoding];
    [commandBuffer commit];
    // The texture is read right after this returns, from another command
    // queue: wait for the copy.
    [commandBuffer waitUntilCompleted];

    CFRelease(source);
    // The decoder's buffer goes back to its pool as soon as the caller
    // releases it; the cache must not keep pinning its surface.
    [self flushTextureCache];
  }
}

+ (void)flushTextureCache {
  @synchronized(self) {
    if (metalTextureCache) {
      CVMetalTextureCacheFlush(metalTextureCache, 0);
    }
  }
}

@end
