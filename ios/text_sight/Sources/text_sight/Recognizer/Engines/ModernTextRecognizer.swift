import Vision

/// Vision's Swift `RecognizeTextRequest` backend — value-typed, `async`, `Sendable` (the WWDC 2024
/// API, iOS 18+). Mirrors `RecognizedTextObservation`s into the neutral `RecognizedLineData`.
@available(iOS 18, *)
struct ModernTextRecognizer: TextRecognizer {
  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    let observations = try await Self.makeRequest(config: config)
      .perform(on: pixelBuffer, orientation: orientation)

    return Self.lines(from: observations)
  }

  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    let observations = try await Self.makeRequest(config: config)
      .perform(on: cgImage, orientation: orientation)

    return Self.lines(from: observations)
  }

  /// Builds a fresh request from a config snapshot. A `RecognizeTextRequest` is a value type, so
  /// each frame/call gets its own (no shared mutable request to race). Internal (not `private`) so
  /// `RunnerTests` can exercise it via `@testable import`.
  static func makeRequest(config: RecognitionConfig) -> RecognizeTextRequest {
    var request = RecognizeTextRequest()
    request.recognitionLevel = config.level == .accurate ? .accurate : .fast
    // Mirror the Dart `RecognitionLevel` enhanced-enum contract: accurate corrects, fast does not.
    request.usesLanguageCorrection = config.level == .accurate
    if !config.languages.isEmpty {
      request.recognitionLanguages = config.languages.map { Locale.Language(identifier: $0) }
    }
    if let roi = config.roi {
      // Vision's region-of-interest is lower-left normalized; flip the incoming top-left rect.
      request.regionOfInterest = NormalizedRect(x: roi.left, y: 1 - (roi.top + roi.height),
                                                width: roi.width, height: roi.height)
    }

    return request
  }

  /// Maps each observation's top candidate to a neutral line, converting Vision's lower-left
  /// normalized box to the top-left-normalized one the wire contract expects.
  private static func lines(from observations: [RecognizedTextObservation]) -> [RecognizedLineData] {
    observations.compactMap { observation -> RecognizedLineData? in
      guard let candidate = observation.topCandidates(1).first else { return nil }

      // A unit image size turns the lower-left normalized box into a top-left normalized one.
      let box = observation.boundingBox.toImageCoordinates(Self.normalizedUnitSize, origin: .upperLeft)

      return RecognizedLineData(text: candidate.string,
                                confidence: Double(candidate.confidence), box: box)
    }
  }

  private static let normalizedUnitSize = CGSize(width: 1, height: 1)
}
