import CoreGraphics
import ImageIO
import Testing

@testable import text_sight

/// `TextSightCamera.displayRotation`: the coordinator's clockwise-to-upright angle mapped to
/// preview quarter-turns, the Vision orientation for the unrotated buffer, and the axes swap.
@Suite("Rotation mapping")
struct RotationMappingTests {
  /// Back camera: a 90 degree clockwise-to-upright angle (portrait) is EXIF `.right`, and the
  /// opposite quarter-turn is `.left`. Swapping those two feeds Vision a 180-rotated image, which
  /// wrecks portrait recognition while landscape still looks fine.
  @Test("Each quarter turn maps to its preview turn, Vision orientation and axes swap", arguments: [
    (angle: 0.0, turns: 0, orientation: CGImagePropertyOrientation.up, swapped: false),
    (angle: 90.0, turns: 1, orientation: .right, swapped: true),
    (angle: 180.0, turns: 2, orientation: .down, swapped: false),
    (angle: 270.0, turns: 3, orientation: .left, swapped: true),
  ])
  func quarterTurn(angle: CGFloat, turns: Int,
                   orientation: CGImagePropertyOrientation, swapped: Bool) {
    let mapped = TextSightCamera.displayRotation(forCaptureAngle: angle)

    #expect(mapped.quarterTurns == turns)
    #expect(mapped.orientation == orientation)
    #expect(mapped.isQuarterTurned == swapped)
  }

  /// 360 wraps to 0, 450 wraps to 90, and a near-quarter angle rounds before the modulo.
  @Test("Angles outside a single turn normalize first", arguments: [
    (angle: 360.0, turns: 0),
    (angle: 450.0, turns: 1),
    (angle: 89.6, turns: 1),
  ])
  func normalizes(angle: CGFloat, turns: Int) {
    #expect(TextSightCamera.displayRotation(forCaptureAngle: angle).quarterTurns == turns)
  }
}
