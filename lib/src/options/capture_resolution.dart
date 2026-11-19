/// How many pixels the camera feeds the recognizer. Live camera only.
///
/// More pixels read smaller text and cost frame rate, up to a point: both engines shrink a big
/// frame before reading it. The camera picks the nearest size it has, so read
/// `TextSightCapture.imageSize` for what actually arrived.
enum CaptureResolution() {
  /// Fastest, misses small print.
  low,

  /// Default. Reads a document page without giving up much speed.
  medium,

  /// Most detail, slowest. For small print, pair it with a scan box (`TextSightOptions.roi`).
  high,
}
