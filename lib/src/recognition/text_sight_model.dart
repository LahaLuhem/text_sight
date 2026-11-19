import '../platform/text_sight_platform.dart';
import '../states/text_sight_readiness_state.dart';

/// Whether the on-device model is ready to read.
///
/// Android's default model downloads through Play Services, and anything read before it lands comes
/// back empty. So call [ensureReady] when the user opens a scanning screen, and watch [readiness].
/// iOS, and Android's bundled model, are always [ModelReady].
abstract final class TextSightModel {
  /// Fetches the model if it's missing. Resolves to [ModelReady], or to [ModelUnavailable] when it
  /// can't be fetched, never a throw.
  ///
  /// Safe to call again, and returns at once when the model's there.
  static Future<TextSightReadinessState> ensureReady() =>
      TextSightPlatform.instance.ensureModelReady();

  /// The model's state as it changes, starting with the current one when it's known.
  ///
  /// Listening never starts a download, [ensureReady] does. Cancel your own subscription.
  static Stream<TextSightReadinessState> get readiness => TextSightPlatform.instance.modelReadiness;
}
