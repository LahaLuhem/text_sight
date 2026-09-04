import Vision

/// Vision's Swift `RecognizeTextRequest` backend: value-typed, `async`, `Sendable` (the WWDC 2024
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

  /// Sets every knob, since anything left alone picks up Vision's own default.
  /// Internal so the tests can reach it.
  static func makeRequest(config: RecognitionConfig) -> RecognizeTextRequest {
    var request = RecognizeTextRequest()
    request.recognitionLevel = config.level == .accurate ? .accurate : .fast
    // Mirror the Dart `RecognitionLevel` enhanced-enum contract: accurate corrects, fast does not.
    request.usesLanguageCorrection = config.level == .accurate
    // Empty means no preference, so it goes through rather than being guarded away.
    request.recognitionLanguages = config.languages.map { Locale.Language(identifier: $0) }
    request.minimumTextHeightFraction = RecognitionConfig.minimumTextHeight
    // Vision's region is lower-left, so flip the top-left rect.
    request.regionOfInterest = config.roi.map {
      NormalizedRect(x: $0.left, y: 1 - ($0.top + $0.height), width: $0.width, height: $0.height)
    } ?? NormalizedRect(x: 0, y: 0, width: 1, height: 1)

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
