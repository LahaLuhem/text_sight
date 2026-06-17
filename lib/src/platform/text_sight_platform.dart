import 'dart:ui' show Locale, Rect;

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../recognition/recognition_level.dart';
import '../recognition/text_sight_capture.dart';
import '../recognition/text_sight_options.dart';
import 'pigeon_text_sight_platform.dart';

/// The platform-facing contract both drivers delegate to — the federation seam.
///
/// Drawn now even though v1 ships a single plugin package: the live controller
/// (and, later, the static one-shot) talk only to [instance], never to the native channel directly,
/// so splitting into per-platform packages later is mechanical. The contract is stated in the package's
/// *public* types — Pigeon is an implementation detail of the concrete subclass and never appears here.
///
/// Methods default to throwing [UnimplementedError] rather than being abstract, so adding one later
/// is non-breaking for any future federated implementation that has not overridden it yet.
/// [instance] defaults to [PigeonTextSightPlatform]; a federated platform package could later
/// supply its own via the [instance] setter.
abstract class TextSightPlatform extends PlatformInterface {
  /// Constructs the interface, passing the verification token to [PlatformInterface].
  TextSightPlatform() : super(token: _token);

  static final _token = Object();

  static TextSightPlatform _instance = PigeonTextSightPlatform();

  /// The active implementation — [PigeonTextSightPlatform] by default.
  static TextSightPlatform get instance => _instance;

  /// Registers [value] as the platform implementation after verifying it `extends` this class
  /// (the token guards against an `implements`-based fake).
  static set instance(TextSightPlatform value) {
    PlatformInterface.verify(value, _token);
    _instance = value;
  }

  /// Opens the camera with [options] and returns the texture id the preview renders into.
  /// Recognition does not begin until [start] is called.
  Future<int> initialize(TextSightOptions options) =>
      throw UnimplementedError('initialize() has not been implemented.');

  /// Begins delivering frames to the recognizer and emitting on [captures].
  Future<void> start() => throw UnimplementedError('start() has not been implemented.');

  /// Stops recognition but keeps the session open for a later [start].
  Future<void> stop() => throw UnimplementedError('stop() has not been implemented.');

  /// Tears the session down and releases the camera and texture.
  Future<void> dispose() => throw UnimplementedError('dispose() has not been implemented.');

  /// Restricts recognition to [roi], or clears it (whole frame) when `null`.
  Future<void> setRegionOfInterest(Rect? roi) =>
      throw UnimplementedError('setRegionOfInterest() has not been implemented.');

  /// Switches the accuracy/latency [level] of the running recognizer.
  Future<void> setRecognitionLevel(RecognitionLevel level) =>
      throw UnimplementedError('setRecognitionLevel() has not been implemented.');

  /// Updates the preferred recognition [languages] (mapped to BCP-47 tags natively).
  Future<void> setLanguages(Iterable<Locale> languages) =>
      throw UnimplementedError('setLanguages() has not been implemented.');

  /// Turns the camera torch on or off when the device has one.
  Future<void> setTorchEnabled({required bool enabled}) =>
      throw UnimplementedError('setTorchEnabled() has not been implemented.');

  /// The live per-frame results stream, backed by a plain `EventChannel`.
  Stream<TextSightCapture> get captures =>
      throw UnimplementedError('captures has not been implemented.');
}
