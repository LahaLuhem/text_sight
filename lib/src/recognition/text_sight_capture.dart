import 'dart:ui' show Size;

import 'recognized_line.dart';

/// Everything one recognition pass found. Comes back the same from the live stream and from the
/// one-shot.
final class const TextSightCapture({
  /// In the order the recognizer emitted them.
  required final List<RecognizedLine> lines,

  /// Pixel size of the image that was analyzed, already turned the same way up as [lines].
  required final Size imageSize,

  /// Clockwise turns to get the raw preview texture upright, which [lines] and [imageSize] already
  /// are. `TextSightView` applies it for you. `0` when the source was upright to start with, like
  /// the one-shot.
  final int quarterTurns = 0,
}) {
  /// Creates it.
  this;

  @override
  String toString() =>
      'TextSightCapture(lines: $lines, imageSize: $imageSize, quarterTurns: $quarterTurns)';
}
