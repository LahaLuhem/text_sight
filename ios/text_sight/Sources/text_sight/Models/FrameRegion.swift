import CoreGraphics

/// The part of a frame Vision reads, the way back from the boxes it reports, and which lines count.
struct FrameRegion {
  /// What Vision reads, from the frame's bottom-left corner: the box plus half its height above and
  /// below, so a line up to the box's height that its edge crosses isn't cut into fragments.
  let visionRect: CGRect

  /// The box from the frame's top-left corner, or nil for the whole frame.
  private let box: CGRect?

  init(_ roi: RegionOfInterestMessage?) {
    guard let roi else {
      visionRect = CGRect(x: 0, y: 0, width: 1, height: 1)
      box = nil

      return
    }

    let box = CGRect(x: roi.left, y: roi.top, width: roi.width, height: roi.height)
    let top = max(0, box.minY - box.height / 2)
    let bottom = min(1, box.maxY + box.height / 2)

    visionRect = CGRect(x: box.minX, y: 1 - bottom, width: box.width, height: bottom - top)
    self.box = box
  }

  /// A box Vision measured inside `visionRect`, on the whole frame and from its top-left corner.
  func toFrame(_ box: CGRect) -> CGRect {
    let width = box.width * visionRect.width
    let height = box.height * visionRect.height
    let left = visionRect.minX + box.minX * visionRect.width
    let bottom = visionRect.minY + box.minY * visionRect.height

    return CGRect(x: left, y: 1 - (bottom + height), width: width, height: height)
  }

  /// The lines whose centre is in the box, each kept whole.
  func keep(_ lines: [RecognizedLineData]) -> [RecognizedLineData] {
    guard let box else { return lines }

    return lines.filter { box.contains(CGPoint(x: $0.box.midX, y: $0.box.midY)) }
  }
}
