import AVFoundation
import Flutter
import UIKit
import XCTest

@testable import text_sight

/// The async control surface on `TextSightCamera`: each call resolves or throws its typed error. A
/// call that hangs instead is what the async conversion risks, and XCTest's timeout catches it.
final class ControlSurfaceTests: XCTestCase {
  private let options = TextSightOptionsMessage(level: .accurate, usesLanguageCorrection: true,
                                                languages: [], minimumTextHeight: 0, roi: nil)

  func testRecognizeImageResolvesForRenderedText() async throws {
    let png = try XCTUnwrap(renderText("HELLO").pngData())

    let frame = try await makeCamera().recognizeImage(
      bytes: FlutterStandardTypedData(bytes: png), options: options
    )

    let lines = try XCTUnwrap(frame["lines"] as? [[String: Any?]])
    let joined = lines.compactMap { $0["text"] as? String }.joined().uppercased()
    XCTAssertTrue(joined.contains("HELLO"), "expected HELLO, got \"\(joined)\"")
  }

  func testRecognizeImageThrowsOnUndecodableBytes() async {
    let garbage = FlutterStandardTypedData(bytes: Data([0x00, 0x01, 0x02, 0x03]))

    await assertThrowsPigeonError(code: "decode-failed") {
      _ = try await self.makeCamera().recognizeImage(bytes: garbage, options: self.options)
    }
  }

  func testRecognizePathThrowsWhenTheFileIsMissing() async {
    await assertThrowsPigeonError(code: "file-not-found") {
      _ = try await self.makeCamera().recognizePath(path: "/no/such/file.png",
                                                        options: self.options)
    }
  }

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

  private func assertThrowsPigeonError(
    code: String, file: StaticString = #filePath, line: UInt = #line,
    _ work: @escaping () async throws -> Void
  ) async {
    do {
      try await work()
      XCTFail("expected a PigeonError(\(code)), got success", file: file, line: line)
    } catch let error as PigeonError {
      XCTAssertEqual(error.code, code, file: file, line: line)
    } catch {
      XCTFail("expected a PigeonError(\(code)), got \(error)", file: file, line: line)
    }
  }
}
