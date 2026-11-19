import CoreGraphics
import ImageIO

enum PreviewGeometry {
  /// The coordinator's clockwise-to-upright `angle` as preview turns, the Vision orientation for
  /// the unturned buffer, and whether width and height swap. If a device shows the preview turned
  /// wrong, look here first.
  static func displayRotation(forCaptureAngle angle: CGFloat)
    -> (quarterTurns: Int, orientation: CGImagePropertyOrientation, isQuarterTurned: Bool) {
    switch (Int(angle.rounded()) % 360 + 360) % 360 {
    // Back camera: 90° clockwise-to-upright (portrait) is EXIF `.right`, 270° is `.left`. Swap them
    // and Vision gets a 180°-rotated image, wrecking portrait while landscape still looks fine.
    case 90: return (1, .right, true)
    case 180: return (2, .down, false)
    case 270: return (3, .left, true)
    default: return (0, .up, false)
    }
  }
}
