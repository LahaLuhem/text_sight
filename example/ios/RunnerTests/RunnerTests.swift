import CoreGraphics
import Foundation
import ImageIO
import Vision
import XCTest

@testable import text_sight

/// Host-side (simulator) unit tests for the pure orientation- and request-mapping helpers in
/// `TextSightCamera`, reached via `@testable import`. No capture session or recognizer runs — only
/// the platform-independent logic behind the rotation contract and the Vision request config.
final class TextSightCameraTests: XCTestCase {
  // MARK: displayRotation — capture angle -> (quarterTurns, Vision orientation, axes-swap)

  func testDisplayRotationMapsEachQuarterTurn() {
    let up = TextSightCamera.displayRotation(forCaptureAngle: 0)
    XCTAssertEqual(up.quarterTurns, 0)
    XCTAssertEqual(up.orientation, .up)
    XCTAssertFalse(up.isQuarterTurned)

    let right = TextSightCamera.displayRotation(forCaptureAngle: 90)
    XCTAssertEqual(right.quarterTurns, 1)
    XCTAssertEqual(right.orientation, .right)
    XCTAssertTrue(right.isQuarterTurned)

    let down = TextSightCamera.displayRotation(forCaptureAngle: 180)
    XCTAssertEqual(down.quarterTurns, 2)
    XCTAssertEqual(down.orientation, .down)
    XCTAssertFalse(down.isQuarterTurned)

    let left = TextSightCamera.displayRotation(forCaptureAngle: 270)
    XCTAssertEqual(left.quarterTurns, 3)
    XCTAssertEqual(left.orientation, .left)
    XCTAssertTrue(left.isQuarterTurned)
  }

  func testDisplayRotationNormalizesOutOfRangeAngles() {
    // 360 wraps to 0; 450 wraps to 90; a near-quarter angle rounds before the modulo.
    XCTAssertEqual(TextSightCamera.displayRotation(forCaptureAngle: 360).quarterTurns, 0)
    XCTAssertEqual(TextSightCamera.displayRotation(forCaptureAngle: 450).quarterTurns, 1)
    XCTAssertEqual(TextSightCamera.displayRotation(forCaptureAngle: 89.6).quarterTurns, 1)
  }

  // MARK: ModernTextRecognizer.makeRequest — config snapshot -> Vision RecognizeTextRequest
  // (iOS 18+ only — `ModernTextRecognizer` is `@available(iOS 18, *)`; skipped on older runtimes).

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

  // MARK: LegacyTextRecognizer.makeRequest — config snapshot -> Vision VNRecognizeTextRequest

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

  // MARK: encodeFrame — neutral lines -> the cross-platform per-frame wire map

  func testEncodeFrameMapsLinesToWireKeys() {
    let line = RecognizedLineData(text: "hi", confidence: 0.5,
                                  box: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4))

    let frame = TextSightCamera.encodeFrame([line], imageWidth: 100, imageHeight: 200,
                                            quarterTurns: 1)

    XCTAssertEqual(frame["imageWidth"] as? Double, 100)
    XCTAssertEqual(frame["imageHeight"] as? Double, 200)
    XCTAssertEqual(frame["quarterTurns"] as? Int, 1)

    let encodedLines = frame["lines"] as? [[String: Any]]
    XCTAssertEqual(encodedLines?.count, 1)

    let encoded = encodedLines?.first
    XCTAssertEqual(encoded?["text"] as? String, "hi")
    XCTAssertEqual(encoded?["confidence"] as? Double, 0.5)
    XCTAssertEqual(encoded?["left"] as? Double, 0.1)
    XCTAssertEqual(encoded?["top"] as? Double, 0.2)
    XCTAssertEqual(encoded?["width"] as? Double, 0.3)
    XCTAssertEqual(encoded?["height"] as? Double, 0.4)
    XCTAssertTrue(encoded?["elements"] is NSNull)
  }
}
