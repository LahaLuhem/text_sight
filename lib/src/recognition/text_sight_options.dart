import 'dart:ui' show Rect;

import 'darwin_options.dart';

/// What the recognizer needs, shared by the live driver and the one-shot.
///
/// Only [roi] works the same everywhere. Anything Vision alone can do sits under [darwin], so a
/// setting a platform ignores cannot be reached without naming that platform. Session-only things
/// like the torch live on the controller. No `copyWith`: clearing [roi] would need a sentinel.
final class const TextSightOptions({
  /// The scan box recognition is restricted to: a normalized `[0, 1]` top-left `Rect`, or `null`
  /// for the whole frame. Vision gets a true region. Android crops the still, and on the live path
  /// keeps the lines whose centre lands inside.
  final Rect? roi,

  /// Settings only Apple Vision honours. Android ignores every one of them.
  final DarwinOptions darwin = const DarwinOptions(),
}) {
  /// Creates recognizer options. Every field has a live-oriented default.
  this;

  @override
  String toString() => 'TextSightOptions(roi: $roi, darwin: $darwin)';
}
