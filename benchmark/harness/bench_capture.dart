/// Stand-ins for one recognition pass, carrying exactly the wire fields the native side emits.
///
/// Not the public `TextSightCapture`, whose `dart:ui` `Rect` / `Size` a `dart compile exe` process
/// cannot load. Every candidate rebuilds the same stand-in, so the measurement isolates codec cost.
library;

/// One recognition pass: analyzed-image size, a display-rotation hint, and the recognized [lines].
final class const BenchCapture({
  required final double imageWidth,
  required final double imageHeight,

  /// Clockwise quarter-turns to display-align the preview (`0`-`3`).
  required final int quarterTurns,
  required final List<BenchLine> lines,
});

/// One recognized line, with its box as four flat normalized (`[0, 1]`, top-left) doubles.
final class const BenchLine({
  required final String text,

  /// `null` when the platform supplies none.
  required final double confidence,
  required final double left,
  required final double top,
  required final double width,
  required final double height,
});
