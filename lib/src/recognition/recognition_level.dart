/// How hard the recognizer works per frame, trading speed for accuracy.
///
/// Live capture defaults to [fast] so the preview keeps up, the one-shot to [accurate]. Apple
/// Vision only: ML Kit's Latin recognizer has no accuracy dial, so on Android both mean the same.
enum RecognitionLevel() {
  /// Quicker, reads less.
  fast,

  /// Reads more, takes longer.
  accurate,
}
