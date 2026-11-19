import CoreVideo
import ImageIO

/// Keeps Vision's request types behind one `recognize`. Config comes with each call, so one
/// instance serves both drivers with nothing shared.
protocol TextRecognizer: Sendable {
  /// How this backend's line confidences behave. Fixed, since the backend is picked once.
  var confidenceScale: ConfidenceScaleMessage { get }

  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData]
  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData]
}
