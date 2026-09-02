import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Flutter
import ImageIO
import UIKit

/// Owns the `AVCaptureSession`, the Vision recognizer, and the preview texture for one live
/// recognition session, the iOS twin of the Android `TextSightCamera`.
///
/// Recognition runs off the platform main thread (Vision's own async executor, kicked off the
/// capture-delegate queue). Boxes are normalized to top-left `[0, 1]` here (Vision yields
/// lower-left normalized rects) and marshalled back to main before reaching the captures
/// `EventChannel` sink. Backpressure is a single in-flight recognition plus
/// `alwaysDiscardsLateVideoFrames`: a late frame is dropped, never queued. Only system
/// frameworks are imported (here: AVFoundation / CoreMedia / CoreVideo / Flutter, with Vision
/// behind the `TextRecognizer`), so the no-bundling contract holds structurally on the Apple side.
final class TextSightCamera: NSObject {
  private let textureRegistry: FlutterTextureRegistry
  private let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "com.lahaluhem.text_sight.session")
  private let captureQueue = DispatchQueue(label: "com.lahaluhem.text_sight.capture")

  /// The Vision backend behind the `TextRecognizer` seam. Stateless w.r.t. config (it is passed
  /// per call), so the live path and the one-shot share this one instance, race-free.
  private let recognizer: any TextRecognizer

  /// Guards every field touched from more than one thread: the latest pixel buffer (capture
  /// queue writes, raster thread reads via `copyPixelBuffer`), the sink, the recognizer config
  /// (control channel writes, capture queue reads), and the recognition gate plus its task.
  private let stateLock = NSLock()

  private var eventSink: FlutterEventSink?
  private var textureId: Int64?
  private var latestPixelBuffer: CVPixelBuffer?
  private var captureDevice: AVCaptureDevice?

  /// Torch intent, re-asserted on foreground return: the hardware drops the torch with the
  /// camera. Touched only on `sessionQueue`.
  private var torchEnabled = false
  /// Background/foreground observer tokens, registered in `init`, removed in `deinit`.
  private var appLifecycleObservers: [NSObjectProtocol] = []
  // Type-erased: the concrete `AVCaptureDevice.RotationCoordinator` is iOS 17+, but this class
  // deploys to 15. Held only to keep the coordinator alive for its KVO, and stays nil on iOS 15-16.
  private var rotationCoordinator: Any?
  private var rotationObservation: NSKeyValueObservation?

  /// Clockwise degrees (from the rotation coordinator) to rotate the sensor buffer upright. The
  /// buffer is delivered unrotated. This drives the Vision orientation and the reported
  /// `quarterTurns` that `TextSightView` applies to the preview texture. Stays `0` on iOS 15-16
  /// (no `RotationCoordinator`): preview and recognition do not follow live rotation there.
  private var currentRotationAngle: CGFloat = 0

  // Recognizer config, stored as the Pigeon transport types and snapshotted into a
  // `RecognitionConfig` per frame for the recognizer (which builds its own value-typed request).
  private var recognitionLevel: RecognitionLevelMessage = .fast
  private var recognitionLanguages: [String] = []
  private var regionOfInterest: RegionOfInterestMessage?

  private var isRecognizing = false

  /// Set when the engine detaches, so a control call that was already in flight cannot rebuild the
  /// session behind teardown's back.
  private var isDetached = false

  /// The one in-flight recognition, nil when idle: both the backpressure gate and the handle that
  /// teardown cancels. Only the owning task clears it, see `releaseSession`.
  private var recognitionTask: Task<Void, Never>?

  /// `recognizer` defaults to the OS-picked backend (modern on iOS 18+, legacy on 15-17). Tests
  /// pass a stub instead.
  init(textureRegistry: FlutterTextureRegistry,
       recognizer: any TextRecognizer = TextRecognizerFactory.make()) {
    self.textureRegistry = textureRegistry
    self.recognizer = recognizer
    super.init()
    observeAppLifecycle()
  }

  deinit {
    // Insurance for the path where neither dispose nor detach ran and ARC just reclaimed us.
    recognitionTask?.cancel()
    appLifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
  }

  // MARK: Control channel (delegated from TextSightPlugin's TextSightHostApi conformance)

  func initialize(options: TextSightOptionsMessage) async throws -> Int64 {
    // One lock hold for all three, so a frame never snapshots a half-applied update.
    stateLock.withLock {
      recognitionLevel = options.level
      recognitionLanguages = options.languages
      regionOfInterest = options.roi
    }

    guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
      throw PigeonError(code: "permission-denied",
                        message: "Camera permission has not been granted.", details: nil)
    }

    do {
      return try await onSessionQueue { try self.configureSession() }
    } catch let error as PigeonError {
      // Already shaped for Dart (the detach guard), so pass it through instead of re-wrapping.
      throw error
    } catch {
      throw PigeonError(code: "initialization-failed",
                        message: error.localizedDescription, details: nil)
    }
  }

  /// Synchronous: it only flips a flag under the lock, so it needs no queue hop.
  func start() {
    stateLock.withLock { isRecognizing = true }
  }

  /// Synchronous, same as `start`.
  func stop() {
    stateLock.withLock { isRecognizing = false }
  }

  func dispose() async throws {
    try await onSessionQueue { self.releaseSession() }
  }

  /// Engine teardown: shuts the gate for good, then releases the session off the calling thread.
  /// Internal (not `private`) so `RunnerTests` can drive it without a `FlutterPluginRegistrar`.
  func detach() {
    stateLock.withLock { isDetached = true }

    // Strong `self` on purpose: teardown has to outlive the plugin's last external reference. Every
    // other `sessionQueue.async` here captures weakly, this one must not.
    sessionQueue.async { self.releaseSession() }
  }

  func setRegionOfInterest(roi: RegionOfInterestMessage?) {
    stateLock.withLock { regionOfInterest = roi }
  }

  func setRecognitionLevel(level: RecognitionLevelMessage) {
    stateLock.withLock { recognitionLevel = level }
  }

  func setLanguages(languages: [String]) {
    stateLock.withLock { recognitionLanguages = languages }
  }

  func setTorchEnabled(enabled: Bool) {
    sessionQueue.async { [weak self] in
      guard let self else { return }

      self.torchEnabled = enabled
      self.applyTorch(enabled)
    }
  }

  // MARK: Session lifecycle

  /// Builds the capture graph (back camera → BGRA video output), registers the preview texture,
  /// and starts the session. Runs on `sessionQueue`, since `startRunning()` must never block main.
  private func configureSession() throws -> Int64 {
    // A control call still in flight when detach landed must not rebuild the session. The other
    // ordering is already safe: a release queued behind us on `sessionQueue` tears this back down.
    let detached = stateLock.withLock { isDetached }
    guard !detached else {
      throw PigeonError(code: "detached",
                        message: "The plugin is not attached to a Flutter engine.", details: nil)
    }

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

    // iOS 15-16 has no `RotationCoordinator`, so rotation stays untracked there (documented).
    if #available(iOS 17, *) { startTrackingRotation(for: device) }

    let id = textureRegistry.register(self)
    stateLock.withLock { textureId = id }

    session.startRunning()

    return id
  }

  /// Tracks the device→upright rotation via an `AVCaptureDevice.RotationCoordinator` (iOS 17+).
  /// The buffer itself is delivered unrotated, which is cheaper and avoids relying on data-output
  /// rotation. Instead the angle is reported to Dart as `quarterTurns` (so `TextSightView` rotates
  /// the preview texture) and is used to orient Vision so recognition stays upright and boxes come
  /// out display-oriented. Gated to 17+: on iOS 15-16 the angle stays `0`, a deliberate degraded
  /// fallback (no live rotation), not a full pre-17 rotation path. See APPENDIX / the README note.
  @available(iOS 17, *)
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
    stateLock.withLock { currentRotationAngle = angle }
  }

  /// Stops capture while the app is backgrounded and restarts it on return. Stopping explicitly
  /// releases the camera instead of riding the system interruption, and the restart re-asserts
  /// the torch.
  private func observeAppLifecycle() {
    let center = NotificationCenter.default
    let onBackground = center.addObserver(
      forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
    ) { [weak self] _ in
      guard let self else { return }

      self.sessionQueue.async { self.suspendSession() }
    }
    let onForeground = center.addObserver(
      forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil
    ) { [weak self] _ in
      guard let self else { return }

      self.sessionQueue.async { self.resumeSession() }
    }
    appLifecycleObservers = [onBackground, onForeground]
  }

  /// Runs on `sessionQueue`.
  private func suspendSession() {
    if session.isRunning { session.stopRunning() }
  }

  /// Runs on `sessionQueue`. Restarts only a configured session, then re-asserts the dropped torch.
  private func resumeSession() {
    guard captureDevice != nil, !session.isRunning else { return }

    session.startRunning()
    applyTorch(torchEnabled)
  }

  /// Runs on `sessionQueue`.
  private func applyTorch(_ enabled: Bool) {
    guard let device = captureDevice, device.hasTorch, device.isTorchAvailable else { return }

    do {
      try device.lockForConfiguration()
      device.torchMode = enabled ? .on : .off
      device.unlockForConfiguration()
    } catch {
      // The device was busy. A failed torch toggle is not session-fatal, so drop it.
    }
  }

  /// Releases every per-session resource. Idempotent, so it is safe on dispose and engine detach.
  private func releaseSession() {
    rotationObservation?.invalidate()
    rotationObservation = nil
    rotationCoordinator = nil

    if session.isRunning { session.stopRunning() }

    // Only reconfigure if there is something to remove: a begin/commit pair on an empty session is
    // a no-op that still costs seconds on a CI simulator, and dispose-before-initialize hits it.
    if !session.inputs.isEmpty || !session.outputs.isEmpty {
      session.beginConfiguration()
      session.inputs.forEach { session.removeInput($0) }
      session.outputs.forEach { session.removeOutput($0) }
      session.commitConfiguration()
    }

    let (inFlight, releasedTextureId) = stateLock.withLock {
      isRecognizing = false
      latestPixelBuffer = nil
      let claimed = (recognitionTask, textureId)
      textureId = nil

      return claimed
    }

    // Cancel but leave the slot: only the owning task clears it, so a cancelled task still
    // draining can never wipe a newer task's handle. Outside the lock, the gate is shut above.
    inFlight?.cancel()

    releasedTextureId.map { textureRegistry.unregisterTexture($0) }
    captureDevice = nil
  }

  // MARK: Recognition

  /// Stores the frame for the preview, then starts recognition when the slot is free. Internal (not
  /// `private`) so `RunnerTests` can drive a frame without an `AVCaptureConnection`.
  func handle(_ pixelBuffer: CVPixelBuffer) {
    let activeTextureId = stateLock.withLock {
      latestPixelBuffer = pixelBuffer
      // Claim the slot and build the task in one lock hold. Split across two, a teardown could land
      // in between and leave a task nobody cancels.
      if isRecognizing, recognitionTask == nil, eventSink != nil {
        recognitionTask = makeRecognitionTask(for: pixelBuffer)
      }

      return textureId
    }

    // Keep the preview live every frame. Recognition is throttled by the single-in-flight slot.
    activeTextureId.map { textureRegistry.textureFrameAvailable($0) }
  }

  /// Builds one frame's task, reading the config and rotation straight off the guarded fields.
  /// The caller holds `stateLock`.
  private func makeRecognitionTask(for pixelBuffer: CVPixelBuffer) -> Task<Void, Never> {
    let config = RecognitionConfig(level: recognitionLevel, languages: recognitionLanguages,
                                   roi: regionOfInterest)
    let rotation = Self.displayRotation(forCaptureAngle: currentRotationAngle)

    // The buffer is sensor-oriented, so report its display-oriented size (axes swap on a quarter
    // turn) to match the boxes Vision returns in the oriented space.
    let bufferWidth = Double(CVPixelBufferGetWidth(pixelBuffer))
    let bufferHeight = Double(CVPixelBufferGetHeight(pixelBuffer))
    let imageWidth = rotation.isQuarterTurned ? bufferHeight : bufferWidth
    let imageHeight = rotation.isQuarterTurned ? bufferWidth : bufferHeight

    return Task { [weak self] in
      defer { self?.clearRecognitionSlot() }

      // Drop a single failed frame rather than tearing down the session (CODESTYLE: `try?`).
      guard
        let lines = try? await self?.recognizer.recognize(pixelBuffer: pixelBuffer,
                                                           orientation: rotation.orientation,
                                                           config: config),
        !Task.isCancelled
      else { return }

      let frame = Self.encodeFrame(lines, imageWidth: imageWidth, imageHeight: imageHeight,
                                   quarterTurns: rotation.quarterTurns)
      self?.emit(frame)
    }
  }

  /// Frees the slot for the next frame. Only the owning task calls this, from its `defer`.
  private func clearRecognitionSlot() {
    stateLock.withLock { recognitionTask = nil }
  }

  /// Runs `work` on `sessionQueue`, bridged to `async`. The queue is the session's synchronisation
  /// domain (`torchEnabled`, `suspendSession`, `resumeSession` all live on it), so callers keep the
  /// hop rather than replacing it.
  private func onSessionQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
      sessionQueue.async { continuation.resume(with: Result(catching: work)) }
    }
  }

  // MARK: Static one-shot recognition (no session, texture, or permission)

  /// Recognizes text in encoded image `bytes`. Delegated from the plugin's `TextSightHostApi`.
  func recognizeImage(bytes: FlutterStandardTypedData,
                      options: TextSightOptionsMessage) async throws -> [String: Any?] {
    // Untested: CGImageSourceCreateWithData returns a source for any Data, so this only guards
    // the documented nil case. The real decode failure surfaces in recognizeStill.
    guard let source = CGImageSourceCreateWithData(bytes.data as CFData, nil) else {
      throw PigeonError(code: "decode-failed",
                        message: "The image bytes could not be decoded.", details: nil)
    }

    return try await recognizeStill(source, options: options)
  }

  /// Recognizes text in the image file at `path`. Delegated from the plugin's `TextSightHostApi`.
  func recognizePath(path: String,
                     options: TextSightOptionsMessage) async throws -> [String: Any?] {
    guard FileManager.default.fileExists(atPath: path) else {
      throw PigeonError(code: "file-not-found", message: "No file exists at \(path).", details: nil)
    }
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
      throw PigeonError(code: "decode-failed",
                        message: "The image at \(path) could not be decoded.", details: nil)
    }

    return try await recognizeStill(source, options: options)
  }

  /// Decodes a still from `source` (honouring EXIF orientation) and returns the same per-frame map
  /// the live path emits, with `quarterTurns` 0 since a still is already upright. No session,
  /// texture, or sink is touched.
  private func recognizeStill(_ source: CGImageSource,
                              options: TextSightOptionsMessage) async throws -> [String: Any?] {
    let config = RecognitionConfig(level: options.level, languages: options.languages,
                                   roi: options.roi)

    guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw PigeonError(code: "decode-failed", message: "The image could not be decoded.",
                        details: nil)
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

      return Self.encodeFrame(lines,
                              imageWidth: isQuarterTurned ? pixelHeight : pixelWidth,
                              imageHeight: isQuarterTurned ? pixelWidth : pixelHeight,
                              quarterTurns: 0)
    } catch {
      throw PigeonError(code: "decode-failed", message: error.localizedDescription, details: nil)
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

  /// Hops to main and emits on the sink read under lock. A sink call from a background thread
  /// is a crash waiting to happen, and the sink can be torn down concurrently by `onCancel`.
  private func emit(_ frame: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      let sink = self.stateLock.withLock { self.eventSink }

      sink?(frame)
    }
  }

  /// Encodes neutral recognized lines into the self-describing per-frame map, byte-identical to
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
    // Back camera: a 90° clockwise-to-upright angle (portrait) is EXIF `.right`, and the opposite
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
    stateLock.withLock { latestPixelBuffer.map(Unmanaged.passRetained) }
  }
}

// MARK: - FlutterStreamHandler (captures EventChannel)

extension TextSightCamera: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stateLock.withLock { eventSink = events }

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stateLock.withLock { eventSink = nil }

    return nil
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension TextSightCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    handle(pixelBuffer)
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
