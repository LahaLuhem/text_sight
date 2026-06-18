import 'dart:ui' show Locale, Rect;

import 'recognition_level.dart';

/// The source-agnostic recognizer configuration shared by both drivers.
///
/// One config type, not a per-driver duplicate: the live `TextSightController` takes it,
/// and (when it lands) the static one-shot accepts it per call. It holds only what the *recognizer*
/// needs: recognition [level], the candidate [languages], and an optional [roi].
/// Session-only concerns such as the torch deliberately live on the controller, not here:
/// a still image has no such concept, so folding it in would be a category error.
final class TextSightOptions {
  /// The accuracy/latency trade-off. Defaults to [RecognitionLevel.fast]; the static one-shot driver
  /// overrides it to [RecognitionLevel.accurate], where there is no per-frame latency budget to protect.
  final RecognitionLevel level;

  /// Preferred recognition languages, most-preferred first.
  ///
  /// A [Locale] rather than a raw tag keeps this type-pure while staying open to whatever a
  /// platform/OS version supports at runtime; each is sent to the native recognizer as its
  /// BCP-47 tag via [Locale.toLanguageTag] (e.g. `en-US`, `zh-Hans`). Apple Vision reads the list
  /// as a preference order. The ML Kit Latin recognizer ignores it (non-Latin scripts need their
  /// own native recognizer and dependency).
  final Iterable<Locale> languages;

  /// The scan-box recognition is restricted to — a normalized `[0, 1]`, top-left
  /// `Rect` — or `null` for the whole frame.
  final Rect? roi;

  /// Creates recognizer options; every field has a live-oriented default.
  const TextSightOptions({
    this.level = .fast,
    this.languages = const [Locale.fromSubtags(languageCode: 'en', countryCode: 'US')],
    this.roi,
  });

  @override
  String toString() => 'TextSightOptions(level: $level, languages: $languages, roi: $roi)';
}
