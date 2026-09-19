import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform/text_sight_platform.dart';
import '../recognition/darwin_options.dart';
import '../recognition/normalized_roi.dart';
import '../recognition/text_sight_capture.dart';
import '../recognition/text_sight_options.dart';
import 'camera_permission_status.dart';
import 'capture_resolution.dart';
import 'text_sight_session_state.dart';

/// Configures and drives a live camera recognition session.
///
/// A [ChangeNotifier], so a `TextSightView` or any other listener rebuilds off it. Per-frame
/// results are not part of that, they arrive on [captures].
final class TextSightController({
  TextSightOptions options = const TextSightOptions(),

  /// Fixed for this controller's life.
  final CaptureResolution resolution = CaptureResolution.medium,
  bool torchEnabled = false,
}) extends ChangeNotifier {
  TextSightOptions _options = options._stable();
  var _isTorchEnabled = torchEnabled;
  var _isRecognizing = false;
  int? _textureId;
  TextSightSessionState _sessionState = const SessionIdle();
  StreamSubscription<TextSightSessionState>? _stateSubscription;

  /// Nothing opens the camera until [start]. [resolution] can't change afterwards, that would mean
  /// rebuilding the capture graph.
  this
    : assert(
        options.roi.isNormalizedRoi,
        'Region-of-interest must be a normalized [0,1] rect with positive extent.',
      );

  /// The recognizer settings in force. Change them with [updateOptions].
  TextSightOptions get options => _options;

  /// Whether the torch is asked to be on.
  bool get isTorchEnabled => _isTorchEnabled;

  /// What you asked for, not what the camera is doing. Only [start] and [pauseRecognition] move it.
  bool get isRecognizing => _isRecognizing;

  /// The preview texture id, or `null` until [start] gets one.
  int? get textureId => _textureId;

  /// What native last reported. [SessionIdle] until [start], and again after [dispose].
  TextSightSessionState get sessionState => _sessionState;

  /// One event per recognized frame. Nothing gets recognized while nobody listens, and cancelling
  /// is yours to do.
  Stream<TextSightCapture> get captures => TextSightPlatform.instance.captures;

  /// Opens the camera if it isn't already and starts recognizing. Reuses the session across a
  /// [pauseRecognition], and it's also the way back from [SessionFailed].
  Future<void> start() async {
    // Before initialize, so the first state of this session is never missed.
    _stateSubscription ??= TextSightPlatform.instance.sessionStates.listen(_onSessionState);
    _textureId ??= await TextSightPlatform.instance.initialize(_options, resolution);
    await TextSightPlatform.instance.start();
    _isRecognizing = true;
    notifyListeners();
  }

  /// Stops recognizing but keeps the session and texture alive. [start] picks it up again.
  Future<void> pauseRecognition() async {
    await TextSightPlatform.instance.pauseRecognition();
    _isRecognizing = false;
    notifyListeners();
  }

  /// Reads the permission status without prompting, so you can show a rationale screen before
  /// [requestCameraPermission].
  Future<CameraPermissionStatus> checkCameraPermission() =>
      TextSightPlatform.instance.checkCameraPermission();

  /// Prompts when the user hasn't decided yet. Call it before [start], which never asks by itself.
  ///
  /// You still have to declare `NSCameraUsageDescription` or iOS kills the app the first time it
  /// touches the camera. The Android manifest entry ships with the plugin.
  Future<CameraPermissionStatus> requestCameraPermission() =>
      TextSightPlatform.instance.requestCameraPermission();

  /// Replaces every setting at once, so start from [options] when you only mean to change one.
  Future<void> updateOptions(TextSightOptions settings) async {
    assert(
      settings.roi.isNormalizedRoi,
      'Region-of-interest must be a normalized [0,1] rect with positive extent.',
    );
    final stable = settings._stable();
    await TextSightPlatform.instance.updateOptions(stable);
    _options = stable;
    notifyListeners();
  }

  /// Asks for the torch on or off. No-op on a device without one.
  Future<void> updateTorchEnabled({required bool enabled}) async {
    await TextSightPlatform.instance.updateTorchEnabled(enabled: enabled);
    _isTorchEnabled = enabled;
    notifyListeners();
  }

  /// Takes the native session down with the controller. Safe even if [start] never succeeded.
  @override
  void dispose() {
    _stateSubscription?.cancel().ignore();
    _sessionState = const SessionIdle();
    // Unconditional: a hot restart leaves native holding a session this controller never saw.
    unawaited(TextSightPlatform.instance.dispose());

    super.dispose();
  }

  /// The only dedupe in the system. Native reports every transition, equal ones stop here.
  void _onSessionState(TextSightSessionState state) {
    if (state == _sessionState) return;
    _sessionState = state;
    notifyListeners();
  }
}

/// `preferredLanguages` can arrive lazy or growable and gets read more than once, and a repeat means
/// nothing in a preference order. A `const` constructor can't do any of that itself.
extension on TextSightOptions {
  TextSightOptions _stable() => TextSightOptions(
    roi: roi,
    darwin: darwin.copyWith(
      preferredLanguages: darwin.preferredLanguages.toSet().toList(growable: false),
    ),
  );
}
