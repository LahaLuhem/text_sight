import Flutter

/// Always ready, since Vision ships with iOS. It's here so `TextSightModel` works the same on both
/// platforms, and it sends the same map Android does.
final class TextSightModelReadiness: NSObject {
  private var eventSink: FlutterEventSink?

  func ensureModelReady() async -> [String: Any?] {
    emit(Self.readyState)

    return Self.readyState
  }

  /// On main, since that's the only thread a sink takes calls on.
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
    // Always ready, so a new listener hears it at once.
    events(Self.readyState)

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil

    return nil
  }
}
