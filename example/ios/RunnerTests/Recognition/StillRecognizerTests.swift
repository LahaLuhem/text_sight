import Flutter
import UIKit
import XCTest

@testable import text_sight

/// The one-shot driver resolves or throws its typed error, never hangs.
final class StillRecognizerTests: XCTestCase {
  private let options = TextSightOptionsMessage(level: .accurate, usesLanguageCorrection: true,
                                                languages: [], minimumTextHeight: 0, roi: nil)

  func testRecognizeImageResolvesForRenderedText() async throws {
    let png = try XCTUnwrap(renderText("HELLO").pngData())

    let frame = try await makeStills().recognizeImage(
      bytes: FlutterStandardTypedData(bytes: png), options: options
    )

    let lines = try XCTUnwrap(frame["lines"] as? [[String: Any?]])
    let joined = lines.compactMap { $0["text"] as? String }.joined().uppercased()
    XCTAssertTrue(joined.contains("HELLO"), "expected HELLO, got \"\(joined)\"")
  }

  func testRecognizeImageThrowsOnUndecodableBytes() async {
    let garbage = FlutterStandardTypedData(bytes: Data([0x00, 0x01, 0x02, 0x03]))

    await assertThrowsPigeonError(code: "decode-failed") {
      _ = try await self.makeStills().recognizeImage(bytes: garbage, options: self.options)
    }
  }

  func testRecognizePathThrowsWhenTheFileIsMissing() async {
    await assertThrowsPigeonError(code: "file-not-found") {
      _ = try await self.makeStills().recognizePath(path: "/no/such/file.png",
                                                        options: self.options)
    }
  }

  private func makeStills() -> StillRecognizer {
    StillRecognizer(recognizer: TextRecognizerFactory.make())
  }
}
