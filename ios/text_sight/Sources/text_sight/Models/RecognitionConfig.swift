/// One snapshot of the recognizer settings, free of the Pigeon types so it can ride the
/// recognition `Task` as a single value.
struct RecognitionConfig {
  let level: RecognitionLevelMessage

  /// Fixes likely misreads against a lexicon. Good for prose, bad for serials.
  let usesLanguageCorrection: Bool
  let languages: [String]

  /// Smallest text to read, as a fraction of the **frame**. Vision shrinks the image to suit, so 0
  /// keeps every pixel.
  let minimumTextHeight: Float
  let roi: RegionOfInterestMessage?

  /// The same floor in the units Vision wants, which are a fraction of the scan box rather than the
  /// frame. Without this a narrower box would quietly start reading smaller text.
  var visionTextHeightFraction: Float {
    let boxHeight = Float(roi?.height ?? 1)
    guard boxHeight > 0 else { return minimumTextHeight }

    return min(minimumTextHeight / boxHeight, 1)
  }
}
