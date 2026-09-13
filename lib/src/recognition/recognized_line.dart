import 'dart:ui' show Rect;

import 'recognized_element.dart';

/// A single recognized line of text with its location and confidence.
///
/// The unit the recognizer emits per detection. Capture-agnostic: it carries no
/// notion of whether the pixels came from a live frame or a still image.
final class const RecognizedLine({
  /// The recognized text of this line.
  required final String text,

  /// Bounding box normalized to `[0, 1]` with a top-left origin (the unified
  /// coordinate contract, converted natively), as a [Rect] for an overlay
  /// painter to map onto the preview.
  required final Rect boundingBox,

  /// How sure the engine is about this line, in `[0, 1]`.
  ///
  /// Engine-relative, not an absolute quality score: what a number means depends on
  /// `TextSightEngine.confidenceScale`, and values from different scales are never comparable.
  /// Both engines always supply one, so this is never null.
  required final double confidence,

  /// Word-level [RecognizedElement]s, or `null` when not provided.
  ///
  /// Reserved: `null` in v1 on every platform. Population is a future additive
  /// change.
  final List<RecognizedElement>? elements,
}) {
  /// Creates a recognized line.
  this;

  @override
  String toString() =>
      'RecognizedLine(text: $text, confidence: $confidence, '
      'boundingBox: $boundingBox, elements: $elements)';
}
