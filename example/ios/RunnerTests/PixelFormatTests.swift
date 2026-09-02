import CoreVideo
import Testing

@testable import text_sight

/// `TextSightCamera.pixelFormat`: which capture format we ask the camera for, given what it offers.
@Suite("Capture pixel format")
struct PixelFormatTests {
  /// The camera's own biplanar YUV wins where offered, video range first since that is what the
  /// sensor hands out, and BGRA is the fallback. The empty row is a not-yet-connected output.
  @Test("The format we ask for, given what the output offers", arguments: [
    (offered: [kCVPixelFormatType_32BGRA, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
     asked: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
    (offered: [kCVPixelFormatType_32BGRA, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange],
     asked: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
    (offered: [kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
               kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
     asked: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
    (offered: [kCVPixelFormatType_32BGRA], asked: kCVPixelFormatType_32BGRA),
    (offered: [], asked: kCVPixelFormatType_32BGRA),
  ])
  func format(offered: [OSType], asked: OSType) {
    #expect(TextSightCamera.pixelFormat(from: offered) == asked)
  }
}
