/// The camera-permission state for the live recognition session.
///
/// [denied] means asking again may still surface the prompt, which Android allows until the user
/// picks "don't ask again". [permanentlyDenied] means only OS settings can change it, where iOS
/// lands immediately since it prompts once.
enum CameraPermissionStatus() {
  /// Camera access is granted, so the session can open the camera.
  granted,

  /// Not granted, but requesting again may still surface the system prompt.
  /// Android-only in practice: iOS never re-prompts, so an iOS refusal is
  /// reported as [permanentlyDenied].
  denied,

  /// Not granted and no prompt will appear again, so the user must enable the
  /// camera in system settings. Also covers iOS restrictions (parental controls
  /// or an MDM profile), where the choice is not the user's to make.
  permanentlyDenied,
}
