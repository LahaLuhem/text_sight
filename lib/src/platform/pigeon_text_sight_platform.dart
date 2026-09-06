import 'dart:ui' show Locale, Rect, Size;

import 'package:flutter/services.dart';

import '../capture/camera_permission_status.dart';
import '../capture/capture_resolution.dart';
import '../recognition/recognition_level.dart';
import '../recognition/recognized_line.dart';
import '../recognition/text_sight_capture.dart';
import '../recognition/text_sight_options.dart';
import '../recognition/text_sight_readiness_state.dart';
import 'messages.g.dart';
import 'text_sight_platform.dart';

/// The default [TextSightPlatform]: Pigeon for control calls, a plain `EventChannel` for the
/// per-frame results.
///
/// The one place public types meet their transport twins. Frames arrive as self-describing maps
/// and are decoded into [TextSightCapture]s here. A federated platform package could replace it.
final class PigeonTextSightPlatform extends TextSightPlatform {
  /// Per-frame results coming up from native. The name is mirrored verbatim by
  /// the native `EventChannel` registration on each platform.
  static const _capturesChannel = EventChannel('com.lahaluhem.text_sight/captures');

  /// Model readiness coming up from native, the name mirrored verbatim by the
  /// `EventChannel` registration on each platform.
  static const _readinessChannel = EventChannel('com.lahaluhem.text_sight/readiness');

  final _hostApi = TextSightHostApi();

  late final Stream<TextSightCapture> _captures = _capturesChannel.receiveBroadcastStream().map(
    _decodeCapture,
  );

  late final Stream<TextSightReadinessState> _readiness = _readinessChannel
      .receiveBroadcastStream()
      .map(_decodeReadiness);

  @override
  Future<int> initialize(TextSightOptions options, CaptureResolution resolution) =>
      _hostApi.initialize(options._toMessage(), resolution._toMessage());

  @override
  Future<void> start() => _hostApi.start();

  @override
  Future<void> stop() => _hostApi.stop();

  @override
  Future<void> dispose() => _hostApi.dispose();

  @override
  Future<CameraPermissionStatus> checkCameraPermission() async =>
      (await _hostApi.checkCameraPermission())._toPublic();

  @override
  Future<CameraPermissionStatus> requestCameraPermission() async =>
      (await _hostApi.requestCameraPermission())._toPublic();

  @override
  Future<void> updateOptions(TextSightOptions options) => _hostApi.setOptions(options._toMessage());

  @override
  Future<void> updateTorchEnabled({required bool enabled}) => _hostApi.setTorchEnabled(enabled);

  @override
  Stream<TextSightCapture> get captures => _captures;

  @override
  Future<TextSightReadinessState> ensureModelReady() async =>
      _decodeReadiness(await _hostApi.ensureModelReady());

  @override
  Stream<TextSightReadinessState> get modelReadiness => _readiness;

  @override
  Future<TextSightCapture> recognizeImage(Uint8List bytes, TextSightOptions options) async =>
      _decodeCapture(await _hostApi.recognizeImage(bytes, options._toMessage()));

  @override
  Future<TextSightCapture> recognizePath(String path, TextSightOptions options) async =>
      _decodeCapture(await _hostApi.recognizePath(path, options._toMessage()));
}

/// Maps the public recognizer config to its Pigeon transport twin.
extension on TextSightOptions {
  TextSightOptionsMessage _toMessage() => TextSightOptionsMessage(
    level: level._toMessage(),
    languages: languages._toLanguageTags(),
    // Pinned until the options type carries it: 0 keeps every pixel, so small print survives.
    minimumTextHeight: 0,
    roi: roi?._toMessage(),
  );
}

extension on RecognitionLevel {
  RecognitionLevelMessage _toMessage() => switch (this) {
    .fast => .fast,
    .accurate => .accurate,
  };
}

extension on CaptureResolution {
  CaptureResolutionMessage _toMessage() => switch (this) {
    .low => .low,
    .medium => .medium,
    .high => .high,
  };
}

/// Maps the Pigeon permission-status twin back to the public enum.
extension on CameraPermissionStatusMessage {
  CameraPermissionStatus _toPublic() => switch (this) {
    .granted => .granted,
    .denied => .denied,
    .permanentlyDenied => .permanentlyDenied,
  };
}

extension on Rect {
  RegionOfInterestMessage _toMessage() =>
      RegionOfInterestMessage(left: left, top: top, width: width, height: height);
}

extension on Iterable<Locale> {
  List<String> _toLanguageTags() => map((locale) => locale.toLanguageTag()).toList(growable: false);
}

/// Decodes one per-frame [PigeonTextSightPlatform.captures] event, a
/// self-describing map, into a [TextSightCapture].
TextSightCapture _decodeCapture(Object? event) {
  final frameMap = event! as Map<Object?, Object?>;
  final rawLines = frameMap['lines']! as List<Object?>;

  return TextSightCapture(
    imageSize: Size(
      (frameMap['imageWidth']! as num).toDouble(),
      (frameMap['imageHeight']! as num).toDouble(),
    ),
    // Absent on an already-upright source (e.g. the static one-shot), so it defaults to no rotation.
    quarterTurns: (frameMap['quarterTurns'] as num?)?.toInt() ?? 0,
    lines: rawLines.map(_decodeLine).toList(growable: false),
  );
}

/// Decodes one line entry into a [RecognizedLine]. `elements` stays `null` in v1
/// (reserved: the wire carries the slot for a future additive change).
RecognizedLine _decodeLine(Object? rawLine) {
  final lineMap = rawLine! as Map<Object?, Object?>;
  final confidenceValue = lineMap['confidence'];

  return RecognizedLine(
    text: lineMap['text']! as String,
    boundingBox: Rect.fromLTWH(
      (lineMap['left']! as num).toDouble(),
      (lineMap['top']! as num).toDouble(),
      (lineMap['width']! as num).toDouble(),
      (lineMap['height']! as num).toDouble(),
    ),
    confidence: (confidenceValue as num?)?.toDouble(),
  );
}

/// Decodes one model-readiness event, a self-describing map, into a
/// [TextSightReadinessState]. Shared by the [PigeonTextSightPlatform.modelReadiness]
/// stream and the terminal map [PigeonTextSightPlatform.ensureModelReady] returns. Each
/// native side emits exactly this shape.
TextSightReadinessState _decodeReadiness(Object? event) {
  final stateMap = event! as Map<Object?, Object?>;

  return switch (stateMap['state']! as String) {
    'ready' => const ModelReady(),
    'downloading' => ModelDownloading(progress: (stateMap['progress'] as num?)?.toDouble()),
    'unavailable' => ModelUnavailable(
      reason: _decodeUnavailableReason(stateMap['reason'] as String?),
      details: stateMap['details'] as String?,
    ),
    // Both ends of this channel are ours, so an unknown tag means a prep that did not complete.
    _ => const ModelUnavailable(reason: ModelUnavailableReason.downloadFailed),
  };
}

/// Maps the wire tag to its [ModelUnavailableReason], defaulting to
/// [ModelUnavailableReason.downloadFailed] for anything unrecognized.
ModelUnavailableReason _decodeUnavailableReason(String? tag) => switch (tag) {
  'playServicesUnavailable' => ModelUnavailableReason.playServicesUnavailable,
  _ => ModelUnavailableReason.downloadFailed,
};
