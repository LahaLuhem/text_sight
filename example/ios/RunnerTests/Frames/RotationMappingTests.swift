import CoreGraphics
import ImageIO
import Testing

@testable import text_sight

@Suite("Rotation mapping")
struct RotationMappingTests {
  /// Swapping `.right` and `.left` feeds Vision an upside-down image, which wrecks portrait while
  /// landscape still looks fine.
  @Test("Each quarter turn maps to its preview turn, Vision orientation and axes swap", arguments: [
    (angle: 0.0, turns: 0, orientation: CGImagePropertyOrientation.up, swapped: false),
    (angle: 90.0, turns: 1, orientation: .right, swapped: true),
    (angle: 180.0, turns: 2, orientation: .down, swapped: false),
    (angle: 270.0, turns: 3, orientation: .left, swapped: true),
  ])
  func quarterTurn(angle: CGFloat, turns: Int,
                   orientation: CGImagePropertyOrientation, swapped: Bool) {
    let mapped = PreviewGeometry.displayRotation(forCaptureAngle: angle)

    #expect(mapped.quarterTurns == turns)
    #expect(mapped.orientation == orientation)
    #expect(mapped.isQuarterTurned == swapped)
  }

  /// 450 wraps to 90, and a near-quarter angle rounds before the modulo.
  @Test("Angles outside a single turn normalize first", arguments: [
    (angle: 450.0, turns: 1),
    (angle: 89.6, turns: 1),
  ])
  func normalizes(angle: CGFloat, turns: Int) {
    #expect(PreviewGeometry.displayRotation(forCaptureAngle: angle).quarterTurns == turns)
  }
}
