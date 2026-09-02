import AVFoundation
import CoreGraphics
import CoreVideo
import Flutter
import ImageIO
import XCTest

@testable import text_sight

// Shared fakes and fixtures for the RunnerTests target.

/// A blank BGRA buffer, all `handle` needs to stand in for a captured frame.
func makeTestPixelBuffer() throws -> CVPixelBuffer {
  var pixelBuffer: CVPixelBuffer?
  let code = CVPixelBufferCreate(kCFAllocatorDefault, 64, 48, kCVPixelFormatType_32BGRA, nil,
                                 &pixelBuffer)
  XCTAssertEqual(code, kCVReturnSuccess)

  return try XCTUnwrap(pixelBuffer)
}

/// Counts open capture configurations. AVFoundation reference-counts begin/commit and exposes no
/// way to read the depth, so mirror it here.
final class CountingCaptureSession: AVCaptureSession {
  private(set) var openConfigurations = 0

  override func beginConfiguration() {
    openConfigurations += 1
    super.beginConfiguration()
  }

  override func commitConfiguration() {
    openConfigurations -= 1
    super.commitConfiguration()
  }
}

/// Satisfies `TextSightCamera`'s texture dependency for the paths that never register a texture.
final class StubTextureRegistry: NSObject, FlutterTextureRegistry {
  func register(_ texture: FlutterTexture) -> Int64 { 1 }

  func textureFrameAvailable(_ textureId: Int64) {}

  func unregisterTexture(_ textureId: Int64) {}
}

/// Never finishes on its own: it parks until its task is cancelled. Lets a test hold a recognition
/// in flight and watch what teardown does to it.
final class ParkedRecognizer: TextRecognizer, @unchecked Sendable {
  let started = XCTestExpectation(description: "the first frame reached the recognizer")
  let cancelled = XCTestExpectation(description: "the parked recognition was cancelled")
  /// Inverted, so waiting on it asserts that no second frame ever got through the gate.
  let startedAgain: XCTestExpectation = {
    let expectation = XCTestExpectation(description: "a second frame reached the recognizer")
    expectation.isInverted = true

    return expectation
  }()

  private let lock = NSLock()
  private var starts = 0

  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    if isFirstStart() { started.fulfill() } else { startedAgain.fulfill() }

    do {
      // Long enough that only cancellation ends the wait.
      try await Task.sleep(nanoseconds: 30 * NSEC_PER_SEC)
    } catch {
      cancelled.fulfill()
      throw error
    }

    return []
  }

  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    XCTFail("the live path must not take the still-image entry point")

    return []
  }

  /// Counts this entry and says whether it was the first.
  private func isFirstStart() -> Bool {
    lock.withLock {
      starts += 1

      return starts == 1
    }
  }
}

/// Takes a fixed time and timestamps every entry, so a test can read the gap between them.
final class TimedRecognizer: TextRecognizer, @unchecked Sendable {
  private let latencyNanos: UInt64
  private let lock = NSLock()
  private var startNanos: [UInt64] = []

  init(latencyMs: Double) {
    latencyNanos = UInt64(latencyMs * 1_000_000)
  }

  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    lock.withLock { startNanos.append(DispatchTime.now().uptimeNanoseconds) }
    try await Task.sleep(nanoseconds: latencyNanos)

    return []
  }

  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    XCTFail("the live path must not take the still-image entry point")

    return []
  }

  /// (recognitions started, mean milliseconds between consecutive starts).
  func stats() -> (Int, Double) {
    lock.withLock {
      guard startNanos.count > 1 else { return (startNanos.count, 0) }
      let span = Double(startNanos[startNanos.count - 1] - startNanos[0]) / 1_000_000

      return (startNanos.count, span / Double(startNanos.count - 1))
    }
  }
}
