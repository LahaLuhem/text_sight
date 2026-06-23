import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Vision

/// One recognized line of text, platform-neutral: the string, a confidence in `[0, 1]`, and a
/// top-left-normalized bounding box. Each Vision backend maps its own observation type to this, so
/// `TextSightCamera.encodeFrame` and the per-frame wire `Map` never touch a Vision type — the
/// backend divergence is contained behind the `TextRecognizer` seam.
struct RecognizedLineData {
  let text: String
  /// `[0, 1]`. Vision always supplies a per-candidate confidence, so this is never synthesized.
  let confidence: Double
  /// Top-left-normalized `[0, 1]` — `minX` / `minY` are the box's left / top.
  let box: CGRect
}

/// A recognizer-config snapshot, decoupled from the Pigeon wire types so a single value carries it
/// across the recognition `Task`. Mirrors the live-tunable knobs (`updateX` on the controller) and
/// the one-shot's per-call options.
struct RecognitionConfig {
  let level: RecognitionLevelMessage
  let languages: [String]
  let roi: RegionOfInterestMessage?
}

/// A source-agnostic text recognizer: callers (the live path and the one-shot) just `await
/// recognize` and never see a Vision request type. Stateless with respect to config — it is passed
/// per call — so one instance is shared by both drivers and is free of cross-thread races.
protocol TextRecognizer: Sendable {
  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData]
  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData]
}

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

/// Picks the recognizer backend once, by OS: the modern Swift `RecognizeTextRequest` on iOS 18+,
/// the legacy `VNRecognizeTextRequest` on iOS 13–17. This `#available` is the *only* version gate;
/// resolving it once (at `TextSightCamera` init) keeps it out of the per-frame path.
enum TextRecognizerFactory {
  static func make() -> any TextRecognizer {
    if #available(iOS 18, *) {
      return ModernTextRecognizer()
    } else {
      return LegacyTextRecognizer()
    }
  }
}
