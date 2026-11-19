/// Whether the app may use the camera.
enum CameraPermissionStatus() {
  /// The camera can open.
  granted,

  /// Not yet, but asking again can still show the prompt. Android only, until the user picks
  /// "don't ask again". iOS asks once, so a refusal there is [permanentlyDenied].
  denied,

  /// Only the system settings can change it now. Also covers iOS restrictions (parental controls or
  /// a managed device), where it isn't the user's call.
  permanentlyDenied,
}
