import 'dart:ui' show Locale, Rect;

import 'recognition_level.dart';

/// What the recognizer needs, shared by the live driver and the one-shot.
///
/// One config type rather than a per-driver duplicate. Session-only things like the torch live on
/// the controller instead, since a still image has no such concept.
final class TextSightOptions {
  /// The accuracy/latency trade-off. Defaults to [RecognitionLevel.fast]. The one-shot overrides it
  /// to [RecognitionLevel.accurate], having no per-frame budget to protect.
  final RecognitionLevel level;

  /// Whether the recognizer fixes likely misreads against a lexicon.
  ///
  /// Helps ordinary prose, hurts serials and part numbers, which it happily "corrects" into words.
  /// Independent of [level], so turn it off explicitly when latency matters more. Apple Vision only,
  /// the ML Kit Latin recognizer has no equivalent.
  final bool usesLanguageCorrection;

  /// Preferred recognition languages, most-preferred first.
  ///
  /// A [Locale] rather than a raw tag keeps this type-pure while staying open to whatever a
  /// platform/OS version supports at runtime. Each is sent to the native recognizer as its
  /// BCP-47 tag via [Locale.toLanguageTag] (e.g. `en-US`, `zh-Hans`). Apple Vision reads the list
  /// as a preference order. The ML Kit Latin recognizer ignores it (non-Latin scripts need their
  /// own native recognizer and dependency).
  final Iterable<Locale> languages;

  /// The scan-box recognition is restricted to: a normalized `[0, 1]`, top-left
  /// `Rect`, or `null` for the whole frame.
  final Rect? roi;

  /// Creates recognizer options. Every field has a live-oriented default.
  const new({
    this.level = .fast,
    this.usesLanguageCorrection = true,
    this.languages = const [Locale.fromSubtags(languageCode: 'en', countryCode: 'US')],
    this.roi,
  });

  @override
  String toString() =>
      'TextSightOptions(level: $level, usesLanguageCorrection: $usesLanguageCorrection, '
      'languages: $languages, roi: $roi)';
}
