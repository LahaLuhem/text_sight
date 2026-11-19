import AVFoundation
import XCTest

@testable import text_sight

/// Each control call resolves or throws its typed error. XCTest's timeout catches one that hangs.
final class ControlSurfaceTests: XCTestCase {
  private let options = TextSightOptionsMessage(level: .accurate, usesLanguageCorrection: true,
                                                languages: [], minimumTextHeight: 0, roi: nil)

  func testInitializeThrowsWithoutCameraPermission() async throws {
    // Authorization is ambient in the test host and has flipped between runs, so only assert when
    // the guard can actually fire.
    try XCTSkipIf(AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
                  "camera is authorized in this host")

    await assertThrowsPigeonError(code: "permission-denied") {
      _ = try await self.makeCamera().initialize(options: self.options, resolution: .medium)
    }
  }

  func testAFailedGraphBuildLeavesNoConfigurationOpen() throws {
    try XCTSkipUnless(
      AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) == nil,
      "needs a host without a camera, which is what the simulator is"
    )
    let session = CountingCaptureSession()
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(), makeSession: { session })

    XCTAssertThrowsError(try camera.buildCaptureGraph())

    // An open configuration reads as clean (inputs and outputs still look right) until
    // start/stopRunning raises and takes the app down, so count the pairs instead.
    XCTAssertEqual(session.openConfigurations, 0, "a failed build left the session wedged")
  }

  private func makeCamera() -> TextSightCamera {
    TextSightCamera(textureRegistry: StubTextureRegistry())
  }
}
