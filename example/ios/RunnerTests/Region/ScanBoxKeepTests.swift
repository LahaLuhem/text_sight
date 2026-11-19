import CoreGraphics
import Flutter
import Testing
import UIKit

@testable import text_sight

@Suite("Lines a scan box keeps")
struct ScanBoxKeepTests {
  static let box = RegionOfInterestMessage(left: 0.1, top: 0.4, width: 0.8, height: 0.2)

  // Already on the frame, the way the camera gets them back from Vision.
  static let lines = [
    line("INSIDE", top: 0.45),
    line("CUT, CENTRE INSIDE", top: 0.385),
    line("CUT, CENTRE OUTSIDE", top: 0.37),
    line("ABOVE THE BOX", top: 0.32),
  ]

  static let kept: Set = ["INSIDE", "CUT, CENTRE INSIDE"]

  @Test("Live: only lines centred in the box come back")
  func live() async throws {
    #expect(try await Self.live([(Self.box, Self.lines)]) == [Self.kept])
  }

  @Test("One-shot: only lines centred in the box come back")
  func oneShot() async throws {
    let stills = StillRecognizer(recognizer: ScriptedRecognizer(frames: [Self.lines]))
    let png = try #require(renderText("ANY").pngData())

    let frame = try await stills.recognizeImage(bytes: FlutterStandardTypedData(bytes: png),
                                                options: Self.options(Self.box))

    #expect(Self.texts(in: frame.compactMapValues { $0 }) == Self.kept)
  }

  // Its centre starts just inside the top edge, then the hand lifts it just past.
  @Test("Live: a line shown on the box's edge stays as the hand moves it just past")
  func edgeLineStays() async throws {
    let frames = try await Self.live([
      (Self.box, [Self.line("EDGE", top: 0.385)]),
      (Self.box, [Self.line("EDGE", top: 0.375)]),
    ])

    #expect(frames == [["EDGE"], ["EDGE"]])
  }

  // The line stays put while the box moves down, leaving its centre just above the new top edge.
  @Test("Live: a changed box starts with nothing shown")
  func changedBoxStartsAfresh() async throws {
    let lowered = RegionOfInterestMessage(left: 0.1, top: 0.41, width: 0.8, height: 0.2)
    let edge = [Self.line("EDGE", top: 0.385)]

    #expect(try await Self.live([(Self.box, edge), (lowered, edge)]) == [["EDGE"], []])
  }

  @Test("A line no frame showed doesn't come in past the edge")
  func unshownLineStaysOut() {
    let elsewhere = Self.line("ELSEWHERE", top: 0.5).box

    let kept = FrameRegion(Self.box).keep([Self.line("EDGE", top: 0.375)], shown: [elsewhere])

    #expect(kept.isEmpty)
  }

  @Test("A shown line goes once its centre is over a quarter of its height past the edge")
  func shownLineLeaves() {
    let shown = Self.line("EDGE", top: 0.375).box

    let kept = FrameRegion(Self.box).keep([Self.line("EDGE", top: 0.365)], shown: [shown])

    #expect(kept.isEmpty)
  }

  private static func live(
    _ steps: [(box: RegionOfInterestMessage, lines: [RecognizedLineData])]
  ) async throws -> [Set<String>] {
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(),
                                 recognizer: ScriptedRecognizer(frames: steps.map(\.lines)))
    let (frames, sink) = AsyncStream<[String: Any]>.makeStream()
    _ = camera.onListen(withArguments: nil) { ($0 as? [String: Any]).map { sink.yield($0) } }
    camera.start()
    var reached = frames.makeAsyncIterator()

    var passed: [Set<String>] = []
    for step in steps {
      camera.setOptions(options: options(step.box))
      camera.handle(try makeTestPixelBuffer())
      passed.append(texts(in: try #require(await reached.next())))
    }
    try await camera.dispose()

    return passed
  }

  private static func options(_ box: RegionOfInterestMessage) -> TextSightOptionsMessage {
    TextSightOptionsMessage(level: .fast, usesLanguageCorrection: true, languages: [],
                            minimumTextHeight: 0, roi: box)
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
