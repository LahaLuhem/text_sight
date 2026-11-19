import 'dart:ui' show Rect;

import 'darwin_options.dart';

/// Recognizer settings, shared by the live driver and the one-shot.
///
/// Vision-only knobs sit under [darwin], so nothing Android ignores can be set without naming the
/// platform. The torch lives on the controller. No `copyWith`, since clearing [roi] needs a sentinel.
final class const TextSightOptions({
  /// The scan box, a normalized `[0, 1]` top-left `Rect`, or `null` for the whole frame.
  ///
  /// A line counts if its centre's inside, and comes back whole even past the top or bottom edge.
  /// The sides still cut it. Live, a line on screen hangs on a little past the edge so it doesn't
  /// blink. Boxes are measured on the whole frame.
  ///
  /// Both engines shrink a big frame before reading it, but a box is read at its own size, so it
  /// reads smaller text than the whole frame does.
  final Rect? roi,

  /// Settings only Apple Vision honours.
  final DarwinOptions darwin = const DarwinOptions(),
}) {
  /// Defaults suit live scanning.
  this;

  @override
  String toString() => 'TextSightOptions(roi: $roi, darwin: $darwin)';
}
