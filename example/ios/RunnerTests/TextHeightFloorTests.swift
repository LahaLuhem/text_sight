import CoreGraphics
import Testing
import UIKit

@testable import text_sight

/// Fails the moment anything stops pinning the recognizers' text-height floor to zero. The legacy
/// backend defaults to zero anyway, so that half is a guard rather than a proof.
@Suite("Small text recognition")
struct TextHeightFloorTests {
  static let lineCount = 8

  @available(iOS 18, *)
  @Test("Modern: reads type below Vision's default floor")
  func modernReadsSmallText() async throws {
    try await check(recognizer: ModernTextRecognizer())
  }

  @Test("Legacy: reads type below Vision's default floor")
  func legacyReadsSmallText() async throws {
    try await check(recognizer: LegacyTextRecognizer())
  }

  private func check(recognizer: some TextRecognizer) async throws {
    let page = try Self.renderPage()
    let lines = try await recognizer.recognize(
      cgImage: page, orientation: .up,
      config: RecognitionConfig(level: .fast, languages: [], roi: nil)
    )

    #expect(lines.count == Self.lineCount)
    #expect(lines.map(\.text).joined().uppercased().contains("QUICK"))
  }

  /// A live-frame-sized page, with type too small for Vision's default floor.
  private static func renderPage() throws -> CGImage {
    let size = CGSize(width: 1080, height: 1920)
    let format = UIGraphicsImageRendererFormat.default()
    // Otherwise the renderer picks up the screen scale and the page changes size.
    format.scale = 1

    let page = UIGraphicsImageRenderer(size: size, format: format).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: size))

      for index in 0..<lineCount {
        let line = "LINE \(index + 1) THE QUICK BROWN FOX" as NSString
        line.draw(at: CGPoint(x: 40, y: CGFloat(index + 1) * 200), withAttributes: [
          .font: UIFont.boldSystemFont(ofSize: 40),
          .foregroundColor: UIColor.black,
        ])
      }
    }

    return try #require(page.cgImage)
  }
}
