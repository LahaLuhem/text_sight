import AVFoundation
import CoreVideo
import Foundation
import XCTest

@testable import text_sight

/// The gate must not wait for a camera frame to start the next recognition. Driven through `handle`
/// at a fixed frame interval with a recognizer of known latency, so no camera is involved. Also
/// covers the other end: a frame arriving after teardown must not bring the consumer back to life.
final class FrameGateTests: XCTestCase {
  private static let frameIntervalMs = 30.0
  /// One and a half frame intervals: slow enough that the old gate had to skip a whole frame.
  private static let latencyMs = 45.0

  func testRecognitionPeriodTracksLatencyNotTheFrameInterval() async throws {
    let recognizer = TimedRecognizer(latencyMs: Self.latencyMs)
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(), recognizer: recognizer)
    _ = camera.onListen(withArguments: nil) { _ in }
    camera.start()
    let pixelBuffer = try makeTestPixelBuffer()

    // Fixed cadence off one start instant, so delivery cannot drift. Recognition runs on the
    // gate's consumer, so the test body can drive the frames itself.
    let start = DispatchTime.now()
    for index in 0..<50 {
      let deadline = start + .milliseconds(Int(Self.frameIntervalMs) * index)
      let now = DispatchTime.now()
      if deadline > now {
        try await Task.sleep(nanoseconds: deadline.uptimeNanoseconds - now.uptimeNanoseconds)
      }
      camera.handle(pixelBuffer)
    }
    // Let the recognition in flight finish before reading the timestamps.
    try await Task.sleep(nanoseconds: UInt64(Self.latencyMs * 2 * 1e6))
    try await camera.dispose()

    let (starts, period) = recognizer.stats()
    XCTAssertGreaterThan(starts, 10, "too few recognitions to judge a period")
    // Re-arming on the next frame instead of on completion would make this 2 x 30 = 60 ms.
    XCTAssertLessThan(period, Self.frameIntervalMs * 1.9,
                      "period \(period) ms is quantized to the frame interval")
    // And it cannot beat the recognizer itself.
    XCTAssertGreaterThan(period, Self.latencyMs * 0.9, "period \(period) ms is impossibly short")
  }

  /// The gate starts its consumer on the first frame, so a frame arriving after teardown must not
  /// bring recognition back to life.
  func testAFrameAfterDisposeDoesNotRecognize() async throws {
    let recognizer = TimedRecognizer(latencyMs: 1)
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(), recognizer: recognizer)
    _ = camera.onListen(withArguments: nil) { _ in XCTFail("a disposed session must not emit") }
    camera.start()

    try await camera.dispose()
    camera.handle(try makeTestPixelBuffer())
    try await Task.sleep(nanoseconds: 200 * NSEC_PER_MSEC)

    XCTAssertEqual(recognizer.stats().0, 0, "a frame after dispose reached the recognizer")
  }

  /// Reopening releases first, so recognition stops even when the rebuild then fails.
  func testAFailedReopenStopsTheRunningRecognition() async throws {
    try XCTSkipUnless(
      AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) == nil,
      "needs a host without a camera, which is what the simulator is"
    )
    let recognizer = TimedRecognizer(latencyMs: 1)
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(), recognizer: recognizer)
    _ = camera.onListen(withArguments: nil) { _ in XCTFail("a released session must not emit") }
    camera.start()

    // No camera here, so the rebuild fails, but only after the release has already happened.
    XCTAssertThrowsError(try camera.configureSession())
    camera.handle(try makeTestPixelBuffer())
    try await Task.sleep(nanoseconds: 200 * NSEC_PER_MSEC)

    XCTAssertEqual(recognizer.stats().0, 0, "a frame after reopening reached the recognizer")
  }
}
