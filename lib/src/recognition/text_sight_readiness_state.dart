/// The readiness of the on-device recognition model, reported by `TextSightModel`.
///
/// Sealed so a consumer can `switch` over the three outcomes exhaustively and pull
/// each state's own data in the same step. On iOS the engine is the Vision *system
/// framework*, so the model is always present — readiness is only ever [ModelReady]
/// there. The other states arise on Android with the **unbundled** ML Kit model
/// (the default), which is fetched from Google Play Services and so can be
/// downloading, or unavailable when Play Services is missing or a fetch fails.
sealed class TextSightReadinessState {
  /// Const base constructor for the sealed hierarchy.
  const TextSightReadinessState();
}

/// The recognition model is present; recognition will produce results.
///
/// The terminal success state. Reached immediately on iOS, with the bundled ML Kit
/// model, or once the unbundled model has finished downloading.
final class ModelReady extends TextSightReadinessState {
  /// Creates the ready state.
  const ModelReady();

  @override
  String toString() => 'ModelReady()';
}

/// The unbundled ML Kit model is being fetched from Google Play Services.
///
/// A non-terminal Android-only state: it never appears on iOS, nor with the bundled
/// model. Recognition called now yields no results until [ModelReady] follows.
final class ModelDownloading extends TextSightReadinessState {
  /// Download progress in `[0, 1]`, or `null` while indeterminate — the fetch has
  /// begun but Play Services has not yet reported byte counts.
  final double? progress;

  /// Creates the downloading state, optionally carrying [progress].
  const ModelDownloading({this.progress});

  @override
  String toString() => 'ModelDownloading(progress: $progress)';
}

/// The model cannot be made ready, so recognition will not produce results.
///
/// A terminal failure state, Android-only in practice: the unbundled model needs
/// Google Play Services (absent on some devices), and a fetch can fail. [reason]
/// says which; [details] carries the native diagnostic when one is available. Never
/// occurs on iOS. Bundling the model (the `useBundled` build flag) sidesteps it.
final class ModelUnavailable extends TextSightReadinessState {
  /// Why the model could not be made ready.
  final ModelUnavailableReason reason;

  /// The native diagnostic message behind [reason], when one is available.
  final String? details;

  /// Creates the unavailable state with its [reason] and optional [details].
  const ModelUnavailable({required this.reason, this.details});

  @override
  String toString() => 'ModelUnavailable(reason: $reason, details: $details)';
}

/// Why the recognition model could not be made ready (see [ModelUnavailable]).
enum ModelUnavailableReason {
  /// The device has no usable Google Play Services, which the unbundled model
  /// needs in order to download. Bundling the model (the `useBundled` build flag)
  /// removes the dependency on Play Services.
  playServicesUnavailable,

  /// Play Services is present but the model download did not complete (e.g. no
  /// network, or it was cancelled).
  downloadFailed,
}
