import CoreVideo
import ImageIO

/// A source-agnostic recognizer: callers just `await recognize` and never see a Vision request
/// type. Config arrives per call, so one instance serves both drivers with no shared state.
protocol TextRecognizer: Sendable {
  /// What this backend's per-line confidence behaves like. Read once, since the backend is picked
  /// once.
  var confidenceScale: ConfidenceScaleMessage { get }

  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData]
  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData]
}
