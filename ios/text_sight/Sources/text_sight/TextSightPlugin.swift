import Flutter

/// The text_sight iOS plugin.
///
/// Wires the Pigeon control channel (`TextSightHostApi`), the per-frame captures
/// `EventChannel`, and the preview texture, delegating capture and recognition to
/// `TextSightCamera`. No recognition library crosses into the Dart pubspec — the Apple side
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

    // Anchor the plugin's lifetime to the registrar; the texture registry retains the camera, and
    // the plugin retains the readiness handler.
    registrar.publish(plugin)
  }

  func initialize(options: TextSightOptionsMessage,
                  completion: @escaping (Result<Int64, Error>) -> Void) {
    camera.initialize(options: options, completion: completion)
  }

  func start(completion: @escaping (Result<Void, Error>) -> Void) {
    camera.start(completion: completion)
  }

  func stop(completion: @escaping (Result<Void, Error>) -> Void) {
    camera.stop(completion: completion)
  }

  func dispose(completion: @escaping (Result<Void, Error>) -> Void) {
    camera.dispose(completion: completion)
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

  func ensureModelReady(completion: @escaping (Result<[String: Any?], Error>) -> Void) {
    modelReadiness.ensureModelReady(completion: completion)
  }

  func recognizeImage(bytes: FlutterStandardTypedData, options: TextSightOptionsMessage,
                      completion: @escaping (Result<[String: Any?], Error>) -> Void) {
    camera.recognizeImage(bytes: bytes, options: options, completion: completion)
  }

  func recognizePath(path: String, options: TextSightOptionsMessage,
                     completion: @escaping (Result<[String: Any?], Error>) -> Void) {
    camera.recognizePath(path: path, options: options, completion: completion)
  }
}

private let capturesChannelName = "com.lahaluhem.text_sight/captures"
private let readinessChannelName = "com.lahaluhem.text_sight/readiness"
