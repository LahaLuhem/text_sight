/// Whether the on-device model is ready, as `TextSightModel` reports it.
///
/// Always [ModelReady] on iOS, where Vision ships with the system. The others only happen on
/// Android, with the default model that Play Services downloads.
sealed class const TextSightReadinessState() {
  /// Const base constructor for the sealed hierarchy.
  this;
}

/// The model is there, so reading works.
///
/// Straight away on iOS and with Android's bundled model, otherwise once the download finishes.
final class const ModelReady() extends TextSightReadinessState {
  /// Creates the ready state.
  this;

  @override
  String toString() => 'ModelReady()';
}

/// Play Services is downloading the ML Kit model. Android only.
///
/// Anything read now comes back empty until [ModelReady].
final class const ModelDownloading({
  /// Download progress in `[0, 1]`, or `null` until Play Services reports any.
  final double? progress,
}) extends TextSightReadinessState {
  /// Creates the downloading state.
  this;

  @override
  String toString() => 'ModelDownloading(progress: $progress)';
}

/// The model can't be made ready, so reading returns nothing.
///
/// Android only: the downloaded model needs Play Services, which some devices lack, and a download
/// can fail. Bundling the model (`useBundled`) avoids both.
final class const ModelUnavailable({
  /// Why the model could not be made ready.
  required final ModelUnavailableReason reason,

  /// The platform's own wording, for logs only.
  final String? details,
}) extends TextSightReadinessState {
  /// Creates the unavailable state.
  this;

  @override
  String toString() => 'ModelUnavailable(reason: $reason, details: $details)';
}

/// Why the model couldn't be made ready.
enum ModelUnavailableReason() {
  /// No usable Play Services on the device, which the download needs. Bundling the model (the
  /// `useBundled` build flag) avoids it.
  playServicesUnavailable,

  /// Play Services is there, but the download didn't finish (no network, or it was cancelled).
  downloadFailed,
}
