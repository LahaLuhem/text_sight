import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform/text_sight_platform.dart';
import '../recognition/normalized_roi.dart';
import '../recognition/text_sight_capture.dart';
import '../recognition/text_sight_options.dart';
import 'camera_permission_status.dart';
import 'capture_resolution.dart';

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
  var _isRunning = false;
  int? _textureId;

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

  /// Whether a session is started and delivering [captures].
  bool get isRunning => _isRunning;

  /// The preview texture id, or `null` before [start] has acquired one.
  /// Read by `TextSightView` to mount the camera preview.
  int? get textureId => _textureId;

  /// The live per-frame results stream. Subscribers must cancel their own subscription.
  /// The controller does not own it.
  Stream<TextSightCapture> get captures => TextSightPlatform.instance.captures;

  /// Opens the camera if needed and begins recognition. Idempotent on the texture:
  /// a session acquired once is reused across stop/start.
  Future<void> start() async {
    _textureId ??= await TextSightPlatform.instance.initialize(_options, resolution);
    await TextSightPlatform.instance.start();
    _isRunning = true;
    notifyListeners();
  }

  /// Pauses recognition while keeping the session (and texture) alive.
  Future<void> stop() async {
    await TextSightPlatform.instance.stop();
    _isRunning = false;
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
    // Unconditional: native can be holding a session this controller never learned about, which is
    // what a hot restart leaves behind. Its dispose is idempotent, so an extra call costs nothing.
    unawaited(TextSightPlatform.instance.dispose());

    super.dispose();
  }
}

/// A stable copy. `languages` can arrive lazy or growable and is read more than once, and a repeat
/// means nothing in a preference order, so drop repeats but keep the order given. A `const`
/// constructor cannot do any of that itself.
extension on TextSightOptions {
  TextSightOptions _stable() => TextSightOptions(
    level: level,
    usesLanguageCorrection: usesLanguageCorrection,
    languages: languages.toSet().toList(growable: false),
    roi: roi,
  );
}
