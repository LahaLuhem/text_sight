import CoreVideo

/// Paces live recognition: keeps only the newest frame and runs one recognition at a time, starting
/// the next as soon as the previous returns.
///
/// The mailbox is what enforces that, rather than a hand-managed slot. `bufferingNewest(1)` holds
/// the latest frame and throws the older one away, and a single consumer loop means recognition
/// never overlaps itself and never sits idle waiting for a camera callback to let it go again.
/// Waiting for that callback is what capped the rate at `ceil(latency / frameInterval)` frames.
final class FrameGate {
  /// What runs for each frame. Set once, when the camera is built.
  var onFrame: (CVPixelBuffer) async -> Void = { _ in }

  private let lock = NSLock()
  private var mailbox: AsyncStream<CVPixelBuffer>.Continuation?
  private var consumer: Task<Void, Never>?

  /// Hands over the newest frame, starting the consumer if there is not one yet. Never blocks, so
  /// the capture queue is free the moment it returns.
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
