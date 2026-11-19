/// @docImport 'text_sight_options.dart';
library;

import 'dart:ui' show Locale;

import 'package:copy_with_extension/copy_with_extension.dart';

import 'recognition_level.dart';

part 'darwin_options.g.dart';

/// Settings only Apple Vision has. iOS uses them, Android ignores them.
@CopyWith()
final class const DarwinOptions({
  /// Speed against accuracy. The one-shot defaults to [RecognitionLevel.accurate], since it has no
  /// frame rate to keep up.
  final RecognitionLevel recognitionLevel = .fast,

  /// Whether the recognizer fixes likely misreads using a dictionary.
  ///
  /// Helps normal text, hurts serial and part numbers, which it happily "corrects" into words. It
  /// works at either [recognitionLevel], so turn it off when speed matters more.
  final bool usesLanguageCorrection = true,

  /// Languages to read, most-preferred first. Repeats are dropped, empty means no preference.
  ///
  /// Vision gets each as its language tag (`en-US`, `zh-Hans`).
  final Iterable<Locale> preferredLanguages = const [
    .fromSubtags(languageCode: 'en', countryCode: 'US'),
  ],

  /// Smallest text to read, as a fraction of the frame height, in `[0, 1]`.
  ///
  /// Higher is faster and blind to small print. `0` leaves the floor to Vision, which shrinks big
  /// frames before reading them anyway. Measured against the frame, so [TextSightOptions.roi]
  /// doesn't move it.
  final double minimumTextHeight = 0,
}) {
  /// Defaults suit live scanning.
  this;

  @override
  String toString() =>
      'DarwinOptions(recognitionLevel: $recognitionLevel, '
      'usesLanguageCorrection: $usesLanguageCorrection, '
      'preferredLanguages: $preferredLanguages, minimumTextHeight: $minimumTextHeight)';
}
