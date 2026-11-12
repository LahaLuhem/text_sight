import AsyncQueue
import AVFoundation
import Testing

@testable import text_sight

/// What each capture-session notification turns into, and how states reach Dart: in order, and
/// never after detach.
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

  @Test("States reach Dart in the order the camera emits them")
  func emitOrder() async {
    let recorder = await StateRecorder()
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(),
                                 onSessionState: recorder.record)
    let emitted = (0..<200).map(String.init)

    for details in emitted { camera.emitState(paused(details)) }
    await drainPushes()

    #expect(await recorder.details == emitted)
  }

  @Test("Releasing a session that never opened reports nothing")
  func silentRelease() async throws {
    let recorder = await StateRecorder()
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(),
                                 onSessionState: recorder.record)

    try await camera.dispose()
    camera.emitState(paused("fence"))
    await drainPushes()

    #expect(await recorder.details == ["fence"])
  }

  @Test("Nothing reaches Dart after detach")
  func silentAfterDetach() async {
    let recorder = await StateRecorder()
    let camera = TextSightCamera(textureRegistry: StubTextureRegistry(),
                                 onSessionState: recorder.record)

    camera.emitState(paused("before"))
    await drainPushes()
    camera.detach()
    camera.emitState(paused("after"))
    await drainPushes()

    #expect(await recorder.details == ["before"])
  }
}

private func paused(_ details: String) -> SessionPausedMessage {
  SessionPausedMessage(reason: .interrupted, details: details)
}

/// Waits until every push queued so far has started, which is when it reaches the recorder.
private func drainPushes() async {
  await Task(on: MainActor.queue) {}.value
}

/// Collects reported states, on main as the camera delivers them.
@MainActor
private final class StateRecorder {
  private var states: [SessionStateMessage] = []

  var details: [String?] { states.map { ($0 as? SessionPausedMessage)?.details } }

  func record(_ state: SessionStateMessage) async {
    states.append(state)
  }
}
