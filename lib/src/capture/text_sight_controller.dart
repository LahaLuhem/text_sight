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
/// The Dart face of the live-camera driver. A [ChangeNotifier] exposing the current configuration
/// and session state through individual getters (no bundled state object) that a `TextSightView`
/// (or any listener) rebuilds from. Per-frame results arrive on [captures]. The preview renders the
/// [textureId]. Every call delegates to [TextSightPlatform.instance], so the controller carries
/// no platform knowledge of its own.
final class TextSightController extends ChangeNotifier {
  TextSightOptions _options;
  bool _isTorchEnabled;
  var _isRecognizing = false;
  int? _textureId;
  TextSightSessionState _sessionState = const SessionIdle();
  StreamSubscription<TextSightSessionState>? _stateSubscription;

  /// Creates a controller from [options], a [resolution] and an initial torch state. Nothing opens
  /// the camera until [start]. [resolution] cannot change after, it rebuilds the capture graph.
  new({
    TextSightOptions options = const TextSightOptions(),
    this.resolution = CaptureResolution.medium,
    bool torchEnabled = false,
  }) : assert(
         options.roi.isNormalizedRoi,
         'Region-of-interest must be a normalized [0,1] rect with positive extent.',
       ),
       _options = options._stable(),
       _isTorchEnabled = torchEnabled;

  /// The recognizer settings in force. Change them with [updateOptions].
  TextSightOptions get options => _options;

  /// Fixed for this controller's life.
  final CaptureResolution resolution;

  /// Whether the torch is currently requested on.
  bool get isTorchEnabled => _isTorchEnabled;

  /// Whether recognition is requested on. Intent, not a readback: it flips with [start] and
  /// [pauseRecognition] and nothing else, so it says what was asked for, not what the camera is doing.
  bool get isRecognizing => _isRecognizing;

  /// The preview texture id, or `null` before [start] has acquired one.
  /// Read by `TextSightView` to mount the camera preview.
  int? get textureId => _textureId;

  /// The capture session's state as native last reported it: [SessionIdle] until [start] and
  /// again after [dispose]. Listeners are notified on change only.
  TextSightSessionState get sessionState => _sessionState;

  /// The live per-frame results stream. Subscribers must cancel their own subscription.
  /// The controller does not own it. Frames are recognized only while this has a listener.
  Stream<TextSightCapture> get captures => TextSightPlatform.instance.captures;

  /// Opens the camera if needed and begins recognition. Idempotent on the texture:
  /// a session acquired once is reused across [pauseRecognition] and [start]. Also the way back
  /// from [SessionFailed].
  Future<void> start() async {
    // Before initialize, so the first state of this session is never missed.
    _stateSubscription ??= TextSightPlatform.instance.sessionStates.listen(_onSessionState);
    _textureId ??= await TextSightPlatform.instance.initialize(_options, resolution);
    await TextSightPlatform.instance.start();
    _isRecognizing = true;
    notifyListeners();
  }

  /// Pauses recognition while keeping the session (and texture) alive. [start] resumes it.
  Future<void> pauseRecognition() async {
    await TextSightPlatform.instance.pauseRecognition();
    _isRecognizing = false;
    notifyListeners();
  }

  /// Reports the current camera-permission status without prompting the user.
  ///
  /// A cheap status read. Use it to decide whether to show a priming or
  /// rationale screen before [requestCameraPermission]. Does not open the camera.
  Future<CameraPermissionStatus> checkCameraPermission() =>
      TextSightPlatform.instance.checkCameraPermission();

  /// Requests camera permission, surfacing the system prompt when the choice is
  /// still undecided, and resolves to the resulting [CameraPermissionStatus].
  ///
  /// Call this before [start] to drive the permission flow without a third-party
  /// package. You must still declare the platform usage string,
  /// `NSCameraUsageDescription` on iOS, which is **required** (iOS terminates the
  /// app if the camera is requested without it). The Android manifest entry ships
  /// with the plugin. [start] itself never requests, so its behaviour is unchanged.
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

  /// Requests the camera torch on or off (no-op on devices without one).
  Future<void> updateTorchEnabled({required bool enabled}) async {
    await TextSightPlatform.instance.updateTorchEnabled(enabled: enabled);
    _isTorchEnabled = enabled;
    notifyListeners();
  }

  /// Releases the native session along with the controller. Safe even when [start] never
  /// succeeded, since a hot restart can leave a session running that this controller never saw.
  @override
  void dispose() {
    _stateSubscription?.cancel().ignore();
    _sessionState = const SessionIdle();
    // Unconditional: native can be holding a session this controller never learned about, which is
    // what a hot restart leaves behind. Its dispose is idempotent, so an extra call costs nothing.
    unawaited(TextSightPlatform.instance.dispose());

    super.dispose();
  }

  /// The only dedupe in the system: natives report every transition, equal reports are dropped here.
  void _onSessionState(TextSightSessionState state) {
    if (state == _sessionState) return;
    _sessionState = state;
    notifyListeners();
  }
}

/// A stable copy. `preferredLanguages` can arrive lazy or growable and is read more than once, and
/// a repeat means nothing in a preference order, so drop repeats but keep the order given. A `const`
/// constructor cannot do any of that itself.
extension on TextSightOptions {
  TextSightOptions _stable() => TextSightOptions(
    roi: roi,
    darwin: darwin.copyWith(
      preferredLanguages: darwin.preferredLanguages.toSet().toList(growable: false),
    ),
  );
}
