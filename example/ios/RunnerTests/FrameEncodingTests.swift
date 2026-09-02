import CoreGraphics
import XCTest

@testable import text_sight

/// `TextSightCamera.encodeFrame`: neutral recognized lines to the per-frame wire map, which has to
/// come out byte-identical to the one Android emits.
final class FrameEncodingTests: XCTestCase {
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
