import '../platform/text_sight_platform.dart';
import '../recognition/text_sight_readiness_state.dart';

/// Controls and observes readiness of the on-device recognition model.
///
/// Mode-agnostic, so loading never blocks app startup. On Android the default unbundled ML Kit
/// model is fetched from Play Services and requests made before it lands yield no results, so call
/// [ensureReady] as the user enters an OCR feature and watch [readiness]. Always [ModelReady] on
/// iOS and with Android's bundled model.
// Nothing to construct here, so a primary constructor would only add a public member.
// ignore: use_primary_constructors
abstract final class TextSightModel {
  /// Ensures the model is present, resolving to [ModelReady] or to [ModelUnavailable] if it
  /// cannot be fetched (failure is a state, not a throw).
  ///
  /// Safe to call repeatedly, and returns at once when the model is already there. Watch
  /// [readiness] for [ModelDownloading] progress meanwhile.
  static Future<TextSightReadinessState> ensureReady() =>
      TextSightPlatform.instance.ensureModelReady();

  /// The live readiness stream: [ModelReady], [ModelDownloading] while the unbundled model
  /// fetches, [ModelUnavailable] on failure.
  ///
  /// Emits the current state on subscription when it is known. Observing never starts a fetch,
  /// that is [ensureReady]'s job. Cancel your own subscription.
  static Stream<TextSightReadinessState> get readiness => TextSightPlatform.instance.modelReadiness;
}
