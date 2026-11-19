import AVFoundation

/// iOS asks once. After that `requestAccess` only replays the answer, so `.denied` and
/// `.restricted` (parental controls, a managed device) are `permanentlyDenied`, since only Settings
/// can undo them. `.notDetermined` is `denied`, because asking can still prompt.
enum CameraPermission {
  /// The current authorization, without prompting.
  static func current() -> CameraPermissionStatusMessage {
    map(AVCaptureDevice.authorizationStatus(for: .video))
  }

  /// Prompts if the user hasn't decided yet, then reports the answer.
  static func request() async -> CameraPermissionStatusMessage {
    guard AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined else {
      return current()
    }

    return await AVCaptureDevice.requestAccess(for: .video) ? .granted : .permanentlyDenied
  }

  private static func map(_ status: AVAuthorizationStatus) -> CameraPermissionStatusMessage {
    switch status {
    case .authorized: .granted
    case .denied, .restricted: .permanentlyDenied
    case .notDetermined: .denied
    @unknown default: .denied
    }
  }
}
