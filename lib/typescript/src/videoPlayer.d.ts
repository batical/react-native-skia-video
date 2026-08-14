import { type SharedValue } from 'react-native-reanimated';
import type { BufferingRange, VideoDimensions, VideoFrame, VideoPlayer } from './types.js';
type UseVideoPlayerOptions = {
    /**
     * The URI of the video to play.
     * if null, the video player won't be created.
     */
    uri: string | null;
    /**
     * If provided, the resolution to scale the video to.
     * If not provided, the original resolution of the video will be used.
     * Downscaling the video can improve performance.
     * Changing the resolution after the video player will lead to re-creating the video player.
     */
    resolution?: {
        width: number;
        height: number;
    } | null;
    /**
     * Whether the video should start playing automatically.
     */
    autoPlay?: boolean;
    /**
     * Weather the video should loop.
     */
    isLooping?: boolean;
    /**
     * The volume of the video.
     */
    volume?: number;
    /**
     * The playback speed of the video.
     * The value should be greater than 0. 1.0 is normal speed, 2.0 is double speed, 0.5 is half speed.
     */
    playbackSpeed?: number;
    /**
     * Callback that is called when the video is ready to play.
     * @param dimensions The dimensions of the video.
     */
    onReadyToPlay?: (dimensions: VideoDimensions) => void;
    /**
     * Callback that is called when the video starts buffering.
     */
    onBufferingStart?: () => void;
    /**
     * Callback that is called when the video stops buffering.
     */
    onBufferingEnd?: () => void;
    /**
     * Callback that is called when the buffered ranges are updated.
     * @param loadedRanges The buffered ranges.
     */
    onBufferingUpdate?: (loadedRanges: BufferingRange[]) => void;
    /**
     * Callback that is called when the video playback completes.
     */
    onComplete?: () => void;
    /**
     * Callback that is called when an error occurs.
     * @param error the error that occurred.
     * @param retry a function that can be called to retry the operation.
     */
    onError?: (error: any, retry: () => void) => void;
    /**
     * Callback that is called when the playing status changes.
     * @param playing Whether the video is playing.
     */
    onPlayingStatusChange?: (playing: boolean) => void;
    /**
     * Callback that is called when a seek operation completes.
     * @returns
     */
    onSeekComplete?: () => void;
};
type VideoPlayerController = Pick<VideoPlayer, 'currentTime' | 'duration' | 'play' | 'pause' | 'seekTo' | 'isPlaying'>;
type UseVideoPlayerReturnType = {
    /**
     * The current frame of the playing video.
     */
    currentFrame: SharedValue<VideoFrame | null>;
    /**
     * The video player controller.
     */
    player: VideoPlayerController | null;
};
/**
 * Hook that creates a video player and manages its state.
 * @param options The options for the video player.
 * @returns
 */
export declare const useVideoPlayer: ({ uri, resolution, autoPlay, isLooping, volume, playbackSpeed, onReadyToPlay, onBufferingStart, onBufferingEnd, onBufferingUpdate, onComplete, onError, onPlayingStatusChange, onSeekComplete, }: UseVideoPlayerOptions) => UseVideoPlayerReturnType;
export {};
//# sourceMappingURL=videoPlayer.d.ts.map