/// Picks the recognizer backend once, by OS: the modern Swift `RecognizeTextRequest` on iOS 18+,
/// the legacy `VNRecognizeTextRequest` on iOS 13–17. This `#available` is the *only* version gate;
/// resolving it once (at `TextSightCamera` init) keeps it out of the per-frame path.
enum TextRecognizerFactory {
  static func make() -> any TextRecognizer {
    if #available(iOS 18, *) {
      return ModernTextRecognizer()
    } else {
      return LegacyTextRecognizer()
    }
  }
}
