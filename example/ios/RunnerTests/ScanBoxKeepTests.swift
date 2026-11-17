import CoreGraphics
import Flutter
import Testing
import UIKit

@testable import text_sight

/// Vision reads past the scan box, so the camera passes on only the lines centred in it.
@Suite("Lines a scan box keeps")
struct ScanBoxKeepTests {
  static let options = TextSightOptionsMessage(
    level: .fast, usesLanguageCorrection: true, languages: [], minimumTextHeight: 0,
    roi: RegionOfInterestMessage(left: 0.1, top: 0.4, width: 0.8, height: 0.2)
  )

  // On the frame, top-left, as Vision's lines come back from the read past the box's top edge.
  static let lines = [
    line("INSIDE", top: 0.45),
    line("CUT, CENTRE INSIDE", top: 0.385),
    line("CUT, CENTRE OUTSIDE", top: 0.37),
    line("ABOVE THE BOX", top: 0.32),
  ]

  static let kept: Set = ["INSIDE", "CUT, CENTRE INSIDE"]

  @Test("Live: only lines centred in the box come back")
  func live() async throws {
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(),
                                 recognizer: FixedLinesRecognizer(lines: Self.lines))
    camera.setOptions(options: Self.options)
    let (frames, sink) = AsyncStream<[String: Any]>.makeStream()
    _ = camera.onListen(withArguments: nil) { ($0 as? [String: Any]).map { sink.yield($0) } }
    camera.start()

    camera.handle(try makeTestPixelBuffer())
    var reached = frames.makeAsyncIterator()
    let frame = try #require(await reached.next())

    #expect(Self.texts(in: frame) == Self.kept)
    try await camera.dispose()
  }

  @Test("One-shot: only lines centred in the box come back")
  func oneShot() async throws {
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(),
                                 recognizer: FixedLinesRecognizer(lines: Self.lines))
    let png = try #require(renderText("ANY").pngData())

    let frame = try await camera.recognizeImage(bytes: FlutterStandardTypedData(bytes: png),
                                                options: Self.options)

    #expect(Self.texts(in: frame.compactMapValues { $0 }) == Self.kept)
  }

  private static func line(_ text: String, top: Double) -> RecognizedLineData {
    RecognizedLineData(text: text, confidence: 1,
                       box: CGRect(x: 0.2, y: top, width: 0.5, height: 0.04))
  }

  private static func texts(in frame: [String: Any]) -> Set<String> {
    let lines = frame["lines"] as? [[String: Any]] ?? []

    return Set(lines.compactMap { $0["text"] as? String })
  }
}
