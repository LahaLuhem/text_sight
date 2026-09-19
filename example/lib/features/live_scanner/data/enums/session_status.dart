/// Lifecycle of the live camera session, as one switchable state for the view.
enum SessionStatus() {
  /// Fetching the model, which happens before the camera is touched. A no-op on iOS and with the
  /// bundled ML Kit model.
  preparingModel,

  /// Asking for camera permission.
  requesting,

  /// Refused, but a retry can still ask.
  denied,

  /// Refused for good, so it's the settings app now.
  permanentlyDenied,

  /// Scanning.
  ready,

  /// The controller reported a pause.
  paused,

  /// The controller reported a failure after scanning had started.
  failed,
}
