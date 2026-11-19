import CoreGraphics

/// The lines last shown, so one on the box's edge can hold instead of blinking.
struct ShownLines {
  private var roi: RegionOfInterestMessage?
  private var boxes: [CGRect] = []

  mutating func keep(_ lines: [RecognizedLineData], in region: FrameRegion,
                     roi: RegionOfInterestMessage?) -> [RecognizedLineData] {
    // A changed box starts with nothing shown.
    let kept = region.keep(lines, shown: roi == self.roi ? boxes : [])
    self.roi = roi
    boxes = kept.map(\.box)

    return kept
  }
}
