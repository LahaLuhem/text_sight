import Flutter

/// The text_sight iOS plugin.
///
/// Wires up the Pigeon control channel, the captures `EventChannel` and the preview texture, then
/// hands the real work to `TextSightCamera`. Imports stay system-only, which is the no-bundling
/// contract. The control methods are `internal` because Pigeon's generated types are, so a `public`
/// signature would not compile.
public final class TextSightPlugin: NSObject, FlutterPlugin, TextSightHostApi {
  private let camera: TextSightCamera
  private let modelReadiness: TextSightModelReadiness

  init(camera: TextSightCamera, modelReadiness: TextSightModelReadiness) {
    self.camera = camera
    self.modelReadiness = modelReadiness
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let stateApi = TextSightFlutterApi(binaryMessenger: messenger)
    let camera = TextSightCamera(textureRegistry: registrar.textures(), onSessionState: { state in
      // Main thread only. A failed send just means no Dart handler is attached.
      Task { @MainActor in try? await stateApi.onSessionStateChanged(state: state) }
    })
    let modelReadiness = TextSightModelReadiness()
    let plugin = TextSightPlugin(camera: camera, modelReadiness: modelReadiness)

    TextSightHostApiSetup.setUp(binaryMessenger: messenger, api: plugin)

    let capturesChannel = FlutterEventChannel(name: capturesChannelName, binaryMessenger: messenger)
    capturesChannel.setStreamHandler(camera)

    let readinessChannel = FlutterEventChannel(name: readinessChannelName, binaryMessenger: messenger)
    readinessChannel.setStreamHandler(modelReadiness)

    // Anchor the plugin to the registrar. The texture registry holds the camera, the plugin holds
    // the readiness handler, and publishing is what earns us `detachFromEngine(for:)` below.
    registrar.publish(plugin)
  }

  /// Engine teardown: drops the session and cancels in-flight recognition, which would otherwise
  /// run until ARC got round to us. No `setUp(api: nil)`, since this fires from
  /// `FlutterEngine.dealloc` where the messenger is already gone.
  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    camera.detach()
  }

  func initialize(options: TextSightOptionsMessage,
                  resolution: CaptureResolutionMessage) async throws -> Int64 {
    try await camera.initialize(options: options, resolution: resolution)
  }

  func start() throws {
    camera.start()
  }

  func pauseRecognition() throws {
    camera.pauseRecognition()
  }

  func dispose() async throws {
    try await camera.dispose()
  }

  func checkCameraPermission() throws -> CameraPermissionStatusMessage {
    CameraPermission.current()
  }

  func requestCameraPermission() async throws -> CameraPermissionStatusMessage {
    await CameraPermission.request()
  }

  func setOptions(options: TextSightOptionsMessage) throws {
    camera.setOptions(options: options)
  }

  func confidenceScale() throws -> ConfidenceScaleMessage {
    camera.confidenceScale
  }

  func setTorchEnabled(enabled: Bool) throws {
    camera.setTorchEnabled(enabled: enabled)
  }

  func ensureModelReady() async throws -> [String: Any?] {
    await modelReadiness.ensureModelReady()
  }

  func recognizeImage(bytes: FlutterStandardTypedData,
                      options: TextSightOptionsMessage) async throws -> [String: Any?] {
    try await camera.recognizeImage(bytes: bytes, options: options)
  }

  func recognizePath(path: String,
                     options: TextSightOptionsMessage) async throws -> [String: Any?] {
    try await camera.recognizePath(path: path, options: options)
  }
}

private let capturesChannelName = "com.lahaluhem.text_sight/captures"
private let readinessChannelName = "com.lahaluhem.text_sight/readiness"
