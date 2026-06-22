import '../platform/text_sight_platform.dart';
import '../recognition/text_sight_readiness_state.dart';

/// Controls and observes readiness of the on-device recognition model.
///
/// Mode-agnostic: both the live `TextSightController` and the one-shot `TextSight`
/// recognize through the same model, so readiness belongs here, on neither driver.
/// It exists so model loading need never block app startup. On Android the default
/// (unbundled) ML Kit model is fetched from Google Play Services, and recognition
/// requests made before it arrives yield no results; call [ensureReady] when the
/// user enters an OCR feature to fetch it in the background, and watch [readiness]
/// to surface download progress or a failure.
///
/// On iOS this is effectively a no-op: Vision is a system framework, so the model
/// is always [ModelReady] and [ensureReady] resolves immediately. Same with the
/// bundled ML Kit model on Android (the `useBundled` build flag).
///
/// A pure namespace: every entry point is `static` and delegates to
/// [TextSightPlatform.instance], so it carries no platform knowledge and is never
/// instantiated.
abstract final class TextSightModel {
  /// Ensures the recognition model is present — fetching the unbundled ML Kit model
  /// when needed — and resolves to the terminal state: [ModelReady] on success, or
  /// [ModelUnavailable] if it cannot be fetched (failure is a state, not a throw).
  ///
  /// Safe to call repeatedly and to `await` without listening to [readiness]; it
  /// resolves immediately when the model is already available (always on iOS and
  /// with the bundled model). Watch [readiness] for intermediate [ModelDownloading]
  /// progress while this is in flight.
  static Future<TextSightReadinessState> ensureReady() =>
      TextSightPlatform.instance.ensureModelReady();

  /// The live model-readiness stream — [ModelReady] once available,
  /// [ModelDownloading] while the unbundled model fetches, [ModelUnavailable] on
  /// failure.
  ///
  /// Emits the current state on subscription when it is already known (e.g.
  /// [ModelReady] on iOS). Listening only *observes*; it never starts a fetch —
  /// that is [ensureReady]'s job. Subscribers must cancel their own subscription.
  static Stream<TextSightReadinessState> get readiness => TextSightPlatform.instance.modelReadiness;
}
