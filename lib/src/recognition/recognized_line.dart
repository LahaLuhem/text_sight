import 'dart:ui' show Rect;

import 'recognized_element.dart';

/// A single recognized line of text with its location and confidence.
///
/// The unit the recognizer emits per detection. Capture-agnostic: it carries no
/// notion of whether the pixels came from a live frame or a still image.
class RecognizedLine {
  /// The recognized text of this line.
  final String text;

  /// Recognition confidence in `[0, 1]`, or `null` when the engine supplies none
  /// for this line. Both Apple Vision and ML Kit provide a per-line value, though
  /// the scales are not guaranteed comparable across platforms. `null` means
  /// "unknown", not "low" — threshold against an explicit default
  /// (`(line.confidence ?? 1) >= min`), never compare `null` to a bound.
  final double? confidence;

  /// Bounding box normalized to `[0, 1]` with a top-left origin (the unified
  /// coordinate contract, converted natively), as a [Rect] for an overlay
  /// painter to map onto the preview.
  final Rect boundingBox;

  /// Word-level [RecognizedElement]s, or `null` when not provided.
  ///
  /// Reserved: `null` in v1 on every platform; population is a future additive
  /// change.
  final List<RecognizedElement>? elements;

  /// Creates a recognized line.
  const RecognizedLine({
    required this.text,
    required this.boundingBox,
    this.confidence,
    this.elements,
  });

  @override
  String toString() =>
      'RecognizedLine(text: $text, confidence: $confidence, '
      'boundingBox: $boundingBox, elements: $elements)';
}
