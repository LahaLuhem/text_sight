import AVFoundation
import Testing

@testable import text_sight

/// What each capture-session notification turns into, and the emit path's silence when there is
/// nothing to report.
@Suite("Session state mapping")
struct SessionStateMappingTests {
  @Test("Losing the camera to the background is the plugin's own pause")
  func backgroundInterruption() {
    let state = TextSightCamera.state(forInterruption: .videoDeviceNotAvailableInBackground)

    #expect(state.reason == .appBackgrounded)
    #expect(state.details == nil)
  }

  @Test("Any other interruption is the OS taking the camera, named in the details", arguments: [
    (reason: AVCaptureSession.InterruptionReason.videoDeviceInUseByAnotherClient,
     name: "videoDeviceInUseByAnotherClient"),
    (reason: .audioDeviceInUseByAnotherClient, name: "audioDeviceInUseByAnotherClient"),
    (reason: .videoDeviceNotAvailableWithMultipleForegroundApps,
     name: "videoDeviceNotAvailableWithMultipleForegroundApps"),
  ])
  func otherInterruptions(reason: AVCaptureSession.InterruptionReason, name: String) {
    let state = TextSightCamera.state(forInterruption: reason)

    #expect(state.reason == .interrupted)
    #expect(state.details == name)
  }

  @Test("A missing reason still reads as an interruption")
  func missingReason() {
    let state = TextSightCamera.state(forInterruption: nil)

    #expect(state.reason == .interrupted)
    #expect(state.details == nil)
  }

  @Test("A runtime error carries the error's own wording")
  func runtimeError() {
    let error = NSError(domain: AVFoundationErrorDomain,
                        code: AVError.Code.mediaServicesWereReset.rawValue)

    #expect(TextSightCamera.state(forRuntimeError: error).details == error.localizedDescription)
    #expect(TextSightCamera.state(forRuntimeError: nil).details == nil)
  }

  @Test("Nothing is reported for a session that never opened, on release or detach")
  func silentWithoutASession() async throws {
    let recorder = StateRecorder()
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(),
                                 onSessionState: recorder.record)

    try await camera.dispose()
    camera.detach()
    // `dispose` rides the same queue, so awaiting it drains the detach's release too.
    try await camera.dispose()

    #expect(recorder.states.isEmpty)
  }
}

/// Collects reported states. Called on the camera's session queue, read after it drained.
private final class StateRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var recorded: [SessionStateMessage] = []

  var states: [SessionStateMessage] { lock.withLock { recorded } }

  func record(_ state: SessionStateMessage) {
    lock.withLock { recorded.append(state) }
  }
}
