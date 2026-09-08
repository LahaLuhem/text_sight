import Testing

@testable import text_sight

/// The session runs only while it is wanted, the app is in the foreground and nothing has failed.
@Suite("Session policy")
struct SessionPolicyTests {
  @Test("Any missing input keeps the session stopped", arguments: [
    (wants: true, foreground: true, failed: false, runs: true),
    (wants: false, foreground: true, failed: false, runs: false),
    (wants: true, foreground: false, failed: false, runs: false),
    (wants: true, foreground: true, failed: true, runs: false),
  ])
  func shouldRun(wants: Bool, foreground: Bool, failed: Bool, runs: Bool) {
    #expect(
      TextSightCamera.shouldRun(wantsSession: wants, isForeground: foreground, hasFailed: failed)
        == runs
    )
  }
}
