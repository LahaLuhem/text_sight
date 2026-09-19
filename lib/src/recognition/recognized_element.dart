import 'dart:ui' show Rect;

/// A word-sized piece of a line, with its own box.
///
/// Reserved. The shape ships now so filling it in later is additive, but `RecognizedLine.elements`
/// stays `null` until then.
final class const RecognizedElement({
  /// What it reads.
  required final String text,

  /// Normalized to `[0, 1]` from the top-left, so an overlay painter can map it straight onto the
  /// preview.
  required final Rect boundingBox,

  /// `[0, 1]`, or `null` when the platform doesn't give one. `null` means unknown, not low, so
  /// don't feed it to a threshold without picking a default first.
  final double? confidence,
}) {
  /// Creates it.
  this;

  @override
  String toString() =>
      'RecognizedElement(text: $text, boundingBox: $boundingBox, '
      'confidence: $confidence)';
}
