import CoreVideo

/// Paces live recognition: newest frame only, one at a time, and the next starts as soon as the
/// previous returns.
///
/// `bufferingNewest(1)` plus one consumer loop enforces that, rather than a hand-managed slot.
/// Waiting on a camera callback to reopen the gate is what capped the rate at
/// `ceil(latency / frameInterval)` frames.
final class FrameGate {
  /// What runs for each frame. Set once, when the camera is built.
  var onFrame: (CVPixelBuffer) async -> Void = { _ in }

  private let lock = NSLock()
  private var mailbox: AsyncStream<CVPixelBuffer>.Continuation?
  private var consumer: Task<Void, Never>?

  /// Hands over the newest frame, starting the consumer if there is not one. Never blocks, so the
  /// capture queue stays free.
  func offer(_ pixelBuffer: CVPixelBuffer) {
    lock.withLock { mailbox ?? startConsumer() }.yield(pixelBuffer)
  }

  /// Cancels the recognition in flight and ends the consumer. Idempotent, and a later `offer`
  /// starts a fresh one, so a session can be torn down and reopened.
  func stop() {
    let (claimedConsumer, claimedMailbox) = lock.withLock {
      let claimed = (consumer, mailbox)
      consumer = nil
      mailbox = nil

      return claimed
    }

    claimedMailbox?.finish()
    claimedConsumer?.cancel()
  }

  /// Builds the mailbox and the loop that drains it. The caller holds `lock`.
  private func startConsumer() -> AsyncStream<CVPixelBuffer>.Continuation {
    // The build closure runs during init, so this is assigned before the next line reads it.
    var handle: AsyncStream<CVPixelBuffer>.Continuation!
    let frames = AsyncStream<CVPixelBuffer>(bufferingPolicy: .bufferingNewest(1)) { handle = $0 }
    let work = onFrame

    mailbox = handle
    consumer = Task { for await pixelBuffer in frames { await work(pixelBuffer) } }

    return handle
  }
}
