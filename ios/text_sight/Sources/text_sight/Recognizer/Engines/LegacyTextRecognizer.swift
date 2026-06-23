import Vision

/// Vision's legacy `VNRecognizeTextRequest` backend (iOS 13–17) — the fallback below the modern
/// API's iOS 18 floor, running the *same* Vision text engine. The request is reference-typed and
/// the handler's `perform` is *synchronous*: it runs on a dedicated serial queue and is bridged to
/// `async` via a continuation, so a blocking recognition never stalls a Swift-concurrency
/// cooperative thread. The single-in-flight backpressure upstream keeps the queue from backing up.
struct LegacyTextRecognizer: TextRecognizer {
  private let queue = DispatchQueue(label: "com.lahaluhem.text_sight.legacy-recognition")

  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    try await runOffCooperativePool {
      let request = Self.makeRequest(config: config)
      try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        .perform([request])

      return Self.lines(from: request)
    }
  }

  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    try await runOffCooperativePool {
      let request = Self.makeRequest(config: config)
      try VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        .perform([request])

      return Self.lines(from: request)
    }
  }

  /// Builds a fresh request from a config snapshot. Internal (not `private`) so `RunnerTests` can
  /// exercise it via `@testable import`.
  static func makeRequest(config: RecognitionConfig) -> VNRecognizeTextRequest {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = config.level == .accurate ? .accurate : .fast
    // Mirror the Dart `RecognitionLevel` enhanced-enum contract: accurate corrects, fast does not.
    request.usesLanguageCorrection = config.level == .accurate
    if !config.languages.isEmpty {
      // The legacy request takes BCP-47 language strings directly (no `Locale.Language`).
      request.recognitionLanguages = config.languages
    }
    if let roi = config.roi {
      // Vision's region-of-interest is lower-left normalized; flip the incoming top-left rect.
      request.regionOfInterest = CGRect(x: roi.left, y: 1 - (roi.top + roi.height),
                                        width: roi.width, height: roi.height)
    }

    return request
  }

  /// Runs the blocking `work` on the recognition queue, bridged to `async` — keeps the synchronous
  /// Vision perform off the cooperative pool.
  private func runOffCooperativePool(
    _ work: @escaping () throws -> [RecognizedLineData]
  ) async throws -> [RecognizedLineData] {
    try await withCheckedThrowingContinuation { continuation in
      queue.async { continuation.resume(with: Result(catching: work)) }
    }
  }

  /// Maps each observation's top candidate to a neutral line, flipping Vision's lower-left
  /// normalized box to the top-left-normalized one the wire contract expects.
  private static func lines(from request: VNRecognizeTextRequest) -> [RecognizedLineData] {
    (request.results ?? []).compactMap { observation -> RecognizedLineData? in
      guard let candidate = observation.topCandidates(1).first else { return nil }

      // Lower-left -> top-left: the box's top edge (maxY in lower-left) becomes 1 - maxY.
      let bounds = observation.boundingBox
      let box = CGRect(x: bounds.minX, y: 1 - bounds.maxY,
                       width: bounds.width, height: bounds.height)

      return RecognizedLineData(text: candidate.string,
                                confidence: Double(candidate.confidence), box: box)
    }
  }
}
