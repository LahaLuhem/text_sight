import AVFoundation
import Testing

@testable import text_sight

/// The capture size is ours to pick, not the device's.
@Suite("Capture session preset")
struct SessionPresetTests {
  /// The fixed-size presets a rung can ask for, so the test can compare them.
  private static let pixels: [AVCaptureSession.Preset: Int] = [
    .vga640x480: 640 * 480,
    .hd1280x720: 1280 * 720,
    .hd1920x1080: 1920 * 1080,
    .hd4K3840x2160: 3840 * 2160,
  ]

  @Test("A session that can do 1080p is asked for it by name")
  func namesTheSize() throws {
    let session = AVCaptureSession()
    try #require(session.canSetSessionPreset(.hd1920x1080), "this host can't do 1080p")

    #expect(TextSightCamera.preset(for: session, resolution: .medium) == .hd1920x1080)
  }

  @Test("Each rung asks for more pixels than the one below")
  func rungsGrow() throws {
    let session = AVCaptureSession()
    let pixels = try [CaptureResolutionMessage.low, .medium, .high].map { rung in
      try #require(Self.pixels[TextSightCamera.preset(for: session, resolution: rung)])
    }

    #expect(zip(pixels, pixels.dropFirst()).allSatisfy { $0 < $1 }, "\(pixels)")
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
