import 'dart:ui' show Rect;

import 'darwin_options.dart';

/// What the recognizer needs, shared by the live driver and the one-shot.
///
/// Only [roi] works the same everywhere. Anything Vision alone can do sits under [darwin], so a
/// setting a platform ignores cannot be reached without naming that platform. Session-only things
/// like the torch live on the controller. No `copyWith`: clearing [roi] would need a sentinel.
final class const TextSightOptions({
  /// The scan box to read: a normalized `[0, 1]` top-left `Rect`, or `null` for the whole frame.
  ///
  /// Both platforms read only what's inside, so a line the box's edge crosses comes back cut. Line
  /// boxes are still measured on the whole frame.
  final Rect? roi,

  /// Settings only Apple Vision honours. Android ignores every one of them.
  final DarwinOptions darwin = const DarwinOptions(),
}) {
  /// Creates recognizer options. Every field has a live-oriented default.
  this;

  @override
  String toString() => 'TextSightOptions(roi: $roi, darwin: $darwin)';
}
