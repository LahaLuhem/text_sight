import AVFoundation
import CoreMedia
import CoreVideo
import Flutter
import Vision

/// Owns the `AVCaptureSession`, the Vision recognizer, and the preview texture for one live
/// recognition session — the iOS twin of the Android `TextSightCamera`.
///
/// Recognition runs off the platform main thread (Vision's own async executor, kicked off the
/// capture-delegate queue); boxes are normalized to top-left `[0, 1]` here — Vision yields
/// lower-left normalized rects — and marshalled back to main before reaching the captures
/// `EventChannel` sink. Backpressure is a single in-flight `RecognizeTextRequest` plus
/// `alwaysDiscardsLateVideoFrames`: a late frame is dropped, never queued. Only system
/// frameworks are imported (Vision / AVFoundation / CoreMedia / CoreVideo / Flutter) — the
/// no-bundling contract holds structurally on the Apple side.
final class TextSightCamera: NSObject {
  private let textureRegistry: FlutterTextureRegistry
  private let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "com.LahaLuhem.text_sight.session")
  private let captureQueue = DispatchQueue(label: "com.LahaLuhem.text_sight.capture")

  /// Guards every field touched from more than one thread: the latest pixel buffer (capture
  /// queue writes, raster thread reads via `copyPixelBuffer`), the sink, the recognizer config
  /// (control channel writes, capture queue reads), and the recognition flags.
  private let stateLock = NSLock()

  private var eventSink: FlutterEventSink?
  private var textureId: Int64?
  private var latestPixelBuffer: CVPixelBuffer?
  private var captureDevice: AVCaptureDevice?
  private var videoDataOutput: AVCaptureVideoDataOutput?
  private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
  private var rotationObservation: NSKeyValueObservation?

  // Recognizer config, stored as the Pigeon transport types and translated to Vision per frame
  // (a `RecognizeTextRequest` is a cheap value type, so there is no shared mutable request to race).
  private var recognitionLevel: RecognitionLevelMessage = .fast
  private var recognitionLanguages: [String] = []
  private var regionOfInterest: RegionOfInterestMessage?

  private var isRecognizing = false
  private var isProcessing = false

  init(textureRegistry: FlutterTextureRegistry) {
    self.textureRegistry = textureRegistry
    super.init()
  }

  // MARK: Control channel (delegated from TextSightPlugin's TextSightHostApi conformance)

  func initialize(options: TextSightOptionsMessage,
                  completion: @escaping (Result<Int64, Error>) -> Void) {
    stateLock.lock()
    recognitionLevel = options.level
    recognitionLanguages = options.languages
    regionOfInterest = options.roi
    stateLock.unlock()

    guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
      completion(.failure(PigeonError(code: "permission-denied",
                                      message: "Camera permission has not been granted.",
                                      details: nil)))
      return
    }

    sessionQueue.async { [weak self] in
      guard let self else { return }

      do {
        let id = try self.configureSession()
        DispatchQueue.main.async { completion(.success(id)) }
      } catch {
        DispatchQueue.main.async {
          completion(.failure(PigeonError(code: "initialization-failed",
                                          message: error.localizedDescription, details: nil)))
        }
      }
    }
  }

  func start(completion: @escaping (Result<Void, Error>) -> Void) {
    stateLock.lock()
    isRecognizing = true
    stateLock.unlock()

    completion(.success(()))
  }

  func stop(completion: @escaping (Result<Void, Error>) -> Void) {
    stateLock.lock()
    isRecognizing = false
    stateLock.unlock()

    completion(.success(()))
  }

  func dispose(completion: @escaping (Result<Void, Error>) -> Void) {
    sessionQueue.async { [weak self] in
      self?.releaseSession()
      DispatchQueue.main.async { completion(.success(())) }
    }
  }

  func setRegionOfInterest(roi: RegionOfInterestMessage?) {
    stateLock.lock()
    regionOfInterest = roi
    stateLock.unlock()
  }

  func setRecognitionLevel(level: RecognitionLevelMessage) {
    stateLock.lock()
    recognitionLevel = level
    stateLock.unlock()
  }

  func setLanguages(languages: [String]) {
    stateLock.lock()
    recognitionLanguages = languages
    stateLock.unlock()
  }

  func setTorchEnabled(enabled: Bool) {
    sessionQueue.async { [weak self] in
      guard let device = self?.captureDevice, device.hasTorch, device.isTorchAvailable else {
        return
      }

      do {
        try device.lockForConfiguration()
        device.torchMode = enabled ? .on : .off
        device.unlockForConfiguration()
      } catch {
        // The device was busy; a failed torch toggle is not session-fatal, so drop it.
      }
    }
  }

  // MARK: Session lifecycle

  /// Builds the capture graph (back camera → BGRA video output), registers the preview texture,
  /// and starts the session. Runs on `sessionQueue`; `startRunning()` must never block main.
  private func configureSession() throws -> Int64 {
    session.beginConfiguration()
    session.sessionPreset = .high

    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    else { throw CameraError.noCaptureDevice }
    captureDevice = device

    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
    session.addInput(input)

    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    output.alwaysDiscardsLateVideoFrames = true
    output.setSampleBufferDelegate(self, queue: captureQueue)
    guard session.canAddOutput(output) else { throw CameraError.cannotAddOutput }
    session.addOutput(output)
    videoDataOutput = output

    session.commitConfiguration()

    startTrackingRotation(for: device)

    let id = textureRegistry.register(self)
    stateLock.lock()
    textureId = id
    stateLock.unlock()

    session.startRunning()

    return id
  }

  /// Drives the video-output rotation off live device orientation via an
  /// `AVCaptureDevice.RotationCoordinator` (iOS 17+) so the preview texture and Vision always see
  /// an upright frame — the buffer dimensions (and the per-frame imageWidth/imageHeight) swap with
  /// orientation, and normalized boxes stay in display space. Observing the *preview* angle keeps
  /// the displayed texture WYSIWYG; `.up` then suffices for Vision.
  private func startTrackingRotation(for device: AVCaptureDevice) {
    let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
    rotationCoordinator = coordinator

    applyCaptureRotation(coordinator.videoRotationAngleForHorizonLevelPreview)
    rotationObservation = coordinator.observe(
      \.videoRotationAngleForHorizonLevelPreview, options: [.new]
    ) { [weak self] _, change in
      guard let self, let angle = change.newValue else { return }

      self.sessionQueue.async { self.applyCaptureRotation(angle) }
    }
  }

  /// Applies `angle` to the video-output connection when supported, keeping delivered buffers
  /// upright for the current device orientation.
  private func applyCaptureRotation(_ angle: CGFloat) {
    guard let connection = videoDataOutput?.connection(with: .video),
          connection.isVideoRotationAngleSupported(angle)
    else { return }

    connection.videoRotationAngle = angle
  }

  /// Releases every per-session resource. Idempotent — safe on dispose and on engine detach.
  private func releaseSession() {
    rotationObservation?.invalidate()
    rotationObservation = nil
    rotationCoordinator = nil

    if session.isRunning { session.stopRunning() }

    session.beginConfiguration()
    session.inputs.forEach { session.removeInput($0) }
    session.outputs.forEach { session.removeOutput($0) }
    session.commitConfiguration()

    stateLock.lock()
    isRecognizing = false
    isProcessing = false
    latestPixelBuffer = nil
    let releasedTextureId = textureId
    textureId = nil
    stateLock.unlock()

    releasedTextureId.map { textureRegistry.unregisterTexture($0) }
    videoDataOutput = nil
    captureDevice = nil
  }

  // MARK: Recognition

  /// Builds a fresh request from the current config and performs it off-main, emitting the
  /// per-frame map on success. `isProcessing` is reset whatever the outcome, releasing backpressure.
  private func recognize(_ pixelBuffer: CVPixelBuffer) {
    stateLock.lock()
    let level = recognitionLevel
    let languages = recognitionLanguages
    let roi = regionOfInterest
    stateLock.unlock()

    var request = RecognizeTextRequest()
    request.recognitionLevel = level == .accurate ? .accurate : .fast
    // Mirror the Dart `RecognitionLevel` enhanced-enum contract: accurate corrects, fast does not.
    request.usesLanguageCorrection = level == .accurate
    if !languages.isEmpty {
      request.recognitionLanguages = languages.map { Locale.Language(identifier: $0) }
    }
    if let roi {
      // Vision's region-of-interest is lower-left normalized; flip the incoming top-left rect.
      request.regionOfInterest = NormalizedRect(x: roi.left, y: 1 - (roi.top + roi.height),
                                                width: roi.width, height: roi.height)
    }

    let imageWidth = Double(CVPixelBufferGetWidth(pixelBuffer))
    let imageHeight = Double(CVPixelBufferGetHeight(pixelBuffer))

    Task { [weak self] in
      defer { self?.finishProcessing() }

      // Drop a single failed frame rather than tearing down the session (CODESTYLE: `try?`).
      guard let observations = try? await request.perform(on: pixelBuffer, orientation: .up)
      else { return }

      let frame = Self.encodeFrame(observations, imageWidth: imageWidth, imageHeight: imageHeight)
      self?.emit(frame)
    }
  }

  private func finishProcessing() {
    stateLock.lock()
    isProcessing = false
    stateLock.unlock()
  }

  /// Hops to main and emits on the sink read under lock — a sink call from a background thread
  /// is a crash waiting to happen, and the sink can be torn down concurrently by `onCancel`.
  private func emit(_ frame: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      self.stateLock.lock()
      let sink = self.eventSink
      self.stateLock.unlock()

      sink?(frame)
    }
  }

  /// Encodes observations into the self-describing per-frame map — byte-identical to the shape
  /// the Android side emits over `com.LahaLuhem.text_sight/captures`.
  private static func encodeFrame(_ observations: [RecognizedTextObservation],
                                  imageWidth: Double, imageHeight: Double) -> [String: Any] {
    let lines = observations.compactMap { observation -> [String: Any]? in
      guard let candidate = observation.topCandidates(1).first else { return nil }

      // A unit image size turns the lower-left normalized box into a top-left normalized one.
      let box = observation.boundingBox.toImageCoordinates(Self.normalizedUnitSize, origin: .upperLeft)

      return [
        "text": candidate.string,
        // Vision always supplies a per-candidate confidence (unlike ML Kit, never null here).
        "confidence": Double(candidate.confidence),
        "left": box.minX,
        "top": box.minY,
        "width": box.width,
        "height": box.height,
        // Word-level elements are reserved for a future additive release.
        "elements": NSNull(),
      ]
    }

    return ["imageWidth": imageWidth, "imageHeight": imageHeight, "lines": lines]
  }

  private static let normalizedUnitSize = CGSize(width: 1, height: 1)
}

// MARK: - FlutterTexture

extension TextSightCamera: FlutterTexture {
  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    stateLock.lock()
    defer { stateLock.unlock() }
    guard let pixelBuffer = latestPixelBuffer else { return nil }

    return Unmanaged.passRetained(pixelBuffer)
  }
}

// MARK: - FlutterStreamHandler (captures EventChannel)

extension TextSightCamera: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stateLock.lock()
    eventSink = events
    stateLock.unlock()

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stateLock.lock()
    eventSink = nil
    stateLock.unlock()

    return nil
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension TextSightCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    stateLock.lock()
    latestPixelBuffer = pixelBuffer
    let shouldRecognize = isRecognizing && !isProcessing && eventSink != nil
    if shouldRecognize { isProcessing = true }
    let activeTextureId = textureId
    stateLock.unlock()

    // Keep the preview live every frame; recognition is throttled by the single-in-flight flag.
    activeTextureId.map { textureRegistry.textureFrameAvailable($0) }

    if shouldRecognize { recognize(pixelBuffer) }
  }
}

/// Setup failures surfaced to Dart as `initialization-failed` via `error.localizedDescription`.
private enum CameraError: LocalizedError {
  case noCaptureDevice
  case cannotAddInput
  case cannotAddOutput

  var errorDescription: String? {
    switch self {
    case .noCaptureDevice: "No back-facing camera is available on this device."
    case .cannotAddInput: "The capture session rejected the camera input."
    case .cannotAddOutput: "The capture session rejected the video output."
    }
  }
}
