# Rendering and decoder scheduling

Paused compositions can now receive a `redrawVersion: SharedValue<number>`.
Increment it when external drawing inputs change. The hook also invalidates on
size or drawer changes. `drawWhenPaused` remains available for continuously
animated overlays. Neither API changes decoding timestamps or export frames.

Export progress defaults to a minimum wall-clock interval of 100 ms, with a
mandatory final update. Pass `progressIntervalMs: 0` for per-frame callbacks.
Frame counts are rounded up to match the frames actually encoded.

The iOS preview coalesces display-link requests. A single video decodes on its
persistent queue; multiple videos use GCD's worker pool. While paused, only
initial preparation or a seek requires another decoding pass. Android stops its
10 ms playback loop while paused and wakes on decoded-frame notifications so
an asynchronous seek still publishes its result. The JS frame hook still polls
for newly available textures; this is not a claim of zero idle CPU usage.

## Validation before leaving draft

Use release builds on iPhone and Android hardware. Run the baseline and branch
with the same clips, device temperature and export settings:

- Pause after initial preparation, then seek repeatedly in both directions.
  Verify the last requested frame appears, including before `ready` fires.
- Play and pause repeatedly, cross at least ten loop boundaries, then seek to
  the end. Repeat with silent clips, audio, still compositions and two videos.
- Edit an overlay while paused, replace the drawer, and resize the canvas.
  The new picture must appear once; unchanged ticks must not flush a surface.
- Hide/show the player, background/foreground the app and dispose during decode.
- Export 30/60 FPS clips including a fractional duration. Verify final progress,
  cancellation, timestamp order, first/last frames and audio synchronization.

Capture CPU activity while paused, preview frame-time p50/p95/p99, peak memory,
export wall time and thermal state. Unit tests cover hook invalidation and
progress emission, not actual GPU scheduling or device performance.

## Further GPU work

This change deliberately retains `readPixels` synchronization, Metal waits and
the existing copy/direct defaults. Replacing them requires producer/consumer
fences and retaining buffers until GPU completion. Test all four copy/direct
combinations before changing a default. Also profile reduced decode resolution
with crop-aware sizing before enabling it for exports. No speedup percentage is
claimed by this change.
