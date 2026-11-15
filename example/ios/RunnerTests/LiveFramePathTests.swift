import CoreVideo
import XCTest

@testable import text_sight

/// Backpressure and cancellation on the live frame path, driven through `handle` with stand-in
/// recognizers so no camera is needed. The cancellation case times out if teardown never reaches
/// work already in flight, the shape `EngineScopeTest` covers on Android.
final class LiveFramePathTests: XCTestCase {
  func testDisposeCancelsTheRecognitionInFlight() async throws {
    let recognizer = ParkedRecognizer()
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(), recognizer: recognizer)
    _ = camera.onListen(withArguments: nil) { _ in }
    camera.start()

    camera.handle(try makeTestPixelBuffer())
    await fulfillment(of: [recognizer.started], timeout: 5)

    try await camera.dispose()

    await fulfillment(of: [recognizer.cancelled], timeout: 5)
  }

  /// The legacy backend's Vision call runs to the end even when cancelled, so cancelling alone
  /// doesn't stop a frame. The check after it has to.
  func testAFrameCancelledMidRecognitionNeverEmits() async throws {
    let recognizer = FinishesAnywayRecognizer()
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(), recognizer: recognizer)
    _ = camera.onListen(withArguments: nil) { _ in XCTFail("a cancelled frame emitted") }
    camera.start()

    camera.handle(try makeTestPixelBuffer())
    await fulfillment(of: [recognizer.started], timeout: 5)
    let consumer = try XCTUnwrap(camera.gate.consumerTask)

    try await camera.dispose()
    await consumer.value
    // An emit hops to main, so let main run whatever is already queued.
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
    }
  }

  func testAFrameWithNoCapturesListenerNeverReachesTheRecognizer() async throws {
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(),
                                 recognizer: ParkedRecognizer())
    camera.start()

    camera.handle(try makeTestPixelBuffer())

    // `handle` decides on the spot, so an idle gate now means the frame never runs.
    XCTAssertNil(camera.gate.consumerTask, "a frame with nobody listening reached the gate")
    try await camera.dispose()
  }

  func testOnlyTheNewestWaitingFrameRunsNext() async throws {
    let recognizer = HeldRecognizer()
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(), recognizer: recognizer)
    _ = camera.onListen(withArguments: nil) { _ in }
    camera.start()
    let (first, stale, newest) =
      (try makeTestPixelBuffer(), try makeTestPixelBuffer(), try makeTestPixelBuffer())
    var reached = recognizer.frames.makeAsyncIterator()

    camera.handle(first)
    let running = await reached.next()
    // Both arrive while the first is running, so only the newest should be left waiting.
    camera.handle(stale)
    camera.handle(newest)
    recognizer.release()
    let next = await reached.next()
    recognizer.release()

    XCTAssertTrue(running === first)
    XCTAssertTrue(next === newest, "a stale frame ran instead of the newest")
    try await camera.dispose()
  }
}
