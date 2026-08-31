import AVFoundation
import CoreGraphics
import Flutter
import Foundation
import ImageIO
import UIKit
import Vision
import XCTest

@testable import text_sight

/// Host-side (simulator) unit tests for the pure orientation- and request-mapping helpers in
/// `TextSightCamera`, reached via `@testable import`. No capture session or recognizer runs, only
/// the platform-independent logic behind the rotation contract and the Vision request config.
final class TextSightCameraTests: XCTestCase {
  // MARK: displayRotation, capture angle -> (quarterTurns, Vision orientation, axes-swap)

  func testDisplayRotationMapsEachQuarterTurn() {
    let up = TextSightCamera.displayRotation(forCaptureAngle: 0)
    XCTAssertEqual(up.quarterTurns, 0)
    XCTAssertEqual(up.orientation, .up)
    XCTAssertFalse(up.isQuarterTurned)

    let right = TextSightCamera.displayRotation(forCaptureAngle: 90)
    XCTAssertEqual(right.quarterTurns, 1)
    XCTAssertEqual(right.orientation, .right)
    XCTAssertTrue(right.isQuarterTurned)

    let down = TextSightCamera.displayRotation(forCaptureAngle: 180)
    XCTAssertEqual(down.quarterTurns, 2)
    XCTAssertEqual(down.orientation, .down)
    XCTAssertFalse(down.isQuarterTurned)

    let left = TextSightCamera.displayRotation(forCaptureAngle: 270)
    XCTAssertEqual(left.quarterTurns, 3)
    XCTAssertEqual(left.orientation, .left)
    XCTAssertTrue(left.isQuarterTurned)
  }

  func testDisplayRotationNormalizesOutOfRangeAngles() {
    // 360 wraps to 0, 450 wraps to 90, and a near-quarter angle rounds before the modulo.
    XCTAssertEqual(TextSightCamera.displayRotation(forCaptureAngle: 360).quarterTurns, 0)
    XCTAssertEqual(TextSightCamera.displayRotation(forCaptureAngle: 450).quarterTurns, 1)
    XCTAssertEqual(TextSightCamera.displayRotation(forCaptureAngle: 89.6).quarterTurns, 1)
  }

  // MARK: ModernTextRecognizer.makeRequest, config snapshot -> Vision RecognizeTextRequest
  // (iOS 18+ only: `ModernTextRecognizer` is `@available(iOS 18, *)`, skipped on older runtimes).

  @available(iOS 18, *)
  func testMakeRequestFastLevelDisablesLanguageCorrection() {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: [], roi: nil)
    )

    XCTAssertEqual(request.recognitionLevel, .fast)
    XCTAssertFalse(request.usesLanguageCorrection)
  }

  @available(iOS 18, *)
  func testMakeRequestAccurateLevelEnablesLanguageCorrection() {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .accurate, languages: [], roi: nil)
    )

    XCTAssertEqual(request.recognitionLevel, .accurate)
    XCTAssertTrue(request.usesLanguageCorrection)
  }

  @available(iOS 18, *)
  func testMakeRequestMapsLanguagesInPreferenceOrder() {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: ["en-US", "fr"], roi: nil)
    )

    XCTAssertEqual(
      request.recognitionLanguages,
      [Locale.Language(identifier: "en-US"), Locale.Language(identifier: "fr")]
    )
  }

  @available(iOS 18, *)
  func testMakeRequestFlipsRegionOfInterestToLowerLeft() {
    let roi = RegionOfInterestMessage(left: 0.1, top: 0.2, width: 0.3, height: 0.4)

    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: [], roi: roi)
    )

    // Vision's region-of-interest is lower-left normalized: y = 1 - (top + height).
    let region = request.regionOfInterest
    XCTAssertEqual(region.origin.x, 0.1, accuracy: 1e-9)
    XCTAssertEqual(region.origin.y, 0.4, accuracy: 1e-9)
    XCTAssertEqual(region.width, 0.3, accuracy: 1e-9)
    XCTAssertEqual(region.height, 0.4, accuracy: 1e-9)
  }

  // MARK: LegacyTextRecognizer.makeRequest, config snapshot -> Vision VNRecognizeTextRequest

  func testLegacyMakeRequestFastLevelDisablesLanguageCorrection() {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: [], roi: nil)
    )

    XCTAssertEqual(request.recognitionLevel, .fast)
    XCTAssertFalse(request.usesLanguageCorrection)
  }

  func testLegacyMakeRequestAccurateLevelEnablesLanguageCorrection() {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .accurate, languages: [], roi: nil)
    )

    XCTAssertEqual(request.recognitionLevel, .accurate)
    XCTAssertTrue(request.usesLanguageCorrection)
  }

  func testLegacyMakeRequestPassesLanguagesThroughInOrder() {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: ["en-US", "fr"], roi: nil)
    )

    XCTAssertEqual(request.recognitionLanguages, ["en-US", "fr"])
  }

  func testLegacyMakeRequestFlipsRegionOfInterestToLowerLeft() {
    let roi = RegionOfInterestMessage(left: 0.1, top: 0.2, width: 0.3, height: 0.4)

    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, languages: [], roi: roi)
    )

    // Vision's region-of-interest is lower-left normalized: y = 1 - (top + height).
    let region = request.regionOfInterest
    XCTAssertEqual(region.origin.x, 0.1, accuracy: 1e-9)
    XCTAssertEqual(region.origin.y, 0.4, accuracy: 1e-9)
    XCTAssertEqual(region.width, 0.3, accuracy: 1e-9)
    XCTAssertEqual(region.height, 0.4, accuracy: 1e-9)
  }

  // MARK: encodeFrame, neutral lines -> the cross-platform per-frame wire map

  func testEncodeFrameMapsLinesToWireKeys() {
    let line = RecognizedLineData(text: "hi", confidence: 0.5,
                                  box: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4))

    let frame = TextSightCamera.encodeFrame([line], imageWidth: 100, imageHeight: 200,
                                            quarterTurns: 1)

    XCTAssertEqual(frame["imageWidth"] as? Double, 100)
    XCTAssertEqual(frame["imageHeight"] as? Double, 200)
    XCTAssertEqual(frame["quarterTurns"] as? Int, 1)

    let encodedLines = frame["lines"] as? [[String: Any]]
    XCTAssertEqual(encodedLines?.count, 1)

    let encoded = encodedLines?.first
    XCTAssertEqual(encoded?["text"] as? String, "hi")
    XCTAssertEqual(encoded?["confidence"] as? Double, 0.5)
    XCTAssertEqual(encoded?["left"] as? Double, 0.1)
    XCTAssertEqual(encoded?["top"] as? Double, 0.2)
    XCTAssertEqual(encoded?["width"] as? Double, 0.3)
    XCTAssertEqual(encoded?["height"] as? Double, 0.4)
    XCTAssertTrue(encoded?["elements"] is NSNull)
  }
}

/// End-to-end recognition for the legacy Vision backend. Unlike `TextSightCameraTests` (pure
/// mapping logic), this actually runs `VNRecognizeTextRequest`: instantiating `LegacyTextRecognizer`
/// directly exercises the iOS 13-17 path on *any* runtime, so the legacy perform / continuation /
/// Y-flip stays covered in CI without a sub-18 simulator.
final class LegacyTextRecognizerTests: XCTestCase {
  func testReadsRenderedText() async throws {
    let cgImage = try XCTUnwrap(Self.renderText("HELLO").cgImage)

    let lines = try await LegacyTextRecognizer().recognize(
      cgImage: cgImage, orientation: .up,
      config: RecognitionConfig(level: .accurate, languages: [], roi: nil)
    )

    XCTAssertFalse(lines.isEmpty, "legacy recognizer returned no lines")
    let joined = lines.map(\.text).joined().uppercased()
    XCTAssertTrue(joined.contains("HELLO"), "expected HELLO, got \"\(joined)\"")

    let line = try XCTUnwrap(lines.first)
    // Vision always supplies a confidence, and the legacy request grades it (often < 1.0). Assert
    // only the invariant range: the exact value is Vision-version-dependent and would be brittle.
    XCTAssertGreaterThanOrEqual(line.confidence, 0)
    XCTAssertLessThanOrEqual(line.confidence, 1)
    // The neutral box is top-left-normalized, so it stays inside the unit square.
    XCTAssertGreaterThanOrEqual(line.box.minX, 0)
    XCTAssertLessThanOrEqual(line.box.maxX, 1)
    XCTAssertGreaterThanOrEqual(line.box.minY, 0)
    XCTAssertLessThanOrEqual(line.box.maxY, 1)
  }

  /// Renders `string` as large black text on a white field, clear enough for reliable recognition.
  static func renderText(_ string: String) -> UIImage {
    let size = CGSize(width: 512, height: 160)

    return UIGraphicsImageRenderer(size: size).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: size))
      (string as NSString).draw(at: CGPoint(x: 24, y: 36), withAttributes: [
        .font: UIFont.boldSystemFont(ofSize: 84),
        .foregroundColor: UIColor.black,
      ])
    }
  }
}

/// The async control surface on `TextSightCamera` and `TextSightModelReadiness`, reached via
/// `@testable import`. Covers both outcomes of the continuation bridge: it resolves, and it throws
/// instead of hanging. A hung continuation is the failure mode the async conversion introduces, and
/// XCTest's own timeout is what catches it.
final class AsyncControlSurfaceTests: XCTestCase {
  private let options = TextSightOptionsMessage(level: .accurate, languages: [], roi: nil)

  func testRecognizeImageResolvesForRenderedText() async throws {
    let png = try XCTUnwrap(LegacyTextRecognizerTests.renderText("HELLO").pngData())

    let frame = try await makeCamera().recognizeImage(
      bytes: FlutterStandardTypedData(bytes: png), options: options
    )

    let lines = try XCTUnwrap(frame["lines"] as? [[String: Any?]])
    let joined = lines.compactMap { $0["text"] as? String }.joined().uppercased()
    XCTAssertTrue(joined.contains("HELLO"), "expected HELLO, got \"\(joined)\"")
  }

  func testRecognizeImageThrowsOnUndecodableBytes() async {
    // Lands on the frame-decode guard, not the source guard: CGImageSourceCreateWithData returns a
    // source for any Data, empty included.
    let garbage = FlutterStandardTypedData(bytes: Data([0x00, 0x01, 0x02, 0x03]))

    await assertThrowsPigeonError(code: "decode-failed",
                                  message: "The image could not be decoded.") {
      try await self.makeCamera().recognizeImage(bytes: garbage, options: self.options)
    }
  }

  func testRecognizePathThrowsWhenTheFileIsMissing() async {
    await assertThrowsPigeonError(code: "file-not-found") {
      try await self.makeCamera().recognizePath(path: "/no/such/file.png", options: self.options)
    }
  }

  func testInitializeThrowsWithoutCameraPermission() async throws {
    // Authorization is ambient in the test host and has flipped between runs, so only assert when
    // the guard can actually fire.
    try XCTSkipIf(AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
                  "camera is authorized in this host")

    await assertThrowsPigeonError(code: "permission-denied") {
      _ = try await self.makeCamera().initialize(options: self.options)
    }
  }

  func testEnsureModelReadyResolvesToReady() async {
    let state = await TextSightModelReadiness().ensureModelReady()

    XCTAssertEqual(state["state"] as? String, "ready")
  }

  func testDisposeResolvesOnAnUnopenedSession() async throws {
    // Exercises the sessionQueue bridge on its own: release is idempotent, so this must resolve
    // rather than hang waiting for a session that never opened.
    try await makeCamera().dispose()
  }

  private func makeCamera() -> TextSightCamera {
    TextSightCamera(textureRegistry: StubTextureRegistry())
  }

  private func assertThrowsPigeonError(
    code: String, message: String? = nil, file: StaticString = #filePath, line: UInt = #line,
    _ work: @escaping () async throws -> Void
  ) async {
    do {
      try await work()
      XCTFail("expected a PigeonError(\(code)), got success", file: file, line: line)
    } catch let error as PigeonError {
      XCTAssertEqual(error.code, code, file: file, line: line)
      if let message {
        XCTAssertEqual(error.message, message, file: file, line: line)
      }
    } catch {
      XCTFail("expected a PigeonError(\(code)), got \(error)", file: file, line: line)
    }
  }
}

/// Satisfies `TextSightCamera`'s texture dependency for the one-shot and dispose paths, which never
/// register a texture.
private final class StubTextureRegistry: NSObject, FlutterTextureRegistry {
  func register(_ texture: FlutterTexture) -> Int64 { 1 }

  func textureFrameAvailable(_ textureId: Int64) {}

  func unregisterTexture(_ textureId: Int64) {}
}
