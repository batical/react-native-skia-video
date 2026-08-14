import type { SkImage } from '@shopify/react-native-skia';
import { type DerivedValue } from 'react-native-reanimated';
import type { FrameDrawer, VideoComposition, VideoCompositionFramesExtractor } from './types.js';
type UseVideoCompositionPlayerOptions<T = undefined> = {
    /**
     * The video composition to play.
     * if null, the composition player won't be created.
     */
    composition: VideoComposition | null;
    /**
     * The function used to draw the composition frames.
     */
    drawFrame: FrameDrawer<T>;
    /**
     * A function that is called before drawing each frame.
     * the return value will be passed to the drawFrame function as context.
     */
    beforeDrawFrame?: () => T;
    /**
     * A function that is called after drawing each frame.
     * the context returned by the beforeDrawFrame function will be passed to this function.
     * This function can be used to clean up resources allocated during the drawFrame function.
     */
    afterDrawFrame?: (context: T) => void;
    /**
     * The width of rendered frames.
     */
    width: number;
    /**
     * The height of rendered frames.
     */
    height: number;
    /**
     * Whether the composition should start playing automatically.
     */
    autoPlay?: boolean;
    /**
     * Weather the composition should loop.
     */
    isLooping?: boolean;
    /**
     * Callback that is called when the composition is ready to play.
     */
    onReadyToPlay?: () => void;
    /**
     * Callback that is called when the composition playback completes.
     */
    onComplete?: () => void;
    /**
     * Callback that is called when an error occurs.
     * @param error the error that occurred.
     * @param retry a function that can be called to retry the operation.
     */
    onError?: (error: any, retry: () => void) => void;
};
type VideoCompositionPlayerController = Pick<VideoCompositionFramesExtractor, 'currentTime' | 'play' | 'pause' | 'seekTo' | 'isPlaying'>;
type UseVideoCompositionPlayerReturnType = {
    /**
     * The current drawn frame of the video composition.
     */
    currentFrame: DerivedValue<SkImage | null>;
    /**
     * The video player controller.
     */
    player: VideoCompositionPlayerController | null;
};
/**
 * A hook that creates a video composition player.
 */
export declare const useVideoCompositionPlayer: ({ composition, drawFrame, beforeDrawFrame, afterDrawFrame, width, height, autoPlay, isLooping, onReadyToPlay, onComplete, onError, }: UseVideoCompositionPlayerOptions) => UseVideoCompositionPlayerReturnType;
export {};
//# sourceMappingURL=videoCompositionPlayer.d.ts.map