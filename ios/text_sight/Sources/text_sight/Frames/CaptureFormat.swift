import AVFoundation
import CoreVideo

enum CaptureFormat {
  /// `.high` is whatever the device fancies, so it only covers a missing preset.
  static func preset(for session: AVCaptureSession,
                     resolution: CaptureResolutionMessage) -> AVCaptureSession.Preset {
    let wanted: AVCaptureSession.Preset = switch resolution {
    case .low: .vga640x480
    case .medium: .hd1920x1080
    case .high: .hd4K3840x2160
    }

    return session.canSetSessionPreset(wanted) ? wanted : .high
  }

  /// The camera's own YUV when offered, else BGRA. YUV skips a conversion every frame and takes 1.5
  /// bytes a pixel instead of 4, and Vision and Flutter both read it as is. Video range first,
  /// since that's what the sensor gives.
  static func pixelFormat(from available: [OSType]) -> OSType {
    let offered = Set(available)
    let preferred: [OSType] = [
      kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
    ]

    return preferred.first(where: offered.contains) ?? kCVPixelFormatType_32BGRA
  }
}
