import 'dart:async';
import 'dart:ui' show Locale, Rect;

import 'package:flutter/foundation.dart';

import '../platform/text_sight_platform.dart';
import '../recognition/normalized_roi.dart';
import '../recognition/recognition_level.dart';
import '../recognition/text_sight_capture.dart';
import '../recognition/text_sight_options.dart';
import 'camera_permission_status.dart';

/// Configures and drives a live camera recognition session.
///
/// The Dart face of the live-camera driver. A [ChangeNotifier] exposing the current configuration
/// and session state through individual getters — no bundled state object — that a `TextSightView`
/// (or any listener) rebuilds from. Per-frame results arrive on [captures]; the preview renders the
/// [textureId]. Every call delegates to [TextSightPlatform.instance], so the controller carries
/// no platform knowledge of its own.
final class TextSightController extends ChangeNotifier {
  RecognitionLevel _level;
  Iterable<Locale> _languages;
  Rect? _roi;
  bool _isTorchEnabled;
  var _isRunning = false;
  int? _textureId;

  /// Creates a controller seeded from [options] (the shared recognizer config) and an initial torch state.
  /// Nothing opens the camera until [start].
  TextSightController({
    TextSightOptions options = const TextSightOptions(),
    bool torchEnabled = false,
  }) : assert(
         options.roi.isNormalizedRoi,
         'Region-of-interest must be a normalized [0,1] rect with positive extent.',
       ),
       _level = options.level,
       _languages = options.languages.toList(growable: false),
       _roi = options.roi,
       _isTorchEnabled = torchEnabled;

  /// The current accuracy/latency level.
  RecognitionLevel get recognitionLevel => _level;

  /// The current preferred recognition languages, most-preferred first.
  Iterable<Locale> get languages => _languages;

  /// The current scan-box, or `null` when recognition spans the whole frame.
  Rect? get regionOfInterest => _roi;

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

  TextSightOptions get _options =>
      TextSightOptions(level: _level, languages: _languages, roi: _roi);

  /// Opens the camera if needed and begins recognition. Idempotent on the texture:
  /// a session acquired once is reused across stop/start.
  Future<void> start() async {
    _textureId ??= await TextSightPlatform.instance.initialize(_options);
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
  /// A cheap status read — use it to decide whether to show a priming or
  /// rationale screen before [requestCameraPermission]. Does not open the camera.
  Future<CameraPermissionStatus> checkCameraPermission() =>
      TextSightPlatform.instance.checkCameraPermission();

  /// Requests camera permission, surfacing the system prompt when the choice is
  /// still undecided, and resolves to the resulting [CameraPermissionStatus].
  ///
  /// Call this before [start] to drive the permission flow without a third-party
  /// package. You must still declare the platform usage string —
  /// `NSCameraUsageDescription` on iOS, which is **required** (iOS terminates the
  /// app if the camera is requested without it); the Android manifest entry ships
  /// with the plugin. [start] itself never requests — its behaviour is unchanged.
  Future<CameraPermissionStatus> requestCameraPermission() =>
      TextSightPlatform.instance.requestCameraPermission();

  /// Switches the accuracy/latency [level] of the running recognizer.
  Future<void> updateRecognitionLevel(RecognitionLevel level) async {
    await TextSightPlatform.instance.updateRecognitionLevel(level);
    _level = level;
    notifyListeners();
  }

  /// Replaces the preferred recognition [languages], most-preferred first.
  Future<void> updateLanguages(Iterable<Locale> languages) async {
    final selected = languages.toList(growable: false);
    await TextSightPlatform.instance.updateLanguages(selected);
    _languages = selected;
    notifyListeners();
  }

  /// Restricts recognition to [roi], or clears it (whole frame) when `null`.
  Future<void> updateRegionOfInterest(Rect? roi) async {
    assert(
      roi.isNormalizedRoi,
      'Region-of-interest must be a normalized [0,1] rect with positive extent.',
    );
    await TextSightPlatform.instance.updateRegionOfInterest(roi);
    _roi = roi;
    notifyListeners();
  }

  /// Requests the camera torch on or off (no-op on devices without one).
  Future<void> updateTorchEnabled({required bool enabled}) async {
    await TextSightPlatform.instance.updateTorchEnabled(enabled: enabled);
    _isTorchEnabled = enabled;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_textureId != null) unawaited(TextSightPlatform.instance.dispose());

    super.dispose();
  }
}
