import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:text_sight/text_sight.dart';

/// The engine's confidence scale, asked once and shared.
///
/// It depends on which recognizer the OS hands over, so it cannot change while the app runs, which
/// is why one fetch is enough. Anything that ranks, thresholds or tints by confidence reads this
/// first: Vision on iOS 18+ reports a coarse scale that parks every line on the same number, and
/// colouring tiers from that would imply a precision the engine does not have.
abstract final class EngineConfidence {
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
