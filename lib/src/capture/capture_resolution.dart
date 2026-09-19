/// How many pixels the camera feeds the recognizer. Live camera only.
///
/// The camera picks the nearest size it actually has, so `TextSightCapture.imageSize` is what
/// really turned up.
enum CaptureResolution() {
  /// Fastest, misses small print.
  low,

  /// Default. Reads a document page without giving up much speed.
  medium,

  /// Most detail, slowest.
  high,
}
