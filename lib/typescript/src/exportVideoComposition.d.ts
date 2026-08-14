import type { ExportOptions, FrameDrawer, VideoComposition } from './types.js';
/**
 * Exports a video composition to a video file.
 *
 * @returns A promise that resolves when the export is complete.
 */
export declare const exportVideoComposition: <T = undefined>({ videoComposition, drawFrame, beforeDrawFrame, afterDrawFrame, onProgress, abortSignal, ...options }: {
    /**
     * The video composition to export.
     */
    videoComposition: VideoComposition;
    /**
     * The function used to draw the video frames.
     */
    drawFrame: FrameDrawer<T>;
    /**
     * A function that is called before drawing each frame.
     * The return value will be passed to the drawFrame function as context.
     *
     * @returns The context that will be passed to the drawFrame function.
     */
    beforeDrawFrame?: () => T;
    /**
     * A function that is called after drawing each frame.
     * @param context The context returned by the beforeDrawFrame function.
     */
    afterDrawFrame?: (context: T) => void;
    /**
     * A signal used to cancel the export operation. If the signal is aborted, the promise will be rejected with an AbortError.
     */
    abortSignal?: AbortSignal;
    /**
     * A callback that is called when a frame is drawn.
     * @returns
     */
    onProgress?: (progress: {
        framesCompleted: number;
        nbFrames: number;
    }) => void;
} & ExportOptions) => Promise<void>;
//# sourceMappingURL=exportVideoComposition.d.ts.map