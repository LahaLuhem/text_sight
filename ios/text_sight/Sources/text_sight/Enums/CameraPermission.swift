import AVFoundation

/// Maps the system camera-authorization state to the Pigeon transport enum and drives the one-shot
/// permission prompt. System frameworks only (AVFoundation), per the no-bundling contract.
///
/// iOS surfaces the prompt exactly once: after the user decides, `requestAccess` resolves immediately
/// with the stored decision and never prompts again. So a refusal (`.denied`) and the
/// non-user-controllable `.restricted` (parental controls / MDM) both map to `permanentlyDenied`:
/// only Settings can change them. `.notDetermined` maps to `.denied` (not granted, but a request can
/// still surface the dialog).
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
