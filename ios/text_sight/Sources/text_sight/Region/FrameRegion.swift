import CoreGraphics

struct FrameRegion {
  let visionRect: CGRect
  private let box: CGRect?

  init(_ roi: RegionOfInterestMessage?) {
    guard let roi else {
      visionRect = CGRect(x: 0, y: 0, width: 1, height: 1)
      box = nil

      return
    }

    let box = CGRect(x: roi.left, y: roi.top, width: roi.width, height: roi.height)
    // Read half the box's height past its top and bottom. Vision turns a line cut along its length
    // into fragments, and this way any line the edge crosses gets read whole.
    let top = max(0, box.minY - box.height / 2)
    let bottom = min(1, box.maxY + box.height / 2)

    // Vision wants it from the bottom-left corner.
    visionRect = CGRect(x: box.minX, y: 1 - bottom, width: box.width, height: bottom - top)
    self.box = box
  }

  func toFrame(_ box: CGRect) -> CGRect {
    // Vision measures from the region's corner, not the frame's.
    let width = box.width * visionRect.width
    let height = box.height * visionRect.height
    let left = visionRect.minX + box.minX * visionRect.width
    let bottom = visionRect.minY + box.minY * visionRect.height

    return CGRect(x: left, y: 1 - (bottom + height), width: width, height: height)
  }

  func keep(_ lines: [RecognizedLineData], shown: [CGRect] = []) -> [RecognizedLineData] {
    guard let box else { return lines }

    return lines.filter { line in
      // The read reaches past the box, so a line counts when its centre is inside.
      if box.contains(CGPoint(x: line.box.midX, y: line.box.midY)) { return true }

      // One already on screen hangs on a bit past the edge, so a shaky hand doesn't blink it.
      let outside = max(box.minY - line.box.midY, line.box.midY - box.maxY)

      return outside <= line.box.height / 4 && shown.contains { Self.isSameLine($0, line.box) }
    }
  }

  private static func isSameLine(_ one: CGRect, _ other: CGRect) -> Bool {
    // Loose enough that a line the hand nudged between frames still matches.
    one.intersection(other).height > min(one.height, other.height) / 2
  }
}
