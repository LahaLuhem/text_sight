import Vision

/// Vision's Swift `RecognizeTextRequest` backend, the WWDC 2024 API for iOS 18+.
@available(iOS 18, *)
struct ModernTextRecognizer: TextRecognizer {
  /// This backend hands back coarse values, frequently exactly 1.0.
  let confidenceScale = ConfidenceScaleMessage.visionCoarse

  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    let observations = try await Self.makeRequest(config: config)
      .perform(on: pixelBuffer, orientation: orientation)

    return Self.lines(from: observations, in: config.region)
  }

  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    let observations = try await Self.makeRequest(config: config)
      .perform(on: cgImage, orientation: orientation)

    return Self.lines(from: observations, in: config.region)
  }

  /// Sets every knob, since anything left alone picks up Vision's own default.
  /// Internal so the tests can reach it.
  static func makeRequest(config: RecognitionConfig) -> RecognizeTextRequest {
    var request = RecognizeTextRequest()
    request.recognitionLevel = config.level == .accurate ? .accurate : .fast
    request.usesLanguageCorrection = config.usesLanguageCorrection
    // Empty means no preference, so it goes through rather than being guarded away.
    request.recognitionLanguages = config.languages.map { Locale.Language(identifier: $0) }
    request.minimumTextHeightFraction = config.visionTextHeightFraction
    request.regionOfInterest = NormalizedRect(normalizedRect: config.region.visionRect)

    return request
  }

  /// Maps each observation's top candidate to a neutral line, its box moved onto the frame.
  private static func lines(from observations: [RecognizedTextObservation],
                            in region: FrameRegion) -> [RecognizedLineData] {
    observations.compactMap { observation -> RecognizedLineData? in
      guard let candidate = observation.topCandidates(1).first else { return nil }

      return RecognizedLineData(text: candidate.string,
                                confidence: Double(candidate.confidence),
                                box: region.toFrame(observation.boundingBox.cgRect))
    }
  }
}
