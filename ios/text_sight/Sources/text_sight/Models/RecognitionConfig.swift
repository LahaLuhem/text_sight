/// One snapshot of the recognizer settings, free of the Pigeon types so it can ride the
/// recognition `Task` as a single value.
struct RecognitionConfig {
  let level: RecognitionLevelMessage

  /// Fixes likely misreads against a lexicon. Good for prose, bad for serials.
  let usesLanguageCorrection: Bool
  let languages: [String]

  /// Smallest text to read, as a fraction of the scan box. Vision shrinks the image to suit, so 0
  /// keeps every pixel.
  let minimumTextHeight: Float
  let roi: RegionOfInterestMessage?
}
