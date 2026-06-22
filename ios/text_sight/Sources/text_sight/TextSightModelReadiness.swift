import Flutter

/// Reports model readiness on iOS, where recognition is Apple Vision — a system framework that is
/// always present. So readiness is constant: ready. This type exists only to satisfy the
/// cross-platform `TextSightModel` contract; there is no model to download (unlike Android's
/// unbundled ML Kit), so `ensureModelReady` resolves immediately and the readiness stream emits a
/// single ready event on subscription. The map shape is identical to the Android side's.
final class TextSightModelReadiness: NSObject {
  private var eventSink: FlutterEventSink?

  /// Resolves immediately to the ready state; delegated from the plugin's `TextSightHostApi`.
  func ensureModelReady(completion: @escaping (Result<[String: Any?], Error>) -> Void) {
    emit(Self.readyState)
    completion(.success(Self.readyState))
  }

  /// Hops to main before touching the sink — a sink call off the main thread is a crash waiting to
  /// happen, and `onCancel` can tear the sink down concurrently.
  private func emit(_ state: [String: Any?]) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(state)
    }
  }

  private static let readyState: [String: Any?] = ["state": "ready"]
}

// MARK: - FlutterStreamHandler (readiness EventChannel)

extension TextSightModelReadiness: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    // Vision is always ready; surface the current state on subscription.
    events(Self.readyState)

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil

    return nil
  }
}
