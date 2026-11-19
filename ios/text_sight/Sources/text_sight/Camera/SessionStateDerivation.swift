import AVFoundation

enum SessionStateDerivation {
  /// Backgrounding is the plugin's own pause. Anything else is the OS taking the camera.
  static func state(forInterruption reason: AVCaptureSession.InterruptionReason?)
    -> SessionPausedMessage {
    switch reason {
    case .videoDeviceNotAvailableInBackground: SessionPausedMessage(reason: .appBackgrounded)
    case let .some(other): SessionPausedMessage(reason: .interrupted, details: name(of: other))
    case .none: SessionPausedMessage(reason: .interrupted)
    }
  }

  static func state(forRuntimeError error: Error?) -> SessionFailedMessage {
    SessionFailedMessage(details: error?.localizedDescription)
  }

  /// Whether the session should be running: wanted, app in the foreground, and not parked by a
  /// runtime error.
  static func shouldRun(wantsSession: Bool, isForeground: Bool, hasFailed: Bool) -> Bool {
    wantsSession && isForeground && !hasFailed
  }

  /// The imported enum prints no case names, so spell them out for the logs.
  private static func name(of reason: AVCaptureSession.InterruptionReason) -> String {
    switch reason {
    case .videoDeviceNotAvailableInBackground: "videoDeviceNotAvailableInBackground"
    case .audioDeviceInUseByAnotherClient: "audioDeviceInUseByAnotherClient"
    case .videoDeviceInUseByAnotherClient: "videoDeviceInUseByAnotherClient"
    case .videoDeviceNotAvailableWithMultipleForegroundApps:
      "videoDeviceNotAvailableWithMultipleForegroundApps"
    case .videoDeviceNotAvailableDueToSystemPressure: "videoDeviceNotAvailableDueToSystemPressure"
    case .sensitiveContentMitigationActivated: "sensitiveContentMitigationActivated"
    @unknown default: "interruptionReason(\(reason.rawValue))"
    }
  }
}
