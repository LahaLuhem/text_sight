/// Stand-ins for one recognition pass, carrying exactly the wire fields the native side emits.
///
/// Not the public `TextSightCapture`: that holds `dart:ui` `Rect` / `Size`, which a
/// `dart compile exe` process cannot load. Every candidate rebuilds the same stand-in, so the
/// measurement isolates codec cost rather than object shape.
library;

/// One recognition pass: analyzed-image size, a display-rotation hint, and the recognized [lines].
final class BenchCapture {
  const new({
    required this.imageWidth,
    required this.imageHeight,
    required this.quarterTurns,
    required this.lines,
  });

  final double imageWidth;
  final double imageHeight;

  /// Clockwise quarter-turns to display-align the preview (`0`-`3`).
  final int quarterTurns;

  final List<BenchLine> lines;
}

/// One recognized line, with its box as four flat normalized (`[0, 1]`, top-left) doubles.
final class BenchLine {
  const new({
    required this.text,
    required this.confidence,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String text;

  /// `null` when the platform supplies none.
  final double? confidence;

  final double left;
  final double top;
  final double width;
  final double height;
}
