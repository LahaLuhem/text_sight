import 'dart:ui' show Rect;

/// A piece of a line, usually a word, with its own text and box.
///
/// Not filled in yet, so `RecognizedLine.elements` is `null`. The type ships early so adding words
/// later breaks nothing.
final class const RecognizedElement({
  /// The recognized text of this element.
  required final String text,

  /// The element's box, as a fraction `[0, 1]` of the image from the top left.
  required final Rect boundingBox,

  /// How sure the engine is, in `[0, 1]`, or `null` when it doesn't say. `null` means unknown, not
  /// low, so pick a default before comparing it to a threshold.
  final double? confidence,
}) {
  /// Creates a recognized element.
  this;

  @override
  String toString() =>
      'RecognizedElement(text: $text, boundingBox: $boundingBox, '
      'confidence: $confidence)';
}
