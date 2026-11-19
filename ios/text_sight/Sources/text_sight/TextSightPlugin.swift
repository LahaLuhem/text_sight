import Flutter

/// Wires up the Pigeon channel, the captures `EventChannel` and the preview texture, then hands the
/// work to `TextSightCamera` (live) and `StillRecognizer` (one-shot). The control methods are
/// `internal` because Pigeon's generated types are, so a `public` signature wouldn't compile.
public final class TextSightPlugin: NSObject, FlutterPlugin, TextSightHostApi {
  private let camera: TextSightCamera
  private let stills: StillRecognizer
  private let modelReadiness: TextSightModelReadiness

  init(camera: TextSightCamera, stills: StillRecognizer, modelReadiness: TextSightModelReadiness) {
    self.camera = camera
    self.stills = stills
    self.modelReadiness = modelReadiness
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let flutterApi = TextSightFlutterApi(binaryMessenger: messenger)
    // One recognizer for both drivers. It takes its config with each call, so sharing it is safe.
    let recognizer = TextRecognizerFactory.make()
    // A failed send means no Dart handler is attached.
    let camera = TextSightCamera(
      textureRegistry: registrar.textures(),
      recognizer: recognizer,
      onSessionState: { state in try? await flutterApi.onSessionStateChanged(state: state) },
      onPreview: { preview in try? await flutterApi.onPreviewChanged(preview: preview) }
    )
    let modelReadiness = TextSightModelReadiness()
    let plugin = TextSightPlugin(camera: camera, stills: StillRecognizer(recognizer: recognizer),
                                 modelReadiness: modelReadiness)

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
    try await stills.recognizeImage(bytes: bytes, options: options)
  }

  func recognizePath(path: String,
                     options: TextSightOptionsMessage) async throws -> [String: Any?] {
    try await stills.recognizePath(path: path, options: options)
  }
}

private let capturesChannelName = "com.lahaluhem.text_sight/captures"
private let readinessChannelName = "com.lahaluhem.text_sight/readiness"
