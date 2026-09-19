import '../platform/text_sight_platform.dart';
import '../recognition/text_sight_readiness_state.dart';

/// Loads and tracks the on-device recognition model.
///
/// Android's default ML Kit model comes from Play Services, and anything you recognize before it
/// lands comes back empty. So call [ensureReady] when the user opens an OCR screen and watch
/// [readiness]. iOS and Android's bundled model are always [ModelReady].
// Nothing to construct here, so a primary constructor would only add a public member.
// ignore: use_primary_constructors
abstract final class TextSightModel {
  /// Fetches the model if it isn't there yet. A failure comes back as [ModelUnavailable] rather
  /// than a throw. Cheap to call again once it's ready.
  static Future<TextSightReadinessState> ensureReady() =>
      TextSightPlatform.instance.ensureModelReady();

  /// Readiness as it changes, opening with the current state when that's known. Listening never
  /// kicks off a fetch, that's [ensureReady]'s job. Cancel your own subscription.
  static Stream<TextSightReadinessState> get readiness => TextSightPlatform.instance.modelReadiness;
}
