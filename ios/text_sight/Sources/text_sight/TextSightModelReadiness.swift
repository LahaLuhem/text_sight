import Flutter

/// Readiness on iOS is always ready: Vision ships with the OS, so there is nothing to download.
/// This exists to hold up the cross-platform `TextSightModel` contract, and emits the same map
/// shape Android does.
final class TextSightModelReadiness: NSObject {
  private var eventSink: FlutterEventSink?

  /// Resolves immediately to the ready state. Delegated from the plugin's `TextSightHostApi`.
  func ensureModelReady() async -> [String: Any?] {
    emit(Self.readyState)

    return Self.readyState
  }

  /// Hops to main before touching the sink. A sink call off the main thread is a crash waiting to
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
    // Vision is always ready, so surface the current state on subscription.
    events(Self.readyState)

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil

    return nil
  }
}
