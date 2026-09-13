import 'dart:ui' show Size;

import 'recognized_line.dart';

/// The result of one recognition pass: every [RecognizedLine] found plus the size of the image they were located in.
///
/// The same type comes from the live stream and the one-shot, with no hint of where the pixels
/// came from. Map a normalized [RecognizedLine.boundingBox] into widget space with [imageSize] and
/// whatever fit shows the preview.
final class const TextSightCapture({
  /// The recognized lines, in the recognizer's emission order.
  required final List<RecognizedLine> lines,

  /// Pixel size of the analyzed image, in the same orientation as the lines' normalized boxes (post-rotation).
  required final Size imageSize,

  /// Clockwise quarter-turns to rotate the *raw preview texture* so it aligns with the
  /// display-upright orientation [lines] and [imageSize] are already in. Live preview frames are
  /// delivered unrotated (cheaper, and avoids leaning on native buffer rotation). `TextSightView`
  /// applies this turn. `0` for an already-upright source such as the static one-shot.
  final int quarterTurns = 0,
}) {
  /// Creates a capture.
  this;

  @override
  String toString() =>
      'TextSightCapture(lines: $lines, imageSize: $imageSize, quarterTurns: $quarterTurns)';
}
