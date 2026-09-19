/// @docImport 'text_sight_options.dart';
library;

import 'dart:ui' show Locale;

import 'package:copy_with_extension/copy_with_extension.dart';

import 'recognition_level.dart';

part 'darwin_options.g.dart';

/// Settings only Apple Vision has. Android ignores the lot.
///
/// Grouped instead of prefixed one by one, so a new Vision knob is a field here rather than a
/// change to [TextSightOptions].
@CopyWith()
final class const DarwinOptions({
  /// Speed against accuracy. The one-shot raises it to [RecognitionLevel.accurate], with no frame
  /// budget to protect.
  final RecognitionLevel recognitionLevel = .fast,

  /// Whether the recognizer fixes likely misreads against a lexicon.
  ///
  /// Helps ordinary prose, wrecks serials and part numbers, which it cheerfully "corrects" into
  /// words.
  final bool usesLanguageCorrection = true,

  /// Most-preferred first. Repeats get dropped, empty means no preference. Goes to Vision as a
  /// BCP-47 tag (`en-US`, `zh-Hans`).
  final Iterable<Locale> preferredLanguages = const [
    .fromSubtags(languageCode: 'en', countryCode: 'US'),
  ],

  /// Smallest text to read, as a fraction of the frame height. Higher is faster and blind to small
  /// print, `0` keeps every pixel. Measured against the whole frame, so narrowing
  /// [TextSightOptions.roi] doesn't change what's readable.
  final double minimumTextHeight = 0,
}) {
  /// Defaults suit live capture.
  this;

  @override
  String toString() =>
      'DarwinOptions(recognitionLevel: $recognitionLevel, '
      'usesLanguageCorrection: $usesLanguageCorrection, '
      'preferredLanguages: $preferredLanguages, minimumTextHeight: $minimumTextHeight)';
}
