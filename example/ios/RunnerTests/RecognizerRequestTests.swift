import CoreGraphics
import Vision
import XCTest

@testable import text_sight

/// `makeRequest` on both Vision backends: a config snapshot mapped to the request that runs it.
/// The modern half is iOS 18+, so it is skipped on older runtimes; the legacy half runs everywhere.
final class RecognizerRequestTests: XCTestCase {
  // (iOS 18+ only: `ModernTextRecognizer` is `@available(iOS 18, *)`, skipped on older runtimes).

  @available(iOS 18, *)
  func testMakeRequestFastLevelDisablesLanguageCorrection() {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: [], roi: nil)
    )

    XCTAssertEqual(request.recognitionLevel, .fast)
    XCTAssertFalse(request.usesLanguageCorrection)
  }

  @available(iOS 18, *)
  func testMakeRequestAccurateLevelEnablesLanguageCorrection() {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .accurate, languages: [], roi: nil)
    )

    XCTAssertEqual(request.recognitionLevel, .accurate)
    XCTAssertTrue(request.usesLanguageCorrection)
  }

  @available(iOS 18, *)
  func testMakeRequestMapsLanguagesInPreferenceOrder() {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: ["en-US", "fr"], roi: nil)
    )

    XCTAssertEqual(
      request.recognitionLanguages,
      [Locale.Language(identifier: "en-US"), Locale.Language(identifier: "fr")]
    )
  }

  @available(iOS 18, *)
  func testMakeRequestFlipsRegionOfInterestToLowerLeft() {
    let roi = RegionOfInterestMessage(left: 0.1, top: 0.2, width: 0.3, height: 0.4)

    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: [], roi: roi)
    )

    // Vision's region-of-interest is lower-left normalized: y = 1 - (top + height).
    let region = request.regionOfInterest
    XCTAssertEqual(region.origin.x, 0.1, accuracy: 1e-9)
    XCTAssertEqual(region.origin.y, 0.4, accuracy: 1e-9)
    XCTAssertEqual(region.width, 0.3, accuracy: 1e-9)
    XCTAssertEqual(region.height, 0.4, accuracy: 1e-9)
  }

  // MARK: LegacyTextRecognizer.makeRequest

  func testLegacyMakeRequestFastLevelDisablesLanguageCorrection() {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: [], roi: nil)
    )

    XCTAssertEqual(request.recognitionLevel, .fast)
    XCTAssertFalse(request.usesLanguageCorrection)
  }

  func testLegacyMakeRequestAccurateLevelEnablesLanguageCorrection() {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .accurate, languages: [], roi: nil)
    )

    XCTAssertEqual(request.recognitionLevel, .accurate)
    XCTAssertTrue(request.usesLanguageCorrection)
  }

  func testLegacyMakeRequestPassesLanguagesThroughInOrder() {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: ["en-US", "fr"], roi: nil)
    )

    XCTAssertEqual(request.recognitionLanguages, ["en-US", "fr"])
  }

  func testLegacyMakeRequestFlipsRegionOfInterestToLowerLeft() {
    let roi = RegionOfInterestMessage(left: 0.1, top: 0.2, width: 0.3, height: 0.4)

    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: [], roi: roi)
    )

    // Vision's region-of-interest is lower-left normalized: y = 1 - (top + height).
    let region = request.regionOfInterest
    XCTAssertEqual(region.origin.x, 0.1, accuracy: 1e-9)
    XCTAssertEqual(region.origin.y, 0.4, accuracy: 1e-9)
    XCTAssertEqual(region.width, 0.3, accuracy: 1e-9)
    XCTAssertEqual(region.height, 0.4, accuracy: 1e-9)
  }
}
