import 'dart:ui' show Size;

import 'recognized_line.dart';

/// The result of one recognition pass — every [RecognizedLine] found plus the size of the image they were located in.
///
/// Capture-agnostic by design: the same type is delivered by the live stream and by the static one-shot,
/// carrying no hint of where the pixels came from. Map a line's normalized [RecognizedLine.boundingBox]
/// into widget space using [imageSize] and whatever fit displays the preview.
final class TextSightCapture {
  /// The recognized lines, in the recognizer's emission order.
  final List<RecognizedLine> lines;

  /// Pixel size of the analyzed image, in the same orientation as the lines' normalized boxes (post-rotation).
  final Size imageSize;

  /// Clockwise quarter-turns to rotate the *raw preview texture* so it aligns with the
  /// display-upright orientation [lines] and [imageSize] are already in. Live preview frames are
  /// delivered unrotated (cheaper, and avoids leaning on native buffer rotation); `TextSightView`
  /// applies this turn. `0` for an already-upright source such as the static one-shot.
  final int quarterTurns;

  /// Creates a capture.
  const TextSightCapture({required this.lines, required this.imageSize, this.quarterTurns = 0});

  @override
  String toString() =>
      'TextSightCapture(lines: $lines, imageSize: $imageSize, quarterTurns: $quarterTurns)';
}
