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

    let left = TextSightCamera.displayRotation(forCaptureAngle: 90)
    XCTAssertEqual(left.quarterTurns, 1)
    XCTAssertEqual(left.orientation, .left)
    XCTAssertTrue(left.isQuarterTurned)

    let down = TextSightCamera.displayRotation(forCaptureAngle: 180)
    XCTAssertEqual(down.quarterTurns, 2)
    XCTAssertEqual(down.orientation, .down)
    XCTAssertFalse(down.isQuarterTurned)

    let right = TextSightCamera.displayRotation(forCaptureAngle: 270)
    XCTAssertEqual(right.quarterTurns, 3)
    XCTAssertEqual(right.orientation, .right)
    XCTAssertTrue(right.isQuarterTurned)
  }

  func testDisplayRotationNormalizesOutOfRangeAngles() {
    // 360 wraps to 0; 450 wraps to 90; a near-quarter angle rounds before the modulo.
    XCTAssertEqual(TextSightCamera.displayRotation(forCaptureAngle: 360).quarterTurns, 0)
    XCTAssertEqual(TextSightCamera.displayRotation(forCaptureAngle: 450).quarterTurns, 1)
    XCTAssertEqual(TextSightCamera.displayRotation(forCaptureAngle: 89.6).quarterTurns, 1)
  }

  // MARK: makeRequest — config snapshot -> Vision RecognizeTextRequest

  func testMakeRequestFastLevelDisablesLanguageCorrection() {
    let request = TextSightCamera.makeRequest(level: .fast, languages: [], roi: nil)

    XCTAssertEqual(request.recognitionLevel, .fast)
    XCTAssertFalse(request.usesLanguageCorrection)
  }

  func testMakeRequestAccurateLevelEnablesLanguageCorrection() {
    let request = TextSightCamera.makeRequest(level: .accurate, languages: [], roi: nil)

    XCTAssertEqual(request.recognitionLevel, .accurate)
    XCTAssertTrue(request.usesLanguageCorrection)
  }

  func testMakeRequestMapsLanguagesInPreferenceOrder() {
    let request = TextSightCamera.makeRequest(level: .fast, languages: ["en-US", "fr"], roi: nil)

    XCTAssertEqual(
      request.recognitionLanguages,
      [Locale.Language(identifier: "en-US"), Locale.Language(identifier: "fr")]
    )
  }

  func testMakeRequestFlipsRegionOfInterestToLowerLeft() {
    let roi = RegionOfInterestMessage(left: 0.1, top: 0.2, width: 0.3, height: 0.4)

    let request = TextSightCamera.makeRequest(level: .fast, languages: [], roi: roi)

    // Vision's region-of-interest is lower-left normalized: y = 1 - (top + height).
    let region = request.regionOfInterest
    XCTAssertEqual(region.origin.x, 0.1, accuracy: 1e-9)
    XCTAssertEqual(region.origin.y, 0.4, accuracy: 1e-9)
    XCTAssertEqual(region.width, 0.3, accuracy: 1e-9)
    XCTAssertEqual(region.height, 0.4, accuracy: 1e-9)
  }
}
