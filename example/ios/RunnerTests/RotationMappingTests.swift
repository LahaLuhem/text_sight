import CoreGraphics
import ImageIO
import XCTest

@testable import text_sight

/// `TextSightCamera.displayRotation`: the coordinator's clockwise-to-upright angle mapped to
/// preview quarter-turns, the Vision orientation for the unrotated buffer, and the axes swap.
final class RotationMappingTests: XCTestCase {
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
    // 360 wraps to 0, 450 wraps to 90, and a near-quarter angle rounds before the modulo.
    XCTAssertEqual(TextSightCamera.displayRotation(forCaptureAngle: 360).quarterTurns, 0)
    XCTAssertEqual(TextSightCamera.displayRotation(forCaptureAngle: 450).quarterTurns, 1)
    XCTAssertEqual(TextSightCamera.displayRotation(forCaptureAngle: 89.6).quarterTurns, 1)
  }
}
