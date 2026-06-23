import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Flutter
import ImageIO

/// Owns the `AVCaptureSession`, the Vision recognizer, and the preview texture for one live
/// recognition session — the iOS twin of the Android `TextSightCamera`.
///
/// Recognition runs off the platform main thread (Vision's own async executor, kicked off the
/// capture-delegate queue); boxes are normalized to top-left `[0, 1]` here — Vision yields
/// lower-left normalized rects — and marshalled back to main before reaching the captures
/// `EventChannel` sink. Backpressure is a single in-flight recognition plus
/// `alwaysDiscardsLateVideoFrames`: a late frame is dropped, never queued. Only system
/// frameworks are imported (here: AVFoundation / CoreMedia / CoreVideo / Flutter; Vision sits
/// behind the `TextRecognizer`) — the no-bundling contract holds structurally on the Apple side.
final class TextSightCamera: NSObject {
  private let textureRegistry: FlutterTextureRegistry
  private let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "com.lahaluhem.text_sight.session")
  private let captureQueue = DispatchQueue(label: "com.lahaluhem.text_sight.capture")

  /// The Vision backend behind the `TextRecognizer` seam. Stateless w.r.t. config (it is passed
  /// per call), so the live path and the one-shot share this one instance, race-free.
  private let recognizer: any TextRecognizer = ModernTextRecognizer()

  /// Guards every field touched from more than one thread: the latest pixel buffer (capture
  /// queue writes, raster thread reads via `copyPixelBuffer`), the sink, the recognizer config
  /// (control channel writes, capture queue reads), and the recognition flags.
  private let stateLock = NSLock()

  private var eventSink: FlutterEventSink?
  private var textureId: Int64?
  private var latestPixelBuffer: CVPixelBuffer?
  private var captureDevice: AVCaptureDevice?
  private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
  private var rotationObservation: NSKeyValueObservation?

  /// Clockwise degrees (from the rotation coordinator) to rotate the sensor buffer upright. The
  /// buffer is delivered unrotated; this drives the Vision orientation and the reported
  /// `quarterTurns` that `TextSightView` applies to the preview texture.
  private var currentRotationAngle: CGFloat = 0

  // Recognizer config, stored as the Pigeon transport types and snapshotted into a
  // `RecognitionConfig` per frame for the recognizer (which builds its own value-typed request).
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

    session.commitConfiguration()

    startTrackingRotation(for: device)

    let id = textureRegistry.register(self)
    stateLock.lock()
    textureId = id
    stateLock.unlock()

    session.startRunning()

    return id
  }

  /// Tracks the device→upright rotation via an `AVCaptureDevice.RotationCoordinator` (iOS 17+).
  /// The buffer itself is delivered unrotated — cheaper, and it avoids relying on data-output
  /// rotation; instead the angle is reported to Dart as `quarterTurns` (so `TextSightView` rotates
  /// the preview texture) and is used to orient Vision so recognition stays upright and boxes come
  /// out display-oriented.
  private func startTrackingRotation(for device: AVCaptureDevice) {
    let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
    rotationCoordinator = coordinator

    updateRotationAngle(coordinator.videoRotationAngleForHorizonLevelCapture)
    rotationObservation = coordinator.observe(
      \.videoRotationAngleForHorizonLevelCapture, options: [.new]
    ) { [weak self] _, change in
      guard let self, let angle = change.newValue else { return }

      self.updateRotationAngle(angle)
    }
  }

  private func updateRotationAngle(_ angle: CGFloat) {
    stateLock.lock()
    currentRotationAngle = angle
    stateLock.unlock()
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
    captureDevice = nil
  }

  // MARK: Recognition

  /// Snapshots the current config and recognizes off-main, emitting the per-frame map on success.
  /// `isProcessing` is reset whatever the outcome, releasing backpressure.
  private func recognize(_ pixelBuffer: CVPixelBuffer) {
    stateLock.lock()
    let config = RecognitionConfig(level: recognitionLevel, languages: recognitionLanguages,
                                   roi: regionOfInterest)
    let angle = currentRotationAngle
    stateLock.unlock()

    let rotation = Self.displayRotation(forCaptureAngle: angle)

    // The buffer is sensor-oriented; report its display-oriented size (axes swap on a quarter
    // turn) to match the boxes Vision returns in the oriented space.
    let bufferWidth = Double(CVPixelBufferGetWidth(pixelBuffer))
    let bufferHeight = Double(CVPixelBufferGetHeight(pixelBuffer))
    let imageWidth = rotation.isQuarterTurned ? bufferHeight : bufferWidth
    let imageHeight = rotation.isQuarterTurned ? bufferWidth : bufferHeight

    Task { [weak self] in
      defer { self?.finishProcessing() }

      // Drop a single failed frame rather than tearing down the session (CODESTYLE: `try?`).
      guard
        let lines = try? await self?.recognizer.recognize(pixelBuffer: pixelBuffer,
                                                           orientation: rotation.orientation,
                                                           config: config)
      else { return }

      let frame = Self.encodeFrame(lines, imageWidth: imageWidth, imageHeight: imageHeight,
                                   quarterTurns: rotation.quarterTurns)
      self?.emit(frame)
    }
  }

  private func finishProcessing() {
    stateLock.lock()
    isProcessing = false
    stateLock.unlock()
  }

  // MARK: Static one-shot recognition (no session, texture, or permission)

  /// Recognizes text in encoded image `bytes`; delegated from the plugin's `TextSightHostApi`.
  func recognizeImage(bytes: FlutterStandardTypedData, options: TextSightOptionsMessage,
                      completion: @escaping (Result<[String: Any?], Error>) -> Void) {
    guard let source = CGImageSourceCreateWithData(bytes.data as CFData, nil) else {
      completion(.failure(PigeonError(code: "decode-failed",
                                      message: "The image bytes could not be decoded.",
                                      details: nil)))
      return
    }

    recognizeStill(source, options: options, completion: completion)
  }

  /// Recognizes text in the image file at `path`; delegated from the plugin's `TextSightHostApi`.
  func recognizePath(path: String, options: TextSightOptionsMessage,
                     completion: @escaping (Result<[String: Any?], Error>) -> Void) {
    guard FileManager.default.fileExists(atPath: path) else {
      completion(.failure(PigeonError(code: "file-not-found",
                                      message: "No file exists at \(path).", details: nil)))
      return
    }
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
      completion(.failure(PigeonError(code: "decode-failed",
                                      message: "The image at \(path) could not be decoded.",
                                      details: nil)))
      return
    }

    recognizeStill(source, options: options, completion: completion)
  }

  /// Decodes a still from `source` (honouring EXIF orientation), runs a transient recognizer off
  /// the main thread, and completes on main with the same per-frame map the live path emits —
  /// `quarterTurns` 0, since a still is already upright. No session, texture, or sink is touched.
  private func recognizeStill(_ source: CGImageSource, options: TextSightOptionsMessage,
                              completion: @escaping (Result<[String: Any?], Error>) -> Void) {
    let config = RecognitionConfig(level: options.level, languages: options.languages,
                                   roi: options.roi)

    Task { [recognizer] in
      guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        DispatchQueue.main.async {
          completion(.failure(PigeonError(code: "decode-failed",
                                          message: "The image could not be decoded.", details: nil)))
        }
        return
      }

      let orientation = Self.orientation(of: source)
      // Report the box space (display-oriented): axes swap when EXIF turns the image a quarter.
      let isQuarterTurned = switch orientation {
      case .left, .leftMirrored, .right, .rightMirrored: true
      default: false
      }
      let pixelWidth = Double(cgImage.width)
      let pixelHeight = Double(cgImage.height)

      do {
        let lines = try await recognizer.recognize(cgImage: cgImage, orientation: orientation,
                                                   config: config)
        let frame = Self.encodeFrame(lines,
                                     imageWidth: isQuarterTurned ? pixelHeight : pixelWidth,
                                     imageHeight: isQuarterTurned ? pixelWidth : pixelHeight,
                                     quarterTurns: 0)
        DispatchQueue.main.async { completion(.success(frame)) }
      } catch {
        DispatchQueue.main.async {
          completion(.failure(PigeonError(code: "decode-failed",
                                          message: error.localizedDescription, details: nil)))
        }
      }
    }
  }

  /// The EXIF orientation stored in `source`, or `.up` when absent.
  private static func orientation(of source: CGImageSource) -> CGImagePropertyOrientation {
    guard
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let raw = properties[kCGImagePropertyOrientation] as? UInt32,
      let orientation = CGImagePropertyOrientation(rawValue: raw)
    else { return .up }

    return orientation
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

  /// Encodes neutral recognized lines into the self-describing per-frame map — byte-identical to
  /// the shape the Android side emits over `com.lahaluhem.text_sight/captures`. Internal (not
  /// `private`) so `RunnerTests` can exercise it via `@testable import`.
  static func encodeFrame(_ lines: [RecognizedLineData],
                          imageWidth: Double, imageHeight: Double,
                          quarterTurns: Int) -> [String: Any] {
    let encodedLines = lines.map { line -> [String: Any] in
      [
        "text": line.text,
        // A non-null Double, which the nullable `RecognizedLine.confidence` contract accepts.
        "confidence": line.confidence,
        "left": Double(line.box.minX),
        "top": Double(line.box.minY),
        "width": Double(line.box.width),
        "height": Double(line.box.height),
        // Word-level elements are reserved for a future additive release.
        "elements": NSNull(),
      ]
    }

    return [
      "imageWidth": imageWidth,
      "imageHeight": imageHeight,
      "quarterTurns": quarterTurns,
      "lines": encodedLines,
    ]
  }

  /// Maps the coordinator's clockwise-to-upright `angle` (degrees) to the preview quarter-turns
  /// (clockwise, for Flutter's `RotatedBox`), the matching Vision orientation for the *unrotated*
  /// buffer, and whether the axes swap. If the on-device preview comes out rotated the wrong way,
  /// this single mapping (the angle↔orientation convention) is the knob to adjust. Internal (not
  /// `private`) so `RunnerTests` can exercise it via `@testable import`.
  static func displayRotation(forCaptureAngle angle: CGFloat)
    -> (quarterTurns: Int, orientation: CGImagePropertyOrientation, isQuarterTurned: Bool) {
    switch (Int(angle.rounded()) % 360 + 360) % 360 {
    // Back camera: a 90° clockwise-to-upright angle (portrait) is EXIF `.right`; the opposite
    // quarter-turn (270°) is `.left`. Swapping the two feeds Vision a 180°-rotated image, which
    // wrecks recognition in portrait while landscape (`.up`/`.down`) still looks fine.
    case 90: return (1, .right, true)
    case 180: return (2, .down, false)
    case 270: return (3, .left, true)
    default: return (0, .up, false)
    }
  }
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
