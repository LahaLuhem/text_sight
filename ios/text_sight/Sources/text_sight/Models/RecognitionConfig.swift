/// A recognizer-config snapshot, decoupled from the Pigeon wire types so a single value carries it
/// across the recognition `Task`. Mirrors the live-tunable knobs (`updateX` on the controller) and
/// the one-shot's per-call options.
struct RecognitionConfig {
  let level: RecognitionLevelMessage
  let languages: [String]
  let roi: RegionOfInterestMessage?
}
