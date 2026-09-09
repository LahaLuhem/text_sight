import 'dart:async';
import 'dart:io' show Directory, InternetAddress, Platform, Socket;
import 'dart:typed_data' show ByteData, Uint8List;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
// The example doubles as the plugin's own harness, and the federation seam is not on the barrel.
// ignore: implementation_imports
import 'package:text_sight/src/platform/text_sight_platform.dart';
import 'package:text_sight/text_sight.dart';

import 'constants/assets/assets.gen.dart';

/// One frame standing in for the camera, and whether it came from the Mac's webcam or the bundled
/// sample. The two always move together, so they share one notifier.
typedef SimulatedFrame = ({Uint8List jpeg, bool isBridged});

/// Stands in for the camera on the iOS Simulator, which has no capture hardware.
///
/// Frames come from the Mac's webcam over a localhost bridge when one is running, and from the
/// bundled sample image otherwise. Either way recognition is real: every frame goes through the
/// wrapped platform's one-shot path, so the lines and boxes the overlay draws are genuine
/// recognizer output. Only the session is fake, and the events that need hardware come from the app
/// lifecycle and from [simulateInterruption] / [simulateFailure].
final class FakeCameraPlatform extends TextSightPlatform {
  /// How long a simulated interruption holds before the camera comes back on its own, as a real
  /// one does. Long enough to read the paused screen, short enough that nothing feels stuck.
  static const _interruptionHold = Duration(seconds: 6);

  /// Paces the bundled-sample fallback. Bridged frames arrive at the webcam's own rate instead.
  static const _sampleInterval = Duration(milliseconds: 200);

  /// Nothing registers a texture here, so any id will do. `TextSightView` only needs a non-null one.
  static const _textureId = 0;

  static FakeCameraPlatform? _installed;

  final TextSightPlatform _real;
  final _captures = StreamController<TextSightCapture>.broadcast();
  final _sessionStates = StreamController<TextSightSessionState>.broadcast();
  final _frameNotifier = ValueNotifier<SimulatedFrame?>(null);

  late final _bridge = _BridgeClient(onFrame: _onBridgeFrame, onLost: _onBridgeLost);

  Timer? _sampleTimer;
  Timer? _recoveryTimer;
  Uint8List? _sampleBytes;
  TextSightCapture? _sampleCapture;
  var _options = const TextSightOptions();
  var _isOpen = false;
  var _isStreaming = false;
  var _isBridged = false;
  var _hasFailed = false;
  var _isRecognizing = false;

  new(this._real) {
    // Native drops the session when the app backgrounds, so mirror it. The binding owns the
    // listener once constructed, so it needs no field.
    AppLifecycleListener(onHide: _reportBackgrounded, onShow: _reportForegrounded);
  }

  /// The installed stand-in, or `null` when the app is driving a real camera.
  static FakeCameraPlatform? get installed => _installed;

  /// Takes over the platform seam on the iOS Simulator, keeping the real implementation for the
  /// one-shot and model paths, which need no camera. A no-op anywhere else, so a device or an
  /// Android emulator still exercises the plugin end to end.
  static void installWhenSimulated() {
    if (!_isSimulated) return;

    final fake = FakeCameraPlatform(TextSightPlatform.instance);
    TextSightPlatform.instance = fake;
    _installed = fake;
  }

  /// The Simulator runs out of a `CoreSimulator` container, which a real device never does.
  /// `Platform.environment` is empty on iOS, so the sandbox path is the signal that is there.
  static bool get _isSimulated =>
      Platform.isIOS && Directory.systemTemp.path.contains('/CoreSimulator/Devices/');

  /// The frame the overlay's boxes belong to, so the preview and the boxes can never disagree.
  ValueListenable<SimulatedFrame?> get frameListenable => _frameNotifier;

  @override
  Future<int> initialize(TextSightOptions options, CaptureResolution resolution) async {
    _options = options;
    await _loadSample();
    _isOpen = true;
    _bridge.start();

    return _textureId;
  }

  /// Also the way back from a simulated failure, matching the native rule that only a start unparks.
  @override
  Future<void> start() async {
    _hasFailed = false;
    _recoveryTimer?.cancel();
    _isStreaming = true;
    _report(const SessionActive());
    _startSampleReplay();
  }

  @override
  Future<void> pauseRecognition() async => _stopStreaming();

  @override
  Future<void> dispose() async {
    _isOpen = false;
    _stopStreaming();
    _recoveryTimer?.cancel();
    _bridge.close();
    _report(const SessionIdle());
  }

  @override
  Future<CameraPermissionStatus> checkCameraPermission() async => .granted;

  @override
  Future<CameraPermissionStatus> requestCameraPermission() async => .granted;

  @override
  Future<void> updateOptions(TextSightOptions options) async {
    _options = options;
    _sampleCapture = null;
    await _loadSample();
  }

  /// The Simulator has no torch, so the view model's own toggle state is the whole effect.
  @override
  Future<void> updateTorchEnabled({required bool enabled}) => Future.value();

  @override
  Stream<TextSightCapture> get captures => _captures.stream;

  @override
  Stream<TextSightSessionState> get sessionStates => _sessionStates.stream;

  // Everything below needs no camera, so it goes to the real implementation untouched.

  @override
  Future<ConfidenceScale> get confidenceScale => _real.confidenceScale;

  @override
  Future<TextSightReadinessState> ensureModelReady() => _real.ensureModelReady();

  @override
  Stream<TextSightReadinessState> get modelReadiness => _real.modelReadiness;

  @override
  Future<TextSightCapture> recognizeImage(Uint8List bytes, TextSightOptions options) =>
      _real.recognizeImage(bytes, options);

  @override
  Future<TextSightCapture> recognizePath(String path, TextSightOptions options) =>
      _real.recognizePath(path, options);

  /// Stands in for the OS taking the camera and handing it back, which needs real hardware to see.
  void simulateInterruption() {
    _stopStreaming();
    _report(const SessionPaused(reason: .interrupted, details: 'Simulated interruption'));
    _recoveryTimer = Timer(_interruptionHold, () {
      _isStreaming = true;
      _report(const SessionActive());
      _startSampleReplay();
    });
  }

  /// Stands in for a capture runtime error, which parks the session until the next start.
  void simulateFailure() {
    _stopStreaming();
    _recoveryTimer?.cancel();
    _hasFailed = true;
    _report(const SessionFailed(details: 'Simulated capture failure'));
  }

  /// The sample is recognized once and its capture replayed, since a still cannot change between
  /// ticks. Bridged frames are recognized one by one instead.
  Future<void> _loadSample() async {
    final bytes = _sampleBytes ??= (await rootBundle.load(ConstMedia.sampleText.keyName)).buffer
        .asUint8List();
    _sampleCapture ??= await _real.recognizeImage(bytes, _options);
  }

  void _onBridgeFrame(Uint8List jpeg) {
    _isBridged = true;
    _stopSampleReplay();
    _frameNotifier.value = (jpeg: jpeg, isBridged: true);
    if (_isStreaming) unawaited(_recognize(jpeg));
  }

  void _onBridgeLost() {
    _isBridged = false;
    _startSampleReplay();
  }

  /// Newest frame wins: one arriving while a recognition is in flight is skipped, which is how the
  /// native frame gate paces the recognizer.
  Future<void> _recognize(Uint8List jpeg) async {
    if (_isRecognizing) return;

    _isRecognizing = true;
    try {
      _captures.add(await _real.recognizeImage(jpeg, _options));
    } on Object {
      // A frame the recognizer rejects is dropped, exactly as native drops a bad frame.
    } finally {
      _isRecognizing = false;
    }
  }

  void _startSampleReplay() {
    if (!_isStreaming || _isBridged) return;

    _sampleTimer ??= Timer.periodic(_sampleInterval, (_) => _replaySample());
  }

  void _stopSampleReplay() {
    _sampleTimer?.cancel();
    _sampleTimer = null;
  }

  void _replaySample() {
    final bytes = _sampleBytes;
    final capture = _sampleCapture;
    if (bytes == null || capture == null) return;

    _frameNotifier.value = (jpeg: bytes, isBridged: false);
    _captures.add(capture);
  }

  void _stopStreaming() {
    _isStreaming = false;
    _stopSampleReplay();
  }

  void _reportBackgrounded() {
    if (!_isOpen) return;

    _stopStreaming();
    _report(const SessionPaused(reason: .appBackgrounded));
  }

  void _reportForegrounded() {
    if (!_isOpen || _hasFailed) return;

    _isStreaming = true;
    _report(const SessionActive());
    _startSampleReplay();
  }

  void _report(TextSightSessionState state) => _sessionStates.add(state);
}

/// Reads a webcam bridge on the host Mac: per frame a 4-byte big-endian length, then that many
/// bytes of JPEG. The Simulator shares the Mac's loopback, so `127.0.0.1` reaches it.
///
/// Retries quietly and forever, so starting the bridge after the app is fine, and so is never
/// starting it at all.
final class _BridgeClient {
  /// CamBridge's default. Any server speaking the same framing works.
  static const _port = 8765;
  static const _headerBytes = 4;
  static const _retryDelay = Duration(seconds: 2);
  static const _connectTimeout = Duration(seconds: 2);

  /// A length past this means the stream is out of sync, so drop the connection rather than try to
  /// allocate it.
  static const _maxFrameBytes = 8 * 1024 * 1024;

  final void Function(Uint8List jpeg) onFrame;
  final void Function() onLost;

  Socket? _socket;
  Timer? _retry;
  var _pending = Uint8List(0);
  var _isStarted = false;

  new({required this.onFrame, required this.onLost});

  void start() {
    if (_isStarted) return;

    _isStarted = true;
    unawaited(_connect());
  }

  void close() {
    _isStarted = false;
    _retry?.cancel();
    _retry = null;
    _socket?.destroy();
    _socket = null;
  }

  Future<void> _connect() async {
    if (!_isStarted) return;

    try {
      // Torn down by destroy() in close() and _reconnect(), which the lint cannot see here.
      // ignore: close_sinks
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        _port,
        timeout: _connectTimeout,
      );
      _socket = socket;
      _pending = Uint8List(0);
      socket.listen(
        _onData,
        onError: (Object _) => _reconnect(),
        onDone: _reconnect,
        cancelOnError: true,
      );
    } on Object {
      _reconnect();
    }
  }

  void _reconnect() {
    if (!_isStarted) return;

    _socket?.destroy();
    _socket = null;
    onLost();
    _retry?.cancel();
    _retry = Timer(_retryDelay, () => unawaited(_connect()));
  }

  void _onData(Uint8List chunk) {
    _pending = _pending.isEmpty
        ? chunk
        : (Uint8List(_pending.length + chunk.length)
            ..setAll(0, _pending)
            ..setAll(_pending.length, chunk));

    while (_pending.length >= _headerBytes) {
      final length = ByteData.sublistView(_pending, 0, _headerBytes).getUint32(0);
      if (length > _maxFrameBytes) {
        _reconnect();

        return;
      }

      final end = _headerBytes + length;
      if (_pending.length < end) return;

      onFrame(_pending.sublist(_headerBytes, end));
      _pending = Uint8List.sublistView(_pending, end);
    }
  }
}
