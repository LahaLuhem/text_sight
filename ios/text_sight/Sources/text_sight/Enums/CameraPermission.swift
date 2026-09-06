import AVFoundation

/// Turns iOS's camera-authorization state into the Pigeon enum, and runs the one prompt iOS allows.
///
/// Once the user decides, `requestAccess` just replays that decision and never asks again. So
/// `.denied` and `.restricted` (parental controls, MDM) both become `permanentlyDenied`, since only
/// Settings can undo them. `.notDetermined` becomes `denied`, because a request can still prompt.
enum CameraPermission {
  /// The current authorization, without prompting.
  static func current() -> CameraPermissionStatusMessage {
    map(AVCaptureDevice.authorizationStatus(for: .video))
  }

  /// Prompts when the authorization is still undetermined, then reports the resulting status.
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
