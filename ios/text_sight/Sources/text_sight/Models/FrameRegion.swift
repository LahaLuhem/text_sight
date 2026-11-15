import CoreGraphics

/// The part of a frame Vision reads, and the way back from the boxes it reports.
struct FrameRegion {
  /// The box the way Vision measures it, from the frame's bottom-left corner.
  let visionRect: CGRect

  init(_ roi: RegionOfInterestMessage?) {
    visionRect = roi.map {
      CGRect(x: $0.left, y: 1 - ($0.top + $0.height), width: $0.width, height: $0.height)
    } ?? CGRect(x: 0, y: 0, width: 1, height: 1)
  }

  /// A box Vision measured inside `visionRect`, on the whole frame and from its top-left corner.
  func toFrame(_ box: CGRect) -> CGRect {
    let width = box.width * visionRect.width
    let height = box.height * visionRect.height
    let left = visionRect.minX + box.minX * visionRect.width
    let bottom = visionRect.minY + box.minY * visionRect.height

    return CGRect(x: left, y: 1 - (bottom + height), width: width, height: height)
  }
}
