/// The readiness of the on-device recognition model, reported by `TextSightModel`.
///
/// Sealed, so a consumer can `switch` the three outcomes exhaustively and read each state's data
/// in the same step. Only ever [ModelReady] on iOS, where Vision is a system framework. The others
/// are Android with the default unbundled ML Kit model, which Play Services fetches.
sealed class const TextSightReadinessState() {
  /// Const base constructor for the sealed hierarchy.
  this;
}

/// The recognition model is present, so recognition will produce results.
///
/// The terminal success state. Reached immediately on iOS, with the bundled ML Kit
/// model, or once the unbundled model has finished downloading.
final class const ModelReady() extends TextSightReadinessState {
  /// Creates the ready state.
  this;

  @override
  String toString() => 'ModelReady()';
}

/// The unbundled ML Kit model is being fetched from Google Play Services.
///
/// A non-terminal Android-only state: it never appears on iOS, nor with the bundled
/// model. Recognition called now yields no results until [ModelReady] follows.
final class const ModelDownloading({
  /// Download progress in `[0, 1]`, or `null` while indeterminate, since the fetch has
  /// begun but Play Services has not yet reported byte counts.
  final double? progress,
}) extends TextSightReadinessState {
  /// Creates the downloading state, optionally carrying [progress].
  this;

  @override
  String toString() => 'ModelDownloading(progress: $progress)';
}

/// The model cannot be made ready, so recognition will not produce results.
///
/// Terminal, and Android-only: the unbundled model needs Google Play Services, which some devices
/// lack, and a fetch can fail. [reason] says which, [details] carries the native diagnostic.
/// Bundling the model (`useBundled`) sidesteps it.
final class const ModelUnavailable({
  /// Why the model could not be made ready.
  required final ModelUnavailableReason reason,

  /// The native diagnostic message behind [reason], when one is available.
  final String? details,
}) extends TextSightReadinessState {
  /// Creates the unavailable state with its [reason] and optional [details].
  this;

  @override
  String toString() => 'ModelUnavailable(reason: $reason, details: $details)';
}

/// Why the recognition model could not be made ready (see [ModelUnavailable]).
enum ModelUnavailableReason() {
  /// The device has no usable Google Play Services, which the unbundled model
  /// needs in order to download. Bundling the model (the `useBundled` build flag)
  /// removes the dependency on Play Services.
  playServicesUnavailable,

  /// Play Services is present but the model download did not complete (e.g. no
  /// network, or it was cancelled).
  downloadFailed,
}
