/// @docImport 'text_sight_options.dart';
library;

import 'dart:ui' show Locale;

import 'package:copy_with_extension/copy_with_extension.dart';

import 'recognition_level.dart';

part 'darwin_options.g.dart';

/// Recognizer settings that only Apple Vision has, so iOS and macOS honour them and Android does
/// nothing with them.
///
/// Grouped rather than prefixed one by one, so a new Vision knob is a field here instead of a
/// change to [TextSightOptions]. `copyWith` is generated, so adding one cannot leave the copy
/// behind.
@CopyWith()
final class const DarwinOptions({
  /// The accuracy/latency trade-off. The one-shot raises it to [RecognitionLevel.accurate], having
  /// no per-frame budget to protect.
  final RecognitionLevel recognitionLevel = .fast,

  /// Whether the recognizer fixes likely misreads against a lexicon.
  ///
  /// Helps ordinary prose, hurts serials and part numbers, which it happily "corrects" into words.
  /// Independent of [recognitionLevel], so turn it off when latency matters more.
  final bool usesLanguageCorrection = true,

  /// Recognition languages, most-preferred first. Repeats are dropped, empty means no preference.
  ///
  /// A [Locale] rather than a raw tag, passed to Vision as its BCP-47 tag (`en-US`, `zh-Hans`).
  final Iterable<Locale> preferredLanguages = const [
    .fromSubtags(languageCode: 'en', countryCode: 'US'),
  ],

  /// Smallest text to read, as a fraction of the frame height, in `[0, 1]`.
  ///
  /// Higher is faster and blind to small print, `0` keeps every pixel. Always measured against the
  /// frame, so narrowing [TextSightOptions.roi] never changes what is readable.
  final double minimumTextHeight = 0,
}) {
  /// Creates Vision-only options. Every field has a live-oriented default.
  this;

  @override
  String toString() =>
      'DarwinOptions(recognitionLevel: $recognitionLevel, '
      'usesLanguageCorrection: $usesLanguageCorrection, '
      'preferredLanguages: $preferredLanguages, minimumTextHeight: $minimumTextHeight)';
}
