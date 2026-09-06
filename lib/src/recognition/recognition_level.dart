/// How hard the recognizer works per frame, trading speed for accuracy.
///
/// Live capture defaults to [fast] so the preview keeps up. The one-shot uses [accurate], which has
/// no frame budget to protect. Apple Vision only: the ML Kit Latin recognizer has no accuracy dial,
/// so on Android both values read the same.
enum RecognitionLevel {
  /// Quicker, reads less.
  fast,

  /// Reads more, takes longer.
  accurate,
}
