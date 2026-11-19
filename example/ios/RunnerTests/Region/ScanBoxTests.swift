import CoreGraphics
import Testing
import UIKit

@testable import text_sight

/// With a scan box set, Vision measures each line from the corner of the region it reads.
@Suite("Line boxes with a scan box set")
struct ScanBoxTests {
  // Off-centre and smaller than the frame both ways, even with the read reaching past the box, so a
  // box measured from the wrong corner or left unscaled lands off its word.
  static let roi = RegionOfInterestMessage(left: 0.15, top: 0.3, width: 0.5, height: 0.3)

  // Inside the box, and apart in both directions, so a box that's off either way shows.
  static let words = [("ALPHA", CGPoint(x: 200, y: 800)), ("BRAVO", CGPoint(x: 400, y: 1040))]

  // The README's strip, whose top edge (768 px) cuts this line about a third of the way down.
  static let strip = RegionOfInterestMessage(left: 0.1, top: 0.4, width: 0.8, height: 0.2)
  static let slicedLine = [("CHARLIE DELTA ECHO", CGPoint(x: 160, y: 738))]

  static let pageSize = CGSize(width: 1080, height: 1920)

  // Vision boxes the glyphs a little looser than they're drawn.
  static let slack = CGSize(width: 16 / pageSize.width, height: 16 / pageSize.height)

  static var attributes: [NSAttributedString.Key: Any] {
    [.font: UIFont.boldSystemFont(ofSize: 64), .foregroundColor: UIColor.black]
  }

  @available(iOS 18, *)
  @Test("Modern: each box lands on its line")
  func modern() async throws {
    try await check(ModernTextRecognizer(), roi: Self.roi, words: Self.words)
  }

  @Test("Legacy: each box lands on its line")
  func legacy() async throws {
    try await check(LegacyTextRecognizer(), roi: Self.roi, words: Self.words)
  }

  @available(iOS 18, *)
  @Test("Modern: a line the box's edge cuts reads whole when its centre is inside")
  func modernSlicedLine() async throws {
    try await check(ModernTextRecognizer(), roi: Self.strip, words: Self.slicedLine)
  }

  @Test("Legacy: a line the box's edge cuts reads whole when its centre is inside")
  func legacySlicedLine() async throws {
    try await check(LegacyTextRecognizer(), roi: Self.strip, words: Self.slicedLine)
  }

  private func check(_ recognizer: some TextRecognizer, roi: RegionOfInterestMessage,
                     words: [(String, CGPoint)]) async throws {
    let lines = try await recognizer.recognize(
      cgImage: try Self.renderPage(words), orientation: .up,
      config: RecognitionConfig(level: .accurate, usesLanguageCorrection: true,
                                languages: [], minimumTextHeight: 0, roi: roi)
    )

    for (word, origin) in words {
      let line = try #require(lines.first { $0.text.uppercased().contains(word) },
                              "\(word) unread in \(lines.map(\.text))")
      let drawn = Self.normalizedRect(of: word, at: origin)
        .insetBy(dx: -Self.slack.width, dy: -Self.slack.height)

      #expect(drawn.contains(line.box), "\(word) reported at \(line.box), drawn at \(drawn)")
    }
  }

  private static func renderPage(_ words: [(String, CGPoint)]) throws -> CGImage {
    let format = UIGraphicsImageRendererFormat.default()
    // Otherwise the renderer picks up the screen scale and the page changes size.
    format.scale = 1

    let page = UIGraphicsImageRenderer(size: pageSize, format: format).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: pageSize))

      for (word, origin) in words {
        (word as NSString).draw(at: origin, withAttributes: attributes)
      }
    }

    return try #require(page.cgImage)
  }

  /// Where `word` sits on the page, top-left normalized like the boxes the recognizers report.
  private static func normalizedRect(of word: String, at origin: CGPoint) -> CGRect {
    let size = (word as NSString).size(withAttributes: attributes)

    return CGRect(x: origin.x / pageSize.width, y: origin.y / pageSize.height,
                  width: size.width / pageSize.width, height: size.height / pageSize.height)
  }
}
