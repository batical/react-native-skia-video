"use strict";

import { useSharedValue, useFrameCallback } from 'react-native-reanimated';
import { useCallback, useEffect, useMemo, useState } from 'react';
import useEventListener from "./utils/useEventListener.js";
import RNSkiaVideoModule from "./RNSkiaVideoModule.js";
/**
 * Hook that creates a video player and manages its state.
 * @param options The options for the video player.
 * @returns
 */
export const useVideoPlayer = ({
  uri,
  resolution,
  autoPlay = false,
  isLooping = false,
  volume = 1,
  playbackSpeed = 1,
  onReadyToPlay,
  onBufferingStart,
  onBufferingEnd,
  onBufferingUpdate,
  onComplete,
  onError,
  onPlayingStatusChange,
  onSeekComplete
}) => {
  const [isErrored, setIsErrored] = useState(false);
  const player = useMemo(() => {
    if (uri && !isErrored) {
      return RNSkiaVideoModule.createVideoPlayer(uri, resolution);
    }
    return null;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isErrored, resolution?.width, resolution?.height, uri]);
  const currentFrame = useSharedValue(null);
  useEffect(() => () => {
    currentFrame.value = null;
    player?.dispose();
  }, [player, currentFrame]);
  const retry = useCallback(() => {
    setIsErrored(false);
  }, []);
  const errorHandler = useCallback(error => {
    onError?.(error, retry);
    setIsErrored(true);
  }, [onError, retry]);
  useEffect(() => {
    if (player) {
      player.isLooping = isLooping;
    }
  }, [player, isLooping]);
  useEffect(() => {
    if (player) {
      player.volume = volume;
    }
  }, [player, volume]);
  useEffect(() => {
    if (player) {
      player.playbackSpeed = playbackSpeed;
    }
  }, [player, playbackSpeed]);
  useEventListener(player, 'ready', onReadyToPlay);
  useEventListener(player, 'bufferingStart', onBufferingStart);
  useEventListener(player, 'bufferingEnd', onBufferingEnd);
  useEventListener(player, 'bufferingUpdate', onBufferingUpdate);
  useEventListener(player, 'complete', onComplete);
  useEventListener(player, 'error', errorHandler);
  useEventListener(player, 'playingStatusChange', onPlayingStatusChange);
  useEventListener(player, 'seekComplete', onSeekComplete);
  useEffect(() => {
    if (autoPlay) {
      player?.play();
    }
  }, [player, autoPlay]);
  useFrameCallback(() => {
    if (!player || !player.isPlaying && currentFrame.value) {
      return;
    }
    const nextFrame = player.decodeNextFrame();
    if (nextFrame) {
      currentFrame.value = nextFrame;
    }
  }, true);
  return {
    currentFrame,
    player
  };
};
//# sourceMappingURL=videoPlayer.js.map