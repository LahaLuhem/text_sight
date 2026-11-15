import CoreGraphics
import CoreImage
import CoreVideo
import Testing
import UIKit

@testable import text_sight

/// The live path asks the camera for biplanar YUV, so pin that Vision reads it on both backends
/// rather than claim it.
@Suite("Reading the camera's YUV")
struct YuvBufferTests {
  @available(iOS 18, *)
  @Test("Modern: reads text from a biplanar YUV buffer")
  func modern() async throws {
    try await check(ModernTextRecognizer())
  }

  @Test("Legacy: reads text from a biplanar YUV buffer")
  func legacy() async throws {
    try await check(LegacyTextRecognizer())
  }

  private func check(_ recognizer: some TextRecognizer) async throws {
    let cgImage = try #require(renderText("HELLO").cgImage)

    let lines = try await recognizer.recognize(
      pixelBuffer: try Self.makeYuvBuffer(from: cgImage), orientation: .up,
      config: RecognitionConfig(level: .accurate, usesLanguageCorrection: true,
                                languages: [], minimumTextHeight: 0, roi: nil)
    )

    let joined = lines.map(\.text).joined().uppercased()
    #expect(joined.contains("HELLO"), "expected HELLO from a YUV buffer, got \"\(joined)\"")
  }

  /// Draws `cgImage` into a biplanar-YUV buffer, the format the live path asks the camera for.
  private static func makeYuvBuffer(from cgImage: CGImage) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary]
    let code = CVPixelBufferCreate(kCFAllocatorDefault, cgImage.width, cgImage.height,
                                   kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                   attributes as CFDictionary, &buffer)
    try #require(code == kCVReturnSuccess)
    let pixelBuffer = try #require(buffer)
    CIContext().render(CIImage(cgImage: cgImage), to: pixelBuffer)

    return pixelBuffer
  }
}
