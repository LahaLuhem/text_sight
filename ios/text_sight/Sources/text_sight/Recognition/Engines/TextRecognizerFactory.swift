/// Picks the backend by OS version, once, so the check stays off the per-frame path.
enum TextRecognizerFactory {
  static func make() -> any TextRecognizer {
    if #available(iOS 18, *) {
      return ModernTextRecognizer()
    } else {
      return LegacyTextRecognizer()
    }
  }
}
