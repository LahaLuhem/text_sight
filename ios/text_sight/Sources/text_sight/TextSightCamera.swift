import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Flutter
import ImageIO
import UIKit

/// Owns the `AVCaptureSession`, the Vision recognizer, and the preview texture for one live
/// session. The Android twin is its own `TextSightCamera`.
///
/// Recognition runs off the main thread and hops back before reaching the captures sink. Boxes come
/// out top-left normalized, since Vision hands back lower-left. The `FrameGate` plus
/// `alwaysDiscardsLateVideoFrames` is the backpressure, so a late frame is dropped, never queued.
final class TextSightCamera: NSObject {
  /// One open capture session: the graph, the camera behind it, and the texture the preview
  /// renders. Built as a unit, dropped as a unit.
  private struct ActiveSession {
    let session: AVCaptureSession
    let device: AVCaptureDevice
    let textureId: Int64
  }

  private let textureRegistry: FlutterTextureRegistry
  private let makeSession: () -> AVCaptureSession
  private let sessionQueue = DispatchQueue(label: "com.lahaluhem.text_sight.session")
  private let captureQueue = DispatchQueue(label: "com.lahaluhem.text_sight.capture")

  /// The Vision backend behind the `TextRecognizer` seam. Stateless w.r.t. config (it is passed
  /// per call), so the live path and the one-shot share this one instance, race-free.
  private let recognizer: any TextRecognizer

  /// Guards every field two threads touch: the latest pixel buffer, the sink, the open session and
  /// the recognizer config. The gate does its own locking.
  private let stateLock = NSLock()

  /// Paces recognition: newest frame only, one at a time, next one starts on completion.
  private let gate = FrameGate()

  private var eventSink: FlutterEventSink?
  private var latestPixelBuffer: CVPixelBuffer?

  /// The open session, or `nil` when idle. Only `sessionQueue` ever writes it.
  private var activeSession: ActiveSession?

  /// Torch intent, re-asserted on foreground return: the hardware drops the torch with the
  /// camera. Touched only on `sessionQueue`.
  private var torchEnabled = false
  /// Background/foreground observer tokens, registered in `init`, removed in `deinit`.
  private var appLifecycleObservers: [NSObjectProtocol] = []
  // Type-erased: the concrete `AVCaptureDevice.RotationCoordinator` is iOS 17+, but this class
  // deploys to 15. Held only to keep the coordinator alive for its KVO, and stays nil on iOS 15-16.
  private var rotationCoordinator: Any?
  private var rotationObservation: NSKeyValueObservation?

  /// Clockwise degrees to turn the sensor buffer upright, from the rotation coordinator. Drives the
  /// Vision orientation and the `quarterTurns` the view applies. Stays `0` on iOS 15-16, which have
  /// no coordinator, so nothing follows rotation there.
  private var currentRotationAngle: CGFloat = 0

  // Recognizer config, stored as the Pigeon transport types and snapshotted into a
  // `RecognitionConfig` per frame for the recognizer (which builds its own value-typed request).
  private var recognitionLevel: RecognitionLevelMessage = .fast
  private var usesLanguageCorrection = true
  private var recognitionLanguages: [String] = []
  private var minimumTextHeight: Float = 0
  private var regionOfInterest: RegionOfInterestMessage?

  private var isRecognizing = false

  /// Written at initialize, read on the session queue when the graph builds, so it takes the lock.
  private var captureResolution: CaptureResolutionMessage = .medium

  /// Set when the engine detaches, so a control call that was already in flight cannot rebuild the
  /// session behind teardown's back.
  private var isDetached = false

  /// `recognizer` defaults to the OS-picked backend (modern on iOS 18+, legacy on 15-17), and
  /// `makeSession` to a plain session per open. Tests pass a stub and a counting session instead.
  init(textureRegistry: FlutterTextureRegistry,
       recognizer: any TextRecognizer = TextRecognizerFactory.make(),
       makeSession: @escaping () -> AVCaptureSession = { AVCaptureSession() }) {
    self.textureRegistry = textureRegistry
    self.recognizer = recognizer
    self.makeSession = makeSession
    super.init()
    observeAppLifecycle()
    gate.onFrame = { [weak self] pixelBuffer in await self?.recognize(pixelBuffer) }
  }

  deinit {
    // Insurance for the path where neither dispose nor detach ran and ARC just reclaimed us.
    gate.stop()
    appLifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
  }

  // MARK: Control channel (delegated from TextSightPlugin's TextSightHostApi conformance)

  func initialize(options: TextSightOptionsMessage,
                  resolution: CaptureResolutionMessage) async throws -> Int64 {
    // One lock hold, so a frame never snapshots a half-applied update.
    stateLock.withLock {
      applyLocked(options)
      captureResolution = resolution
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

  /// Synchronous, same as `start`. The session stays up, only the recognition flag drops.
  func pauseRecognition() {
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

  /// Delegated to the backend, so the factory's `#available` stays the only version gate.
  var confidenceScale: ConfidenceScaleMessage { recognizer.confidenceScale }

  func setOptions(options: TextSightOptionsMessage) {
    stateLock.withLock { applyLocked(options) }
  }

  /// Caller holds `stateLock`.
  private func applyLocked(_ options: TextSightOptionsMessage) {
    recognitionLevel = options.level
    usesLanguageCorrection = options.usesLanguageCorrection
    recognitionLanguages = options.languages
    minimumTextHeight = Float(options.minimumTextHeight)
    regionOfInterest = options.roi
  }

  func setTorchEnabled(enabled: Bool) {
    sessionQueue.async { [weak self] in
      guard let self else { return }

      self.torchEnabled = enabled
      self.applyTorch(enabled)
    }
  }

  // MARK: Session lifecycle

  /// Registers the texture and starts the session on a freshly built graph. On `sessionQueue`,
  /// because `startRunning()` must never block main. Internal for `RunnerTests`.
  func configureSession() throws -> Int64 {
    // A control call still in flight when detach landed must not rebuild the session. The other
    // ordering is already safe: a release queued behind us on `sessionQueue` tears this back down.
    let detached = stateLock.withLock { isDetached }
    guard !detached else {
      throw PigeonError(code: "detached",
                        message: "The plugin is not attached to a Flutter engine.", details: nil)
    }

    // Reopening an open session is fine: whatever is there goes first. A hot restart lands here
    // with the camera still up, because Dart lost the texture id and we didn't.
    releaseSession()

    let built = try buildCaptureGraph()

    // iOS 15-16 has no `RotationCoordinator`, so rotation stays untracked there (documented).
    if #available(iOS 17, *) { startTrackingRotation(for: built.device) }

    let id = textureRegistry.register(self)
    // Published only now, so a failed build leaves the camera idle rather than half-open.
    stateLock.withLock {
      activeSession = ActiveSession(session: built.session, device: built.device, textureId: id)
    }

    built.session.startRunning()

    return id
  }

  /// Wires a fresh session to the back camera and hands back both. Runs on `sessionQueue`.
  /// Internal (not `private`) so `RunnerTests` can drive a failed build.
  func buildCaptureGraph() throws -> (session: AVCaptureSession, device: AVCaptureDevice) {
    // Fresh every time, so a throw below drops a half-built session instead of leaving one behind.
    let session = makeSession()
    session.beginConfiguration()
    // Commit on every exit, throws included. A configuration left open wedges the session for the
    // whole process: start/stopRunning then raise an ObjC exception, which Swift cannot catch.
    defer { session.commitConfiguration() }

    session.sessionPreset = Self.preset(for: session,
                                        resolution: stateLock.withLock { captureResolution })

    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    else { throw CameraError.noCaptureDevice }

    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
    session.addInput(input)

    let output = AVCaptureVideoDataOutput()
    output.alwaysDiscardsLateVideoFrames = true
    output.setSampleBufferDelegate(self, queue: captureQueue)
    guard session.canAddOutput(output) else { throw CameraError.cannotAddOutput }
    session.addOutput(output)

    // Set after adding: the list depends on the connected device's active format.
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String:
        Self.pixelFormat(from: output.availableVideoPixelFormatTypes),
    ]

    return (session, device)
  }

  /// `.high` is whatever the device fancies, so it only covers a missing preset.
  /// Internal for tests.
  static func preset(for session: AVCaptureSession,
                     resolution: CaptureResolutionMessage) -> AVCaptureSession.Preset {
    let wanted: AVCaptureSession.Preset = switch resolution {
    case .low: .vga640x480
    case .medium: .hd1920x1080
    case .high: .hd4K3840x2160
    }

    return session.canSetSessionPreset(wanted) ? wanted : .high
  }

  /// Picks the capture pixel format: the camera's own biplanar YUV when offered, else BGRA. YUV
  /// skips AVFoundation's per-frame conversion and costs 1.5 bytes a pixel instead of 4. Vision
  /// reads it fine and Flutter wraps both planes without copying. Video range first, that is what
  /// the sensor hands out. Internal for `RunnerTests`.
  static func pixelFormat(from available: [OSType]) -> OSType {
    let offered = Set(available)
    let preferred: [OSType] = [
      kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
    ]

    return preferred.first(where: offered.contains) ?? kCVPixelFormatType_32BGRA
  }

  /// Tracks device-to-upright rotation with `AVCaptureDevice.RotationCoordinator` (iOS 17+). The
  /// buffer stays unrotated because that is cheaper. The angle goes to Dart as `quarterTurns` and
  /// orients Vision so boxes come out upright. On iOS 15-16 it stays `0`, so nothing rotates.
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

  /// Stops capture while backgrounded and restarts on return. Stopping explicitly hands the camera
  /// back rather than riding the system interruption, and the restart re-asserts the torch.
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
    guard let active = stateLock.withLock({ activeSession }), active.session.isRunning
    else { return }

    active.session.stopRunning()
  }

  /// Runs on `sessionQueue`. Restarts only a configured session, then re-asserts the dropped torch.
  private func resumeSession() {
    guard let active = stateLock.withLock({ activeSession }), !active.session.isRunning
    else { return }

    active.session.startRunning()
    applyTorch(torchEnabled)
  }

  /// Runs on `sessionQueue`.
  private func applyTorch(_ enabled: Bool) {
    guard let device = stateLock.withLock({ activeSession })?.device,
          device.hasTorch, device.isTorchAvailable else { return }

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

    let released = stateLock.withLock {
      isRecognizing = false
      latestPixelBuffer = nil
      let claimed = activeSession
      activeSession = nil

      return claimed
    }

    gate.stop()

    guard let released else { return }

    // Dropping the session takes its inputs and outputs with it, so stopping is the whole teardown.
    if released.session.isRunning { released.session.stopRunning() }
    textureRegistry.unregisterTexture(released.textureId)
  }

  // MARK: Recognition

  /// Publishes the frame for the preview and offers it to the gate. Internal (not `private`) so
  /// `RunnerTests` can drive a frame without an `AVCaptureConnection`.
  func handle(_ pixelBuffer: CVPixelBuffer) {
    let activeTextureId = stateLock.withLock {
      latestPixelBuffer = pixelBuffer
      // Offer under the same lock hold that reads the flag. Teardown clears the flag before it
      // stops the gate, so a frame racing dispose cannot restart the consumer behind it.
      if isRecognizing, eventSink != nil { gate.offer(pixelBuffer) }

      return activeSession?.textureId
    }

    // Keep the preview live every frame. Recognition is paced by the gate.
    activeTextureId.map { textureRegistry.textureFrameAvailable($0) }
  }

  /// Recognizes one frame and emits it. Runs on the gate's consumer, so never concurrently with
  /// itself, and cancelling the gate cancels the Vision call in flight.
  private func recognize(_ pixelBuffer: CVPixelBuffer) async {
    let (config, rotation) = stateLock.withLock {
      (RecognitionConfig(level: recognitionLevel,
                         usesLanguageCorrection: usesLanguageCorrection,
                         languages: recognitionLanguages,
                         minimumTextHeight: minimumTextHeight, roi: regionOfInterest),
       Self.displayRotation(forCaptureAngle: currentRotationAngle))
    }

    // The buffer is sensor-oriented, so report its display-oriented size (axes swap on a quarter
    // turn) to match the boxes Vision returns in the oriented space.
    let bufferWidth = Double(CVPixelBufferGetWidth(pixelBuffer))
    let bufferHeight = Double(CVPixelBufferGetHeight(pixelBuffer))
    let imageWidth = rotation.isQuarterTurned ? bufferHeight : bufferWidth
    let imageHeight = rotation.isQuarterTurned ? bufferWidth : bufferHeight

    // Drop a single failed frame rather than tearing down the session (CODESTYLE: `try?`).
    guard
      let lines = try? await recognizer.recognize(pixelBuffer: pixelBuffer,
                                                  orientation: rotation.orientation,
                                                  config: config),
      !Task.isCancelled
    else { return }

    emit(Self.encodeFrame(lines, imageWidth: imageWidth, imageHeight: imageHeight,
                          quarterTurns: rotation.quarterTurns))
  }

  /// Runs `work` on `sessionQueue`, bridged to `async`. That queue owns `torchEnabled` and the
  /// suspend/resume pair, so callers keep the hop rather than replacing it.
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

  /// Decodes a still from `source` (EXIF orientation honoured) and emits the same per-frame map the
  /// live path does, `quarterTurns` 0 since a still is upright. No session or texture involved.
  private func recognizeStill(_ source: CGImageSource,
                              options: TextSightOptionsMessage) async throws -> [String: Any?] {
    let config = RecognitionConfig(level: options.level,
                                   usesLanguageCorrection: options.usesLanguageCorrection,
                                   languages: options.languages,
                                   minimumTextHeight: Float(options.minimumTextHeight),
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

  /// Encodes neutral lines into the self-describing per-frame map, byte-identical to what Android
  /// emits. Internal for `RunnerTests`.
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

  /// Maps the coordinator's clockwise-to-upright `angle` to preview quarter-turns, the Vision
  /// orientation for the unrotated buffer, and whether the axes swap. If the preview comes out
  /// rotated wrong on a device, this mapping is the knob. Internal for `RunnerTests`.
  static func displayRotation(forCaptureAngle angle: CGFloat)
    -> (quarterTurns: Int, orientation: CGImagePropertyOrientation, isQuarterTurned: Bool) {
    switch (Int(angle.rounded()) % 360 + 360) % 360 {
    // Back camera: 90° clockwise-to-upright (portrait) is EXIF `.right`, 270° is `.left`. Swap them
    // and Vision gets a 180°-rotated image, wrecking portrait while landscape still looks fine.
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
