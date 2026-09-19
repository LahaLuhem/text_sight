import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:text_sight/text_sight.dart';

/// The engine's confidence scale, asked once and shared.
///
/// Fixed for the run, since the OS picks the recognizer once. Anything that ranks or tints by
/// confidence reads this first, because Vision on iOS 18+ parks every line on the same number and
/// tiering off that would imply precision it hasn't got.
abstract final class EngineConfidence() {
  static final _scaleNotifier = ValueNotifier<ConfidenceScale?>(null);

  /// `null` until [resolve] lands, and after a failure. Treat that as "do not rank".
  static ValueListenable<ConfidenceScale?> get scaleListenable => _scaleNotifier;

  static Future<void> resolve() async {
    try {
      _scaleNotifier.value = await TextSightEngine.confidenceScale;
    } on Object {
      // Staying null keeps consumers on plain values, which is the safe reading anyway.
    }
  }
}
