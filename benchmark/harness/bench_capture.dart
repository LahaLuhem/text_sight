/// In-memory stand-ins for one recognition pass, carrying exactly the wire
/// fields the native side emits on the captures `EventChannel` (decoded today
/// by `_decodeCapture` in `pigeon_text_sight_platform.dart`).
///
/// The benchmark uses these rather than the public `TextSightCapture` /
/// `RecognizedLine` because those hold `dart:ui` `Rect` / `Size`, which are
/// unavailable in a pure-Dart (`dart compile exe`) process. Every candidate
/// reconstructs the *same* stand-in, so the measurement isolates codec cost,
/// not object shape — and building a `Rect` is comparably cheap to the four
/// flat doubles here.
library;

/// One recognition pass: the analyzed-image size, a display-rotation hint, and the recognized [lines].
final class BenchCapture {
  /// Creates a capture.
  const BenchCapture({
    required this.imageWidth,
    required this.imageHeight,
    required this.quarterTurns,
    required this.lines,
  });

  /// Analyzed-image width, in pixels.
  final double imageWidth;

  /// Analyzed-image height, in pixels.
  final double imageHeight;

  /// Clockwise quarter-turns to display-align the preview (`0`–`3`).
  final int quarterTurns;

  /// The recognized lines, in emission order.
  final List<BenchLine> lines;
}

/// One recognized line: its [text], optional [confidence], and a normalized (`[0, 1]`, top-left origin)
/// bounding box as four flat doubles.
final class BenchLine {
  /// Creates a line.
  const BenchLine({
    required this.text,
    required this.confidence,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// The recognized text.
  final String text;

  /// Confidence in `[0, 1]`, or `null` when the platform supplies none.
  final double? confidence;

  /// Normalized box left edge.
  final double left;

  /// Normalized box top edge.
  final double top;

  /// Normalized box width.
  final double width;

  /// Normalized box height.
  final double height;
}
