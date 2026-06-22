/// The camera-permission state for the live recognition session.
///
/// A unified, cross-platform contract returned when checking or requesting
/// camera access. The platforms reach a refusal differently — iOS shows the
/// system prompt only once (a refusal is immediately settings-only), while
/// Android separates a refusal that can be re-prompted from a "don't ask again"
/// — so the actionable split is [denied] (asking again may surface the prompt)
/// versus [permanentlyDenied] (only the OS settings can change it).
enum CameraPermissionStatus {
  /// Camera access is granted; the session can open the camera.
  granted,

  /// Not granted, but requesting again may still surface the system prompt.
  /// Android-only in practice — iOS never re-prompts, so an iOS refusal is
  /// reported as [permanentlyDenied].
  denied,

  /// Not granted and no prompt will appear again — the user must enable the
  /// camera in system settings. Also covers iOS restrictions (parental controls
  /// or an MDM profile), where the choice is not the user's to make.
  permanentlyDenied,
}
