import CoreVideo
import XCTest

@testable import text_sight

/// Backpressure and cancellation on the live frame path, driven through `handle` with a parked
/// recognizer so no camera is needed. The cancellation case is the interesting one: it times out if
/// teardown never reaches work already in flight, the shape `EngineScopeTest` covers on Android.
final class LiveFramePathTests: XCTestCase {
  func testDisposeCancelsTheRecognitionInFlight() async throws {
    let recognizer = ParkedRecognizer()
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(), recognizer: recognizer)
    _ = camera.onListen(withArguments: nil) { _ in XCTFail("a cancelled frame must not emit") }
    camera.start()

    camera.handle(try makeTestPixelBuffer())
    await fulfillment(of: [recognizer.started], timeout: 5)

    try await camera.dispose()

    await fulfillment(of: [recognizer.cancelled], timeout: 5)
  }

  func testAFrameIsDroppedWhileAnotherIsStillRunning() async throws {
    let recognizer = ParkedRecognizer()
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(), recognizer: recognizer)
    _ = camera.onListen(withArguments: nil) { _ in }
    camera.start()
    let pixelBuffer = try makeTestPixelBuffer()

    camera.handle(pixelBuffer)
    await fulfillment(of: [recognizer.started], timeout: 5)
    camera.handle(pixelBuffer)

    // Inverted, so this passes only while the second frame stays out of the recognizer.
    await fulfillment(of: [recognizer.startedAgain], timeout: 0.5)

    try await camera.dispose()
    await fulfillment(of: [recognizer.cancelled], timeout: 5)
  }
}
