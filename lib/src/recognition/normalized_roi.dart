import 'dart:ui' show Rect;

/// Range validation for a region-of-interest [Rect] in the unified normalized
/// `[0, 1]`, top-left coordinate space.
extension NormalizedRoi on Rect? {
  /// Whether this is a valid region-of-interest: `null` (the whole frame), or a
  /// normalized `[0, 1]` rect with positive extent.
  ///
  /// Shared by both recognizer drivers — the live `TextSightController` and the
  /// static `TextSight` one-shot — which validate `TextSightOptions.roi` with a
  /// debug `assert` against this. The check lives on the consumer, not the
  /// `const` `TextSightOptions` constructor (which can't run one).
  bool get isNormalizedRoi {
    final roi = this;

    return roi == null ||
        (roi.left >= 0 &&
            roi.top >= 0 &&
            roi.right <= 1 &&
            roi.bottom <= 1 &&
            roi.width > 0 &&
            roi.height > 0);
  }
}
