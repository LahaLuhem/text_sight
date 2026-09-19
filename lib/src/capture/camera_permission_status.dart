/// Whether the live session is allowed to open the camera.
enum CameraPermissionStatus() {
  /// Good to go.
  granted,

  /// Asking again can still bring up the prompt. Android only, since iOS prompts once and then
  /// reports [permanentlyDenied].
  denied,

  /// Only the settings app can change this now. Covers an iOS refusal, and also a restriction the
  /// user doesn't get a say in, like parental controls or an MDM profile.
  permanentlyDenied,
}
