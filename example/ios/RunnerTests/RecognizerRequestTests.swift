import CoreGraphics
import Testing
import Vision

@testable import text_sight

/// `makeRequest` on both Vision backends: a config snapshot mapped to the request that runs it.
/// The modern half is iOS 18+, so it is skipped on older runtimes; the legacy half runs everywhere.
@Suite("Vision request mapping")
struct RecognizerRequestTests {
  /// One row per accuracy level: what Vision is asked for, and whether language correction rides
  /// along with it.
  static let levels: [(level: RecognitionLevelMessage, correction: Bool)] = [
    (level: .fast, correction: false),
    (level: .accurate, correction: true),
  ]

  /// The scan box every region-of-interest case uses, and where Vision should put it. Vision's
  /// region is lower-left normalized, so the expected y is 1 - (top + height).
  static let roi = RegionOfInterestMessage(left: 0.1, top: 0.2, width: 0.3, height: 0.4)
  static let flippedRoi = CGRect(x: 0.1, y: 0.4, width: 0.3, height: 0.4)

  static let languages = ["en-US", "fr"]

  @available(iOS 18, *)
  @Test("Modern: the level picks the Vision level and its language correction",
        arguments: RecognizerRequestTests.levels)
  func modernLevel(level: RecognitionLevelMessage, correction: Bool) {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: level, languages: [], roi: nil)
    )

    #expect(request.recognitionLevel == (level == .fast ? .fast : .accurate))
    #expect(request.usesLanguageCorrection == correction)
  }

  @available(iOS 18, *)
  @Test("Modern: languages map in preference order")
  func modernLanguages() {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: Self.languages, roi: nil)
    )

    #expect(request.recognitionLanguages == Self.languages.map(Locale.Language.init(identifier:)))
  }

  @available(iOS 18, *)
  @Test("Modern: the scan box flips into Vision's lower-left space")
  func modernRegion() {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: [], roi: Self.roi)
    )

    let region = request.regionOfInterest

    #expect(isClose(originX: region.origin.x, originY: region.origin.y,
                    width: region.width, height: region.height, to: Self.flippedRoi))
  }

  @Test("Legacy: the level picks the Vision level and its language correction",
        arguments: RecognizerRequestTests.levels)
  func legacyLevel(level: RecognitionLevelMessage, correction: Bool) {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: level, languages: [], roi: nil)
    )

    #expect(request.recognitionLevel == (level == .fast ? .fast : .accurate))
    #expect(request.usesLanguageCorrection == correction)
  }

  @Test("Legacy: languages pass through in order")
  func legacyLanguages() {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: Self.languages, roi: nil)
    )

    #expect(request.recognitionLanguages == Self.languages)
  }

  @Test("Legacy: the scan box flips into Vision's lower-left space")
  func legacyRegion() {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: [], roi: Self.roi)
    )

    let region = request.regionOfInterest

    #expect(isClose(originX: region.origin.x, originY: region.origin.y,
                    width: region.width, height: region.height, to: Self.flippedRoi))
  }
}

/// Corner-by-corner match with a float tolerance, since the lower-left flip carries sub-epsilon
/// error. Takes the components rather than a rect: the modern backend hands back Vision's
/// `NormalizedRect` and the legacy one a `CGRect`.
private func isClose(originX: Double, originY: Double, width: Double, height: Double,
                     to expected: CGRect, tolerance: Double = 1e-9) -> Bool {
  abs(originX - expected.origin.x) < tolerance && abs(originY - expected.origin.y) < tolerance
    && abs(width - expected.width) < tolerance && abs(height - expected.height) < tolerance
}
