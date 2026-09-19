import 'dart:ui' show Rect;

import 'recognized_element.dart';

/// One line of recognized text. Same shape whether the pixels came from a live frame or a still.
final class const RecognizedLine({
  /// What it reads.
  required final String text,

  /// Normalized to `[0, 1]` from the top-left, so an overlay painter can map it straight onto the
  /// preview.
  required final Rect boundingBox,

  /// How sure the engine is, in `[0, 1]`. Not an absolute quality score, so read
  /// `TextSightEngine.confidenceScale` for what the number is worth here.
  required final double confidence,

  /// Reserved, always `null` for now. See [RecognizedElement].
  final List<RecognizedElement>? elements,
}) {
  /// Creates it.
  this;

  @override
  String toString() =>
      'RecognizedLine(text: $text, confidence: $confidence, '
      'boundingBox: $boundingBox, elements: $elements)';
}
