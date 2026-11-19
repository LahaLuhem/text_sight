import XCTest

@testable import text_sight

/// Driven through the internal `detach()`, so no `FlutterPluginRegistrar` fake is needed. The
/// cancel test times out if detach never reaches the read already running.
final class EngineDetachTests: XCTestCase {
  func testDetachCancelsTheRecognitionInFlight() async throws {
    let recognizer = ParkedRecognizer()
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(), recognizer: recognizer)
    _ = camera.onListen(withArguments: nil) { _ in }
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
    // all is the check: a release has to be safe to repeat, even on a session that never opened.
    try await camera.dispose()
  }
}
