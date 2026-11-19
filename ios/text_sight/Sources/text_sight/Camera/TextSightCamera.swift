import AsyncQueue
import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Flutter
import ImageIO
import UIKit

/// The live driver: owns the `AVCaptureSession` and the preview texture for one session.
///
/// Reading runs off main and hops back to reach the captures sink. The `FrameGate` and
/// `alwaysDiscardsLateVideoFrames` drop a late frame rather than queue it.
final class TextSightCamera: NSObject {
  /// One open session, its camera and its preview texture, built and dropped together.
  private struct ActiveSession {
    let session: AVCaptureSession
    let device: AVCaptureDevice
    let textureId: Int64
  }

  private let textureRegistry: FlutterTextureRegistry
  private let makeSession: () -> AVCaptureSession
  private let sessionQueue = DispatchQueue(label: "com.lahaluhem.text_sight.session")
  private let captureQueue = DispatchQueue(label: "com.lahaluhem.text_sight.capture")

  /// Shared with the one-shot.
  private let recognizer: any TextRecognizer

  /// Guards every field two threads touch. The gate does its own locking.
  private let stateLock = NSLock()

  /// Internal so `RunnerTests` can see whether a frame got through.
  let gate = FrameGate()

  private var eventSink: FlutterEventSink?
  private var latestPixelBuffer: CVPixelBuffer?

  /// The open session, or `nil` when idle. Only `sessionQueue` ever writes it.
  private var activeSession: ActiveSession?

  /// What was asked for, applied again on every start, since the torch goes off with the camera.
  /// Only touched on `sessionQueue`.
  private var torchEnabled = false

  // What `syncSession()` decides from, only touched on `sessionQueue`. `isForeground` starts true
  // since the plugin registers while the app is in front, and the notifications correct it.
  private var wantsSession = false
  private var isForeground = true
  private var hasFailed = false

  /// Where session transitions go, on main: production forwards to the FlutterApi, tests record.
  private let onSessionState: @MainActor (SessionStateMessage) async -> Void

  /// Where preview geometry goes, on main. Production forwards to the FlutterApi.
  private let onPreview: @MainActor (PreviewMessage) async -> Void

  private var notificationObservers: [NSObjectProtocol] = []
  // Type-erased: the concrete `AVCaptureDevice.RotationCoordinator` is iOS 17+, but this class
  // deploys to 15. Held only to keep the coordinator alive for its KVO, and stays nil on iOS 15-16.
  private var rotationCoordinator: Any?
  private var rotationObservation: NSKeyValueObservation?

  /// Clockwise degrees to turn the sensor buffer upright. Stays `0` on iOS 15-16, which have no
  /// rotation coordinator, so nothing turns there.
  private var currentRotationAngle: CGFloat = 0

  /// The last frame's buffer size, so a frame only rebuilds the preview geometry when it changes.
  private var previewBufferSize: CGSize?

  /// The last geometry pushed, so an unchanged one isn't pushed again.
  private var preview: PreviewMessage?

  // No lock, since only the gate's consumer touches it, one frame at a time.
  private var shownLines = ShownLines()

  // Recognizer settings, copied into a `RecognitionConfig` for each frame.
  private var recognitionLevel: RecognitionLevelMessage = .fast
  private var usesLanguageCorrection = true
  private var recognitionLanguages: [String] = []
  private var minimumTextHeight: Float = 0
  private var regionOfInterest: RegionOfInterestMessage?

  private var isRecognizing = false

  /// Written at initialize, read on the session queue when the graph builds, so it takes the lock.
  private var captureResolution: CaptureResolutionMessage = .medium

  /// Set when the engine detaches, so neither a control call already in flight nor a queued push
  /// outlives teardown.
  private var isDetached = false

  /// Tests swap in a stub recognizer, a counting session and a recorder.
  init(textureRegistry: FlutterTextureRegistry,
       recognizer: any TextRecognizer = TextRecognizerFactory.make(),
       makeSession: @escaping () -> AVCaptureSession = { AVCaptureSession() },
       onSessionState: @escaping @MainActor (SessionStateMessage) async -> Void = { _ in },
       onPreview: @escaping @MainActor (PreviewMessage) async -> Void = { _ in }) {
    self.textureRegistry = textureRegistry
    self.recognizer = recognizer
    self.makeSession = makeSession
    self.onSessionState = onSessionState
    self.onPreview = onPreview
    super.init()
    observeNotifications()
    gate.onFrame = { [weak self] pixelBuffer in await self?.recognize(pixelBuffer) }
  }

  deinit {
    // For when neither dispose nor detach ran before ARC reclaimed us.
    gate.stop()
    notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
  }

  // MARK: Control channel, called from TextSightPlugin

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

  /// Turns reading on, then makes sure the session runs. Also how a session that a runtime error
  /// stopped comes back.
  func start() {
    stateLock.withLock { isRecognizing = true }
    sessionQueue.async { [weak self] in
      guard let self else { return }

      self.hasFailed = false
      self.syncSession()
    }
  }

  /// The session stays up, only reading stops.
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

  /// Comes from the backend, so the iOS 18 check lives only in the factory.
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

  /// Runs on `sessionQueue`, since `startRunning()` must never block main. Internal for
  /// `RunnerTests`.
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

    // iOS 15-16 has no `RotationCoordinator`, so rotation stays untracked there.
    if #available(iOS 17, *) { startTrackingRotation(for: built.device) }

    let id = textureRegistry.register(self)
    // Published only now, so a failed build leaves the camera idle rather than half-open.
    stateLock.withLock {
      activeSession = ActiveSession(session: built.session, device: built.device, textureId: id)
    }

    wantsSession = true
    syncSession()

    return id
  }

  /// Runs on `sessionQueue`. Internal so `RunnerTests` can drive a failed build.
  func buildCaptureGraph() throws -> (session: AVCaptureSession, device: AVCaptureDevice) {
    // Fresh every time, so a throw below drops a half-built session instead of leaving one behind.
    let session = makeSession()
    session.beginConfiguration()
    // Commit on every exit, throws included. A configuration left open wedges the session for the
    // whole process: start/stopRunning then raise an ObjC exception, which Swift cannot catch.
    defer { session.commitConfiguration() }

    let resolution = stateLock.withLock { captureResolution }
    session.sessionPreset = CaptureFormat.preset(for: session, resolution: resolution)

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
        CaptureFormat.pixelFormat(from: output.availableVideoPixelFormatTypes),
    ]

    return (session, device)
  }

  /// The buffer stays unturned because that's cheaper. The angle goes to Dart as `quarterTurns`,
  /// and tells Vision which way is up.
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
    stateLock.withLock {
      currentRotationAngle = angle
      refreshPreviewLocked()
    }
  }

  /// Caller holds `stateLock`, so geometry is pushed in the order it changes.
  private func refreshPreviewLocked() {
    guard let textureId = activeSession?.textureId, let size = previewBufferSize else { return }

    // The texture is the raw buffer, so it takes the same turns Vision's orientation does.
    let rotation = PreviewGeometry.displayRotation(forCaptureAngle: currentRotationAngle)
    let next = PreviewMessage(textureId: textureId,
                              width: Int64(rotation.isQuarterTurned ? size.height : size.width),
                              height: Int64(rotation.isQuarterTurned ? size.width : size.height),
                              quarterTurns: Int64(rotation.quarterTurns))
    guard next != preview else { return }

    preview = next
    push { [onPreview] in await onPreview(next) }
  }

  /// Stopping on background ourselves hands the camera back, instead of waiting on the system's
  /// interruption. Session notifications use `object: nil`, so a rebuilt session needs no new
  /// observers, and each handler filters them.
  private func observeNotifications() {
    let center = NotificationCenter.default
    notificationObservers = [
      center.addObserver(
        forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
      ) { [weak self] _ in self?.setForeground(false) },
      center.addObserver(
        forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil
      ) { [weak self] _ in self?.setForeground(true) },
      center.addObserver(
        forName: AVCaptureSession.wasInterruptedNotification, object: nil, queue: nil
      ) { [weak self] note in self?.onSessionQueue { $0.sessionWasInterrupted(note) } },
      center.addObserver(
        forName: AVCaptureSession.interruptionEndedNotification, object: nil, queue: nil
      ) { [weak self] note in self?.onSessionQueue { $0.sessionInterruptionEnded(note) } },
      center.addObserver(
        forName: AVCaptureSession.runtimeErrorNotification, object: nil, queue: nil
      ) { [weak self] note in self?.onSessionQueue { $0.sessionRuntimeError(note) } },
    ]
  }

  private func setForeground(_ isForeground: Bool) {
    onSessionQueue { camera in
      camera.isForeground = isForeground
      camera.syncSession()
    }
  }

  /// Fire-and-forget twin of the throwing `onSessionQueue`, weak so a torn-down camera skips it.
  private func onSessionQueue(_ work: @escaping (TextSightCamera) -> Void) {
    sessionQueue.async { [weak self] in
      guard let self else { return }

      work(self)
    }
  }

  /// Runs on `sessionQueue`. The notification observers use `object: nil`, so a session the host
  /// app owns has to be dropped here.
  private func activeSession(matching object: Any?) -> ActiveSession? {
    guard let active = stateLock.withLock({ activeSession }), object as AnyObject === active.session
    else { return nil }

    return active
  }

  /// Runs on `sessionQueue`.
  private func sessionWasInterrupted(_ note: Notification) {
    guard activeSession(matching: note.object) != nil else { return }

    let reason = (note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int)
      .flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
    emitState(SessionStateDerivation.state(forInterruption: reason))
  }

  /// Runs on `sessionQueue`. AVFoundation resumes the session itself, so only confirm that it did.
  private func sessionInterruptionEnded(_ note: Notification) {
    guard let active = activeSession(matching: note.object), active.session.isRunning
    else { return }

    emitState(SessionActiveMessage())
  }

  /// Runs on `sessionQueue`. Parks the session: only `start()` tries again.
  private func sessionRuntimeError(_ note: Notification) {
    guard activeSession(matching: note.object) != nil else { return }

    hasFailed = true
    let error = note.userInfo?[AVCaptureSessionErrorKey] as? Error
    emitState(SessionStateDerivation.state(forRuntimeError: error))
  }

  /// Runs on `sessionQueue`. Internal for `RunnerTests`.
  func emitState(_ state: SessionStateMessage) {
    push { [onSessionState] in await onSessionState(state) }
  }

  /// Pushes start on main in the order they're made. One that would start after detach is dropped,
  /// since the messenger is gone.
  private func push(_ send: @escaping @MainActor () async -> Void) {
    Task(on: MainActor.queue) { [weak self] in
      guard let self, !self.stateLock.withLock({ self.isDetached }) else { return }

      await send()
    }
  }

  /// Runs on `sessionQueue`. Starts or stops the open session to match `shouldRun`, so every input
  /// change funnels through here.
  private func syncSession() {
    guard let active = stateLock.withLock({ activeSession }) else { return }

    let shouldRun = SessionStateDerivation.shouldRun(wantsSession: wantsSession,
                                                     isForeground: isForeground,
                                                     hasFailed: hasFailed)
    if shouldRun, !active.session.isRunning {
      active.session.startRunning()
      applyTorch(torchEnabled)
      // A start that fails posts a runtime error instead, so report only what actually happened.
      if active.session.isRunning { emitState(SessionActiveMessage()) }
    } else if !shouldRun, active.session.isRunning {
      active.session.stopRunning()
      if !isForeground { emitState(SessionPausedMessage(reason: .appBackgrounded)) }
    }
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

  /// Safe to call twice, so dispose and detach can both reach it.
  private func releaseSession() {
    rotationObservation?.invalidate()
    rotationObservation = nil
    rotationCoordinator = nil

    let released = stateLock.withLock {
      isRecognizing = false
      latestPixelBuffer = nil
      previewBufferSize = nil
      preview = nil
      let claimed = activeSession
      activeSession = nil

      return claimed
    }
    wantsSession = false
    hasFailed = false

    gate.stop()

    guard let released else { return }

    // Dropping the session takes its inputs and outputs with it, so stopping is the whole teardown.
    if released.session.isRunning { released.session.stopRunning() }
    textureRegistry.unregisterTexture(released.textureId)
    emitState(SessionIdleMessage())
  }

  // MARK: Recognition

  /// Internal so `RunnerTests` can drive a frame without an `AVCaptureConnection`.
  func handle(_ pixelBuffer: CVPixelBuffer) {
    let bufferSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                            height: CVPixelBufferGetHeight(pixelBuffer))
    let activeTextureId = stateLock.withLock {
      latestPixelBuffer = pixelBuffer
      // Offer under the same lock hold that reads the flag. Teardown clears the flag before it
      // stops the gate, so a frame racing dispose cannot restart the consumer behind it.
      if isRecognizing, eventSink != nil { gate.offer(pixelBuffer) }

      if bufferSize != previewBufferSize {
        previewBufferSize = bufferSize
        refreshPreviewLocked()
      }

      return activeSession?.textureId
    }

    // Keep the preview live every frame. Recognition is paced by the gate.
    activeTextureId.map { textureRegistry.textureFrameAvailable($0) }
  }

  /// Runs on the gate's consumer, so never twice at once, and stopping the gate cancels the Vision
  /// call in flight.
  private func recognize(_ pixelBuffer: CVPixelBuffer) async {
    let (config, rotation) = stateLock.withLock {
      (RecognitionConfig(level: recognitionLevel,
                         usesLanguageCorrection: usesLanguageCorrection,
                         languages: recognitionLanguages,
                         minimumTextHeight: minimumTextHeight, roi: regionOfInterest),
       PreviewGeometry.displayRotation(forCaptureAngle: currentRotationAngle))
    }

    // Report the size the boxes are in, so width and height swap on a quarter turn.
    let bufferWidth = Double(CVPixelBufferGetWidth(pixelBuffer))
    let bufferHeight = Double(CVPixelBufferGetHeight(pixelBuffer))
    let imageWidth = rotation.isQuarterTurned ? bufferHeight : bufferWidth
    let imageHeight = rotation.isQuarterTurned ? bufferWidth : bufferHeight

    // One failed frame isn't worth closing the session over, so drop it.
    guard
      let lines = try? await recognizer.recognize(pixelBuffer: pixelBuffer,
                                                  orientation: rotation.orientation,
                                                  config: config),
      !Task.isCancelled
    else { return }

    let kept = shownLines.keep(lines, in: config.region, roi: config.roi)
    emit(FrameEncoding.encodeFrame(kept, imageWidth: imageWidth, imageHeight: imageHeight,
                                   quarterTurns: rotation.quarterTurns))
  }

  /// Runs `work` on `sessionQueue` and awaits it. That queue owns the session's flags, so keep the
  /// hop.
  private func onSessionQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
      sessionQueue.async { continuation.resume(with: Result(catching: work)) }
    }
  }

  /// On main, the only thread a sink takes calls on. The sink is read under the lock, since
  /// `onCancel` can clear it.
  private func emit(_ frame: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      let sink = self.stateLock.withLock { self.eventSink }

      sink?(frame)
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
