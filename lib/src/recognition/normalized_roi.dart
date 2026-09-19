import 'dart:ui' show Rect;

/// Range checking for a region-of-interest rect.
extension NormalizedRoi on Rect? {
  /// `null` means the whole frame. Anything else has to sit inside `[0, 1]` from the top-left and
  /// have some size. Lives here rather than in `TextSightOptions`, whose `const` constructor can't
  /// run a check.
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
