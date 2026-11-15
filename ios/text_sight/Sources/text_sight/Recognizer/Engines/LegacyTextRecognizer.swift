import Vision

/// Vision's older `VNRecognizeTextRequest` backend for iOS 15-17, same text engine as the modern
/// one. Its `perform` is synchronous, so it gets its own serial queue and a continuation to bridge
/// to `async`, keeping a slow read off Swift concurrency's shared threads.
struct LegacyTextRecognizer: TextRecognizer {
  /// This backend grades its confidences, unlike the modern one.
  let confidenceScale = ConfidenceScaleMessage.visionGraded

  private let queue = DispatchQueue(label: "com.lahaluhem.text_sight.legacy-recognition")

  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    try await runOffCooperativePool {
      let request = Self.makeRequest(config: config)
      try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        .perform([request])

      return Self.lines(from: request, in: config.region)
    }
  }

  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    try await runOffCooperativePool {
      let request = Self.makeRequest(config: config)
      try VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        .perform([request])

      return Self.lines(from: request, in: config.region)
    }
  }

  /// Sets every knob, since anything left alone picks up Vision's own default.
  /// Internal so the tests can reach it.
  static func makeRequest(config: RecognitionConfig) -> VNRecognizeTextRequest {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = config.level == .accurate ? .accurate : .fast
    request.usesLanguageCorrection = config.usesLanguageCorrection
    // Empty means no preference, so it goes through rather than being guarded away.
    request.recognitionLanguages = config.languages
    request.minimumTextHeight = config.visionTextHeightFraction
    request.regionOfInterest = config.region.visionRect

    return request
  }

  private func runOffCooperativePool(
    _ work: @escaping () throws -> [RecognizedLineData]
  ) async throws -> [RecognizedLineData] {
    try await withCheckedThrowingContinuation { continuation in
      queue.async { continuation.resume(with: Result(catching: work)) }
    }
  }

  /// Maps each observation's top candidate to a neutral line, its box moved onto the frame.
  private static func lines(from request: VNRecognizeTextRequest,
                            in region: FrameRegion) -> [RecognizedLineData] {
    (request.results ?? []).compactMap { observation -> RecognizedLineData? in
      guard let candidate = observation.topCandidates(1).first else { return nil }

      return RecognizedLineData(text: candidate.string,
                                confidence: Double(candidate.confidence),
                                box: region.toFrame(observation.boundingBox))
    }
  }
}
