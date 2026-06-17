import 'dart:ui' show Size;

import 'recognized_line.dart';

/// The result of one recognition pass — every [RecognizedLine] found plus the size of the image they were located in.
///
/// Capture-agnostic by design: the same type is delivered by the live stream and by the static one-shot,
/// carrying no hint of where the pixels came from. Map a line's normalized [RecognizedLine.boundingBox]
/// into widget space using [imageSize] and whatever fit displays the preview.
class TextSightCapture {
  /// The recognized lines, in the recognizer's emission order.
  final List<RecognizedLine> lines;

  /// Pixel size of the analyzed image, in the same orientation as the lines' normalized boxes (post-rotation).
  final Size imageSize;

  /// Creates a capture.
  const TextSightCapture({required this.lines, required this.imageSize});

  @override
  String toString() => 'TextSightCapture(lines: $lines, imageSize: $imageSize)';
}
