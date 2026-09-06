/// @docImport 'text_sight_options.dart';
library;

import 'dart:ui' show Locale;

import 'recognition_level.dart';

/// Recognizer settings that only Apple Vision has, so iOS and macOS honour them and Android does
/// nothing with them.
///
/// Grouped rather than prefixed one by one, so the platform is stated once and a new Vision knob is
/// a field here instead of a change to [TextSightOptions]. ML Kit's Latin recognizer exposes none of
/// these, and its own knobs (picking a script bundle) will land in a sibling group.
final class DarwinOptions {
  /// The accuracy/latency trade-off. The one-shot raises it to [RecognitionLevel.accurate], having
  /// no per-frame budget to protect.
  final RecognitionLevel recognitionLevel;

  /// Whether the recognizer fixes likely misreads against a lexicon.
  ///
  /// Helps ordinary prose, hurts serials and part numbers, which it happily "corrects" into words.
  /// Independent of [recognitionLevel], so turn it off when latency matters more.
  final bool usesLanguageCorrection;

  /// Recognition languages, most-preferred first. Repeats are dropped.
  ///
  /// A [Locale] rather than a raw tag keeps this type-pure while staying open to whatever the OS
  /// supports at runtime. Each goes to Vision as its BCP-47 tag (`en-US`, `zh-Hans`). Empty means
  /// no preference.
  final Iterable<Locale> preferredLanguages;

  /// Smallest text to read, as a fraction of the frame height, in `[0, 1]`.
  ///
  /// Vision shrinks the image to suit before reading, so a higher floor is faster and blind to
  /// small print. `0`, the default, keeps every pixel. Measured against the *frame* even when
  /// [TextSightOptions.roi] narrows the scan box, so moving the box never changes what is readable.
  final double minimumTextHeight;

  /// Creates Vision-only options. Every field has a live-oriented default.
  const new({
    this.recognitionLevel = .fast,
    this.usesLanguageCorrection = true,
    this.preferredLanguages = const [.fromSubtags(languageCode: 'en', countryCode: 'US')],
    this.minimumTextHeight = 0,
  });

  /// A copy with the named fields replaced. Omitted fields keep their current value.
  DarwinOptions copyWith({
    RecognitionLevel? recognitionLevel,
    bool? usesLanguageCorrection,
    Iterable<Locale>? preferredLanguages,
    double? minimumTextHeight,
  }) => DarwinOptions(
    recognitionLevel: recognitionLevel ?? this.recognitionLevel,
    usesLanguageCorrection: usesLanguageCorrection ?? this.usesLanguageCorrection,
    preferredLanguages: preferredLanguages ?? this.preferredLanguages,
    minimumTextHeight: minimumTextHeight ?? this.minimumTextHeight,
  );

  @override
  String toString() =>
      'DarwinOptions(recognitionLevel: $recognitionLevel, '
      'usesLanguageCorrection: $usesLanguageCorrection, '
      'preferredLanguages: $preferredLanguages, minimumTextHeight: $minimumTextHeight)';
}
