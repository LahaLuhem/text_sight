/// Stand-ins for one recognition pass, carrying exactly the wire fields native emits.
///
/// Not the public `TextSightCapture`, whose `dart:ui` `Rect` and `Size` a `dart compile exe`
/// process can't load. Every candidate rebuilds the same stand-in, so only codec cost is measured.
library;

final class const BenchCapture({
  required final double imageWidth,
  required final double imageHeight,

  /// `0` to `3`, clockwise, to get the preview display-upright.
  required final int quarterTurns,
  required final List<BenchLine> lines,
});

/// One recognized line, box flattened into four normalized (`[0, 1]`, top-left) doubles.
final class const BenchLine({
  required final String text,
  required final double confidence,
  required final double left,
  required final double top,
  required final double width,
  required final double height,
});
