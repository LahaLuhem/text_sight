/// One snapshot of the recognizer settings, so they ride the recognition `Task` as a single value.
struct RecognitionConfig {
  let level: RecognitionLevelMessage

  /// Fixes likely misreads against a lexicon. Good for prose, bad for serials.
  let usesLanguageCorrection: Bool
  let languages: [String]

  /// Smallest text to read, as a fraction of the **frame** height.
  let minimumTextHeight: Float
  let roi: RegionOfInterestMessage?

  var region: FrameRegion { FrameRegion(roi) }

  /// The same floor in the units Vision wants, which are a fraction of the region it reads rather
  /// than the frame. Without this a narrower box would quietly start reading smaller text.
  var visionTextHeightFraction: Float {
    let readHeight = Float(region.visionRect.height)
    guard readHeight > 0 else { return minimumTextHeight }

    return min(minimumTextHeight / readHeight, 1)
  }
}
