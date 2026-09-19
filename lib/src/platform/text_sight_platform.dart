import 'dart:typed_data' show Uint8List;

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../capture/camera_permission_status.dart';
import '../capture/capture_resolution.dart';
import '../capture/text_sight_session_state.dart';
import '../recognition/confidence_scale.dart';
import '../recognition/text_sight_capture.dart';
import '../recognition/text_sight_options.dart';
import '../recognition/text_sight_readiness_state.dart';
import 'pigeon_text_sight_platform.dart';

/// The seam both drivers delegate to, so nothing above it ever sees Pigeon and splitting into
/// per-platform packages later stays mechanical.
///
/// Methods throw [UnimplementedError] instead of being abstract, so adding one doesn't break an
/// implementation that already exists.
abstract class TextSightPlatform() extends PlatformInterface {
  /// Passes the verification token up.
  this : super(token: _token);

  static final _token = Object();

  static TextSightPlatform _instance = PigeonTextSightPlatform();

  /// The active implementation, [PigeonTextSightPlatform] by default.
  static TextSightPlatform get instance => _instance;

  /// The token check rejects an `implements`-based fake, so [value] has to `extend` this class.
  static set instance(TextSightPlatform value) {
    PlatformInterface.verify(value, _token);
    _instance = value;
  }

  /// Opens the camera and returns the texture id the preview renders into. Recognition waits for
  /// [start]. Reopening is fine, the old session is released first and this id replaces it.
  Future<int> initialize(TextSightOptions options, CaptureResolution resolution) =>
      throw UnimplementedError('initialize() has not been implemented.');

  /// Starts feeding frames to the recognizer and emitting on [captures].
  Future<void> start() => throw UnimplementedError('start() has not been implemented.');

  /// Stops recognizing but keeps the session open for a later [start].
  Future<void> pauseRecognition() =>
      throw UnimplementedError('pauseRecognition() has not been implemented.');

  /// Tears the session down and releases the camera and texture. Idempotent.
  Future<void> dispose() => throw UnimplementedError('dispose() has not been implemented.');

  /// Reads the camera-permission status without prompting.
  Future<CameraPermissionStatus> checkCameraPermission() =>
      throw UnimplementedError('checkCameraPermission() has not been implemented.');

  /// Prompts for camera permission when it's still undecided.
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

  /// One event per recognized frame, over a plain `EventChannel`.
  Stream<TextSightCapture> get captures =>
      throw UnimplementedError('captures has not been implemented.');

  /// Session-state changes pushed by native, one per actual transition.
  Stream<TextSightSessionState> get sessionStates =>
      throw UnimplementedError('sessionStates has not been implemented.');

  // Readiness is camera-free on purpose: a still image and a live preview both need the model,
  // neither needs the other.

  /// Makes sure the model is there, resolving to the terminal readiness state.
  Future<TextSightReadinessState> ensureModelReady() =>
      throw UnimplementedError('ensureModelReady() has not been implemented.');

  /// Model readiness as it changes, over a plain `EventChannel`.
  Stream<TextSightReadinessState> get modelReadiness =>
      throw UnimplementedError('modelReadiness has not been implemented.');

  // The one-shot pair below needs no session, texture or permission, and both come back with
  // `quarterTurns` 0, since a still is already upright.

  /// Recognizes text in encoded still-image [bytes].
  Future<TextSightCapture> recognizeImage(Uint8List bytes, TextSightOptions options) =>
      throw UnimplementedError('recognizeImage() has not been implemented.');

  /// Recognizes text in the still image at [path].
  Future<TextSightCapture> recognizePath(String path, TextSightOptions options) =>
      throw UnimplementedError('recognizePath() has not been implemented.');
}
