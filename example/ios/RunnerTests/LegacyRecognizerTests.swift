import CoreGraphics
import CoreImage
import CoreVideo
import ImageIO
import UIKit
import XCTest

@testable import text_sight

/// End-to-end recognition on the legacy Vision backend. Unlike the mapping tests, this really runs
/// `VNRecognizeTextRequest`: building `LegacyTextRecognizer` directly exercises the iOS 15-17 path on
/// any runtime, so perform / continuation / Y-flip stay covered without a sub-18 simulator.
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

  /// The format switch rests on Vision reading biplanar YUV, so pin that rather than claim it.
  func testReadsTextFromABiplanarYuvBuffer() async throws {
    let cgImage = try XCTUnwrap(Self.renderText("HELLO").cgImage)

    let lines = try await LegacyTextRecognizer().recognize(
      pixelBuffer: try Self.makeYuvBuffer(from: cgImage), orientation: .up,
      config: RecognitionConfig(level: .accurate, languages: [], roi: nil)
    )

    let joined = lines.map(\.text).joined().uppercased()
    XCTAssertTrue(joined.contains("HELLO"), "expected HELLO from a YUV buffer, got \"\(joined)\"")
  }

  /// Draws `cgImage` into a biplanar-YUV buffer, the format the live path now asks the camera for.
  private static func makeYuvBuffer(from cgImage: CGImage) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary]
    let code = CVPixelBufferCreate(kCFAllocatorDefault, cgImage.width, cgImage.height,
                                   kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                   attributes as CFDictionary, &buffer)
    XCTAssertEqual(code, kCVReturnSuccess)
    let pixelBuffer = try XCTUnwrap(buffer)
    CIContext().render(CIImage(cgImage: cgImage), to: pixelBuffer)

    return pixelBuffer
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
