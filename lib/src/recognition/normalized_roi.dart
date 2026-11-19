import 'dart:ui' show Rect;

/// Checks a scan box.
extension NormalizedRoi on Rect? {
  /// Whether this is `null` (the whole frame), or a rect inside `[0, 1]` with some area.
  ///
  /// Lives here because `TextSightOptions`'s `const` constructor can't run a check.
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
