import 'dart:typed_data' show Uint8List;

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../options/capture_resolution.dart';
import '../options/text_sight_options.dart';
import '../results/confidence_scale.dart';
import '../results/text_sight_capture.dart';
import '../states/camera_permission_status.dart';
import '../states/preview_geometry.dart';
import '../states/text_sight_readiness_state.dart';
import '../states/text_sight_session_state.dart';
import 'pigeon_text_sight_platform.dart';

/// What the Dart side asks of each platform.
///
/// The controller and the one-shot only talk to [instance], never to Pigeon, so splitting into
/// per-platform packages later is a move, not a rewrite. Methods throw [UnimplementedError] instead
/// of being abstract, so adding one breaks no implementation.
abstract class TextSightPlatform() extends PlatformInterface {
  /// Hands [PlatformInterface] the token it checks.
  this : super(token: _token);

  static final _token = Object();

  static TextSightPlatform _instance = PigeonTextSightPlatform();

  /// The active implementation, [PigeonTextSightPlatform] by default.
  static TextSightPlatform get instance => _instance;

  /// Sets the implementation, which has to `extend` this class. The token checks that.
  static set instance(TextSightPlatform value) {
    PlatformInterface.verify(value, _token);
    _instance = value;
  }

  /// Opens the camera with [options] and returns the texture id the preview renders into.
  /// Recognition waits for [start]. Reopening an open session is fine, the old one is released
  /// first and this id replaces it.
  Future<int> initialize(TextSightOptions options, CaptureResolution resolution) =>
      throw UnimplementedError('initialize() has not been implemented.');

  /// Starts reading frames onto [captures].
  Future<void> start() => throw UnimplementedError('start() has not been implemented.');

  /// Pauses recognition but keeps the session open for a later [start].
  Future<void> pauseRecognition() =>
      throw UnimplementedError('pauseRecognition() has not been implemented.');

  /// Tears the session down and releases the camera and texture. Idempotent, so calling it with
  /// nothing open is fine.
  Future<void> dispose() => throw UnimplementedError('dispose() has not been implemented.');

  /// Reports the current camera-permission status without prompting.
  Future<CameraPermissionStatus> checkCameraPermission() =>
      throw UnimplementedError('checkCameraPermission() has not been implemented.');

  /// Prompts for camera permission when it is still undecided and resolves to the resulting status.
  Future<CameraPermissionStatus> requestCameraPermission() =>
      throw UnimplementedError('requestCameraPermission() has not been implemented.');

  /// Replaces the recognizer settings on an open session.
  Future<void> updateOptions(TextSightOptions options) =>
      throw UnimplementedError('updateOptions() has not been implemented.');

  /// What a recognized line's confidence means on this device's engine.
  Future<ConfidenceScale> get confidenceScale =>
      throw UnimplementedError('confidenceScale has not been implemented.');

  /// Turns the camera torch on or off when the device has one.
  Future<void> updateTorchEnabled({required bool enabled}) =>
      throw UnimplementedError('updateTorchEnabled() has not been implemented.');

  /// Results, one per read frame.
  Stream<TextSightCapture> get captures =>
      throw UnimplementedError('captures has not been implemented.');

  /// Session-state changes pushed by native, one per actual transition.
  Stream<TextSightSessionState> get sessionStates =>
      throw UnimplementedError('sessionStates has not been implemented.');

  /// The preview's geometry, pushed by native whenever it changes.
  Stream<PreviewGeometry> get previews =>
      throw UnimplementedError('previews has not been implemented.');

  // Model readiness, apart from the camera: the live camera and the one-shot both need the model,
  // and neither needs the other.

  /// Ensures the recognition model is present and resolves to the terminal readiness state.
  Future<TextSightReadinessState> ensureModelReady() =>
      throw UnimplementedError('ensureModelReady() has not been implemented.');

  /// The model's readiness as it changes.
  Stream<TextSightReadinessState> get modelReadiness =>
      throw UnimplementedError('modelReadiness has not been implemented.');

  // The one-shot: no camera session, texture or permission.

  /// Recognizes text in the encoded still-image [bytes] using [options].
  Future<TextSightCapture> recognizeImage(Uint8List bytes, TextSightOptions options) =>
      throw UnimplementedError('recognizeImage() has not been implemented.');

  /// Recognizes text in the still image at [path] using [options].
  Future<TextSightCapture> recognizePath(String path, TextSightOptions options) =>
      throw UnimplementedError('recognizePath() has not been implemented.');
}
