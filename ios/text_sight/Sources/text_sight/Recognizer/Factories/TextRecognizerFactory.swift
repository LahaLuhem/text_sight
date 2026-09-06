/// Picks the backend once by OS: modern `RecognizeTextRequest` on iOS 18+, legacy
/// `VNRecognizeTextRequest` below that. The only version gate in the package, and resolving it at
/// init keeps it off the per-frame path.
enum TextRecognizerFactory {
  static func make() -> any TextRecognizer {
    if #available(iOS 18, *) {
      return ModernTextRecognizer()
    } else {
      return LegacyTextRecognizer()
    }
  }
}
