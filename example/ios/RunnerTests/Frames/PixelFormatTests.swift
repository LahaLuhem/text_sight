import CoreVideo
import Testing

@testable import text_sight

@Suite("Capture pixel format")
struct PixelFormatTests {
  /// The empty row is an output with no camera connected yet.
  @Test("The format we ask for, given what the output offers", arguments: [
    (offered: [kCVPixelFormatType_32BGRA, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange],
     asked: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
    (offered: [kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
               kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
     asked: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
    (offered: [], asked: kCVPixelFormatType_32BGRA),
  ])
  func format(offered: [OSType], asked: OSType) {
    #expect(CaptureFormat.pixelFormat(from: offered) == asked)
  }
}
