import XCTest

@testable import text_sight

/// Engine detach, the iOS counterpart to Android's `EngineScopeTest`. Driven through the internal
/// `detach()` seam, so no `FlutterPluginRegistrar` fake is needed. Like the dispose case, the
/// cancellation test times out if the hook never reaches work that is already running.
final class EngineDetachTests: XCTestCase {
  func testDetachCancelsTheRecognitionInFlight() async throws {
    let recognizer = ParkedRecognizer()
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(), recognizer: recognizer)
    _ = camera.onListen(withArguments: nil) { _ in XCTFail("a cancelled frame must not emit") }
    camera.start()

    camera.handle(try makeTestPixelBuffer())
    await fulfillment(of: [recognizer.started], timeout: 5)

    camera.detach()

    await fulfillment(of: [recognizer.cancelled], timeout: 5)
  }

  func testDetachIsSafeOnASessionThatNeverOpened() async throws {
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry())

    camera.detach()
    camera.detach()

    // `dispose` rides the same session queue, so awaiting it drains both teardowns. Resolving at
    // all is the assertion: release is idempotent and must not trap on an unopened session.
    try await camera.dispose()
  }
}
