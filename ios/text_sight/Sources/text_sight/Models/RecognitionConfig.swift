/// A recognizer-config snapshot, decoupled from the Pigeon wire types so a single value carries it
/// across the recognition `Task`. Mirrors the live-tunable knobs (`updateX` on the controller) and
/// the one-shot's per-call options.
struct RecognitionConfig {
  /// 0 stops Vision downscaling, so we read the smallest text the pixels allow.
  static let minimumTextHeight: Float = 0

  let level: RecognitionLevelMessage
  let languages: [String]
  let roi: RegionOfInterestMessage?
}
