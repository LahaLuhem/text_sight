import 'dart:ui' show Size;

import 'recognized_line.dart';

/// One recognition pass: every [RecognizedLine] found, plus the size of the image they came from.
///
/// Live and one-shot results look the same. In `TextSightView`'s overlay, scale a
/// [RecognizedLine.boundingBox] by the overlay's constraints. Over your own image, use [imageSize]
/// and your fit.
final class const TextSightCapture({
  /// The recognized lines, in the recognizer's order.
  required final List<RecognizedLine> lines,

  /// The analyzed image's pixel size, in the boxes' orientation.
  required final Size imageSize,

  /// Clockwise quarter turns that bring the analyzed frame upright. `0` for a still.
  @Deprecated('TextSightView turns the preview itself. Removed in the next major.')
  final int quarterTurns = 0,
}) {
  /// Creates a capture.
  this;

  @override
  String toString() => 'TextSightCapture(lines: $lines, imageSize: $imageSize)';
}
