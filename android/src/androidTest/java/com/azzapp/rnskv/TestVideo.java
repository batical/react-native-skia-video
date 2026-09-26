package com.azzapp.rnskv;

import android.media.Image;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.MediaMuxer;

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;

/**
 * A small H.264 file encoded on the device, so the tests carry no media: 30
 * frames a second, a key frame every second, frame i at i / 30 s.
 */
final class TestVideo {

  static final int WIDTH = 320;

  static final int HEIGHT = 240;

  static final int FPS = 30;

  static final long FRAME_US = 1_000_000L / FPS;

  private TestVideo() {
  }

  static File write(File file, double seconds) throws IOException {
    int frames = (int) Math.round(seconds * FPS);
    MediaFormat format =
      MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, WIDTH, HEIGHT);
    format.setInteger(
      MediaFormat.KEY_COLOR_FORMAT,
      MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible);
    format.setInteger(MediaFormat.KEY_BIT_RATE, 400_000);
    format.setInteger(MediaFormat.KEY_FRAME_RATE, FPS);
    format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1);

    MediaCodec encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC);
    MediaMuxer muxer = new MediaMuxer(file.getPath(), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
    boolean muxing = false;
    try {
      encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
      encoder.start();
      MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
      int track = -1;
      int queued = 0;
      boolean inputDone = false;
      boolean outputDone = false;
      while (!outputDone) {
        if (!inputDone) {
          int in = encoder.dequeueInputBuffer(10_000);
          if (in >= 0) {
            long ptsUs = queued * 1_000_000L / FPS;
            if (queued == frames) {
              encoder.queueInputBuffer(in, 0, 0, ptsUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
              inputDone = true;
            } else {
              Image image = encoder.getInputImage(in);
              if (image == null) {
                throw new IOException("The encoder takes no flexible YUV input");
              }
              fill(image, 16 + (queued * 7) % 220);
              encoder.queueInputBuffer(in, 0, WIDTH * HEIGHT * 3 / 2, ptsUs, 0);
              queued++;
            }
          }
        }
        int out = encoder.dequeueOutputBuffer(info, 10_000);
        if (out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
          track = muxer.addTrack(encoder.getOutputFormat());
          muxer.start();
          muxing = true;
        } else if (out >= 0) {
          ByteBuffer data = encoder.getOutputBuffer(out);
          boolean config = (info.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0;
          if (!config && info.size > 0 && muxing && data != null) {
            data.position(info.offset);
            data.limit(info.offset + info.size);
            muxer.writeSampleData(track, data, info);
          }
          encoder.releaseOutputBuffer(out, false);
          outputDone = (info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0;
        }
      }
      encoder.stop();
    } finally {
      encoder.release();
      if (muxing) {
        muxer.stop();
      }
      muxer.release();
    }
    return file;
  }

  private static void fill(Image image, int luma) {
    Image.Plane[] planes = image.getPlanes();
    fillPlane(planes[0], WIDTH, HEIGHT, (byte) luma);
    fillPlane(planes[1], WIDTH / 2, HEIGHT / 2, (byte) 128);
    fillPlane(planes[2], WIDTH / 2, HEIGHT / 2, (byte) 128);
  }

  private static void fillPlane(Image.Plane plane, int width, int height, byte value) {
    ByteBuffer buffer = plane.getBuffer();
    int rowStride = plane.getRowStride();
    int pixelStride = plane.getPixelStride();
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int index = y * rowStride + x * pixelStride;
        if (index < buffer.limit()) {
          buffer.put(index, value);
        }
      }
    }
  }
}
