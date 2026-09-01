import Flutter

/// The text_sight iOS plugin.
///
/// Wires the Pigeon control channel (`TextSightHostApi`), the per-frame captures
/// `EventChannel`, and the preview texture, delegating capture and recognition to
/// `TextSightCamera`. No recognition library crosses into the Dart pubspec. The Apple side
/// imports only system frameworks (Vision / AVFoundation), the no-bundling contract.
///
/// The control methods are `internal`: `TextSightHostApi` (Pigeon-generated) and its message
/// types are themselves internal, so a `public` signature exposing them would not compile. Only
/// the `FlutterPlugin` registration surface needs to be `public`.
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
    let camera = TextSightCamera(textureRegistry: registrar.textures())
    let modelReadiness = TextSightModelReadiness()
    let plugin = TextSightPlugin(camera: camera, modelReadiness: modelReadiness)

    TextSightHostApiSetup.setUp(binaryMessenger: messenger, api: plugin)

    let capturesChannel = FlutterEventChannel(name: capturesChannelName, binaryMessenger: messenger)
    capturesChannel.setStreamHandler(camera)

    let readinessChannel = FlutterEventChannel(name: readinessChannelName, binaryMessenger: messenger)
    readinessChannel.setStreamHandler(modelReadiness)

    // Anchor the plugin's lifetime to the registrar. The texture registry retains the camera, and
    // the plugin retains the readiness handler. Publishing is also what earns us
    // `detachFromEngine(for:)` below.
    registrar.publish(plugin)
  }

  /// Engine teardown: releases the capture session and cancels in-flight recognition, which would
  /// otherwise keep running until ARC happened to reclaim us. No `setUp(api: nil)` here on purpose,
  /// since this fires from `FlutterEngine.dealloc` where the messenger is already gone.
  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    camera.detach()
  }

  func initialize(options: TextSightOptionsMessage) async throws -> Int64 {
    try await camera.initialize(options: options)
  }

  func start() throws {
    camera.start()
  }

  func stop() throws {
    camera.stop()
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

  func setRegionOfInterest(roi: RegionOfInterestMessage?) throws {
    camera.setRegionOfInterest(roi: roi)
  }

  func setRecognitionLevel(level: RecognitionLevelMessage) throws {
    camera.setRecognitionLevel(level: level)
  }

  func setLanguages(languages: [String]) throws {
    camera.setLanguages(languages: languages)
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
