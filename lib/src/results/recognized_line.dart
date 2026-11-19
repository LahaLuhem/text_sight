import 'dart:ui' show Rect;

import 'recognized_element.dart';

/// One line of text, where it sits, and how sure the engine is about it.
final class const RecognizedLine({
  /// The recognized text of this line.
  required final String text,

  /// The line's box, as a fraction `[0, 1]` of the image from the top left, on every platform.
  required final Rect boundingBox,

  /// How sure the engine is, in `[0, 1]`.
  ///
  /// What it means depends on `TextSightEngine.confidenceScale`, and numbers from different scales
  /// don't compare.
  required final double confidence,

  /// The line's words. Always `null` for now, see [RecognizedElement].
  final List<RecognizedElement>? elements,
}) {
  /// Creates a recognized line.
  this;

  @override
  String toString() =>
      'RecognizedLine(text: $text, confidence: $confidence, '
      'boundingBox: $boundingBox, elements: $elements)';
}
