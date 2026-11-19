import 'dart:async';

import 'package:flutter/foundation.dart';

import '../options/capture_resolution.dart';
import '../options/darwin_options.dart';
import '../options/text_sight_options.dart';
import '../platform/text_sight_platform.dart';
import '../recognition/normalized_roi.dart';
import '../results/text_sight_capture.dart';
import '../states/camera_permission_status.dart';
import '../states/preview_geometry.dart';
import '../states/text_sight_session_state.dart';

/// Runs a live camera session that reads text.
///
/// A [ChangeNotifier], so a `TextSightView` or any listener rebuilds when its state changes.
/// Results arrive on [captures].
final class TextSightController({
  TextSightOptions options = const TextSightOptions(),

  /// Fixed for this controller's life, since changing it means rebuilding the camera session.
  final CaptureResolution resolution = CaptureResolution.medium,
  bool torchEnabled = false,
}) extends ChangeNotifier {
  TextSightOptions _options = options._stable();
  var _isTorchEnabled = torchEnabled;
  var _isRecognizing = false;
  int? _textureId;
  TextSightSessionState _sessionState = const SessionIdle();
  StreamSubscription<TextSightSessionState>? _stateSubscription;
  PreviewGeometry? _preview;
  StreamSubscription<PreviewGeometry>? _previewSubscription;

  /// Nothing opens the camera until [start].
  this
    : assert(
        options.roi.isNormalizedRoi,
        'Region-of-interest must be a normalized [0,1] rect with positive extent.',
      );

  /// The recognizer settings in force. Change them with [updateOptions].
  TextSightOptions get options => _options;

  /// Whether the torch is currently requested on.
  bool get isTorchEnabled => _isTorchEnabled;

  /// Whether reading is switched on. Only [start] and [pauseRecognition] flip it, so it says what
  /// you asked for, not what the camera is doing.
  bool get isRecognizing => _isRecognizing;

  /// The preview texture id, or `null` before [start] has acquired one.
  @Deprecated('Use TextSightView, which shows the texture the right way up.')
  int? get textureId => _textureId;

  /// How to show the open texture, or `null` until native has said. Only `TextSightView` reads it.
  @internal
  PreviewGeometry? get preview =>
      // Matched on read, since geometry can land before `initialize` hands back the id.
      _preview?.textureId == _textureId ? _preview : null;

  /// The capture session's state as native last reported it: [SessionIdle] until [start] and
  /// again after [dispose]. Listeners are notified on change only.
  TextSightSessionState get sessionState => _sessionState;

  /// Results, one per read frame. Frames are only read while this has a listener. Cancel your own
  /// subscription, the controller doesn't own it.
  Stream<TextSightCapture> get captures => TextSightPlatform.instance.captures;

  /// Opens the camera if needed and starts reading. Reuses the open session after
  /// [pauseRecognition], and is also the way back from [SessionFailed].
  Future<void> start() async {
    // Before initialize, so nothing native reports for this session is missed.
    _stateSubscription ??= TextSightPlatform.instance.sessionStates.listen(_onSessionState);
    _previewSubscription ??= TextSightPlatform.instance.previews.listen(_onPreview);
    _textureId ??= await TextSightPlatform.instance.initialize(_options, resolution);
    await TextSightPlatform.instance.start();
    _isRecognizing = true;
    notifyListeners();
  }

  /// Stops reading but keeps the camera and its preview running. [start] resumes it.
  Future<void> pauseRecognition() async {
    await TextSightPlatform.instance.pauseRecognition();
    _isRecognizing = false;
    notifyListeners();
  }

  /// The camera permission, without asking the user.
  ///
  /// Use it to decide whether to explain why you need the camera before [requestCameraPermission].
  Future<CameraPermissionStatus> checkCameraPermission() =>
      TextSightPlatform.instance.checkCameraPermission();

  /// Asks for camera permission if the user hasn't decided yet.
  ///
  /// Call it before [start], which never asks by itself. iOS also needs `NSCameraUsageDescription`
  /// in your Info.plist, or it kills the app on first camera use. Android's manifest entry comes
  /// with the plugin.
  Future<CameraPermissionStatus> requestCameraPermission() =>
      TextSightPlatform.instance.requestCameraPermission();

  /// Replaces the recognizer settings on the open session.
  ///
  /// Every setting goes at once, so read [options] first when you only mean to change one.
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

  /// Turns the torch on or off. Does nothing on devices without one.
  Future<void> updateTorchEnabled({required bool enabled}) async {
    await TextSightPlatform.instance.updateTorchEnabled(enabled: enabled);
    _isTorchEnabled = enabled;
    notifyListeners();
  }

  /// Closes the camera along with the controller, even if [start] never ran.
  @override
  void dispose() {
    _stateSubscription?.cancel().ignore();
    _previewSubscription?.cancel().ignore();
    _sessionState = const SessionIdle();
    // Always, since a hot restart can leave native holding a session this controller never saw. A
    // spare call is harmless.
    unawaited(TextSightPlatform.instance.dispose());

    super.dispose();
  }

  /// The only place repeats are dropped, since native reports every change.
  void _onSessionState(TextSightSessionState state) {
    if (state == _sessionState) return;
    _sessionState = state;
    notifyListeners();
  }

  void _onPreview(PreviewGeometry preview) {
    assert(!preview.size.isEmpty, 'Native sends real buffer sizes, so an empty one is its bug.');
    if (preview == _preview) return;
    _preview = preview;
    notifyListeners();
  }
}

/// A fixed copy, since the caller's language list can be lazy or change later. Repeats mean
/// nothing in a preference order, so they go. The `const` constructor can't do this itself.
extension on TextSightOptions {
  TextSightOptions _stable() => TextSightOptions(
    roi: roi,
    darwin: darwin.copyWith(
      preferredLanguages: darwin.preferredLanguages.toSet().toList(growable: false),
    ),
  );
}
