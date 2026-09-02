import CoreVideo
import XCTest

@testable import text_sight

/// `TextSightCamera.pixelFormat`: which capture format we ask the camera for, given what it offers.
final class PixelFormatTests: XCTestCase {
  func testPixelFormatPrefersBiplanarYuvOverBgra() {
    let format = TextSightCamera.pixelFormat(from: [
      kCVPixelFormatType_32BGRA,
      kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
    ])

    XCTAssertEqual(format, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
  }

  func testPixelFormatTakesFullRangeWhenVideoRangeIsAbsent() {
    let format = TextSightCamera.pixelFormat(from: [
      kCVPixelFormatType_32BGRA,
      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
    ])

    XCTAssertEqual(format, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
  }

  func testPixelFormatFallsBackToBgra() {
    // Covers an empty list too, which is what a not-yet-connected output reports.
    XCTAssertEqual(TextSightCamera.pixelFormat(from: []), kCVPixelFormatType_32BGRA)
    XCTAssertEqual(TextSightCamera.pixelFormat(from: [kCVPixelFormatType_32BGRA]),
                   kCVPixelFormatType_32BGRA)
  }
}
