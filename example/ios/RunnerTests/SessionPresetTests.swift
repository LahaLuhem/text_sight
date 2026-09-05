import AVFoundation
import Testing

@testable import text_sight

/// The capture size is ours to pick, not the device's.
@Suite("Capture session preset")
struct SessionPresetTests {
  @Test("A session that can do 1080p is asked for it by name")
  func namesTheSize() {
    let session = AVCaptureSession()

    #expect(session.canSetSessionPreset(.hd1920x1080))
    #expect(TextSightCamera.preset(for: session, resolution: .medium) == .hd1920x1080)
  }

  @Test("Each rung asks for a different size")
  func rungsDiffer() {
    let session = AVCaptureSession()
    let presets = [CaptureResolutionMessage.low, .medium, .high]
      .map { TextSightCamera.preset(for: session, resolution: $0) }

    #expect(Set(presets).count == presets.count)
  }

  @Test("Hardware without it falls back instead of failing")
  func fallsBack() {
    #expect(TextSightCamera.preset(for: RefusingCaptureSession(), resolution: .medium) == .high)
  }
}

/// Stands in for a device that offers no 1080p format.
private final class RefusingCaptureSession: AVCaptureSession {
  override func canSetSessionPreset(_ preset: AVCaptureSession.Preset) -> Bool { false }
}
