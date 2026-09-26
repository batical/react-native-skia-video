package com.azzapp.rnskv;

/**
 * When an item's decoder is open, for a composition with lazy decoders: from a
 * little before the item starts to a little after it ends. Without lazy
 * decoders every decoder is open for the life of the player.
 */
final class DecoderWindow {

  // The preview has to open a codec and decode to the first frame before the
  // item is on screen; the export waits for it anyway. Chosen, not measured.
  private static final long PREVIEW_LEAD_US = 1_500_000;
  private static final long EXPORT_LEAD_US = 500_000;

  // Kept a little past both ends, so a scrub across a cut does not reopen it.
  private static final long MARGIN_US = 500_000;

  private final boolean lazy;

  private final long leadUs;

  private DecoderWindow(boolean lazy, long leadUs) {
    this.lazy = lazy;
    this.leadUs = leadUs;
  }

  static DecoderWindow of(boolean lazy, boolean realTime) {
    return new DecoderWindow(lazy, realTime ? PREVIEW_LEAD_US : EXPORT_LEAD_US);
  }

  boolean isLazy() {
    return lazy;
  }

  /**
   * @param startUs    the item's start in the composition
   * @param endUs      the item's end in the composition
   * @param positionUs the composition time
   * @param durationUs the composition's duration
   * @param looping    whether the composition starts over at its end
   */
  boolean opens(long startUs, long endUs, long positionUs, long durationUs, boolean looping) {
    return !lazy || within(startUs - leadUs, endUs, positionUs, durationUs, looping);
  }

  /**
   * Wider than {@link #opens}, so an item is never closed and reopened on
   * either side of the same edge.
   */
  boolean keeps(long startUs, long endUs, long positionUs, long durationUs, boolean looping) {
    return !lazy || within(
      startUs - leadUs - MARGIN_US, endUs + MARGIN_US, positionUs, durationUs, looping);
  }

  private static boolean within(
    long fromUs, long toUs, long positionUs, long durationUs, boolean looping) {
    if (positionUs >= fromUs && positionUs < toUs) {
      return true;
    }
    // Near the end of a loop, the items at the start come next.
    long wrappedUs = positionUs - durationUs;
    return looping && wrappedUs >= fromUs && wrappedUs < toUs;
  }
}
