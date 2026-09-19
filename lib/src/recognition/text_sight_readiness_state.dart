/// Whether the on-device recognition model is usable, reported by `TextSightModel`.
///
/// Always [ModelReady] on iOS, where Vision is a system framework. The other two are Android with
/// the default unbundled ML Kit model, which Play Services fetches.
sealed class const TextSightReadinessState() {
  /// Const base constructor.
  this;
}

/// The model is there, so recognition will give you results. Terminal.
final class const ModelReady() extends TextSightReadinessState {
  /// Creates it.
  this;

  @override
  String toString() => 'ModelReady()';
}

/// Play Services is fetching the ML Kit model. Android only, and recognition gives you nothing back
/// until [ModelReady] lands.
final class const ModelDownloading({
  /// `0` to `1`, or `null` until Play Services starts reporting byte counts.
  final double? progress,
}) extends TextSightReadinessState {
  /// Creates it.
  this;

  @override
  String toString() => 'ModelDownloading(progress: $progress)';
}

/// The model can't be made ready, so recognition will give you nothing. Terminal, and Android only.
///
/// Bundling the model (`useBundled`) sidesteps the whole state.
final class const ModelUnavailable({
  /// Why it couldn't.
  required final ModelUnavailableReason reason,

  /// The native diagnostic behind [reason], when there is one.
  final String? details,
}) extends TextSightReadinessState {
  /// Creates it.
  this;

  @override
  String toString() => 'ModelUnavailable(reason: $reason, details: $details)';
}

/// Why the model couldn't be made ready (see [ModelUnavailable]).
enum ModelUnavailableReason() {
  /// No usable Google Play Services, which the unbundled model needs to download. The `useBundled`
  /// build flag drops that dependency.
  playServicesUnavailable,

  /// Play Services is there but the download didn't finish, say no network or it got cancelled.
  downloadFailed,
}
