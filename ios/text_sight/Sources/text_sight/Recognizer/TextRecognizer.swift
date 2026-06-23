import CoreVideo
import ImageIO

/// A source-agnostic text recognizer: callers (the live path and the one-shot) just `await
/// recognize` and never see a Vision request type. Stateless with respect to config — it is passed
/// per call — so one instance is shared by both drivers and is free of cross-thread races.
protocol TextRecognizer: Sendable {
  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData]
  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData]
}
