import 'dart:ui' show Rect;

/// A sub-line recognition unit (typically a word) with its own text and box.
///
/// Reserved for a future release: the model shape carries it from v1 so that
/// populating word-level detail later is an additive change, but
/// `RecognizedLine.elements` stays `null` until that feature ships. The
/// contract mirrors a line, one level down.
final class const RecognizedElement({
  /// The recognized text of this element.
  required final String text,

  /// Bounding box normalized to `[0, 1]` with a top-left origin (the unified
  /// coordinate contract), as a [Rect] for direct use by an overlay painter.
  required final Rect boundingBox,

  /// Recognition confidence in `[0, 1]`, or `null` when the platform does not
  /// supply one. `null` means "unknown", not "low", so never compare it to a
  /// threshold without choosing an explicit default.
  final double? confidence,
}) {
  /// Creates a recognized element.
  this;

  @override
  String toString() =>
      'RecognizedElement(text: $text, boundingBox: $boundingBox, '
      'confidence: $confidence)';
}
