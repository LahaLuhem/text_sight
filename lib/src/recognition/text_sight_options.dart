import 'dart:ui' show Rect;

import 'darwin_options.dart';

/// Recognizer settings, shared by the live driver and the one-shot.
///
/// Only [roi] works everywhere. Vision-only knobs sit under [darwin], so you can't reach a setting
/// a platform ignores without naming that platform. No `copyWith`, since clearing [roi] would need
/// a sentinel.
final class const TextSightOptions({
  /// The scan box, normalized `[0, 1]` from the top-left, or `null` for the whole frame. Vision
  /// gets a real region. Android crops the still, and on the live path keeps whichever lines have
  /// their centre inside.
  final Rect? roi,

  /// Settings only Apple Vision honours.
  final DarwinOptions darwin = const DarwinOptions(),
}) {
  /// Defaults suit live capture.
  this;

  @override
  String toString() => 'TextSightOptions(roi: $roi, darwin: $darwin)';
}
