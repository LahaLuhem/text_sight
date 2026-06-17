/// How aggressively text is recognized, trading latency for accuracy.
///
/// The two drivers default differently on purpose: live capture uses [fast] so
/// per-frame latency stays low and the preview keeps up, while one-shot still
/// recognition uses [accurate], where there is no frame budget to protect.
enum RecognitionLevel {
  /// Lowest latency, lower accuracy — the default for the live camera driver.
  fast(usesLanguageCorrection: false),

  /// Highest accuracy at the cost of latency — the default for one-shot stills.
  accurate(usesLanguageCorrection: true);

  /// Whether the native recognizer applies language correction at this level.
  ///
  /// Carried on the value so the choice lives where it is described and every
  /// call site reads the same `level.usesLanguageCorrection`; the native side
  /// maps it (Apple Vision's `usesLanguageCorrection`). Disabling it trims
  /// latency, which is why [fast] leaves it off.
  final bool usesLanguageCorrection;

  const RecognitionLevel({required this.usesLanguageCorrection});
}
