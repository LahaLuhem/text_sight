import 'dart:async';
import 'dart:ui' show Locale, Rect, Size;

import 'package:flutter/services.dart';

import '../options/capture_resolution.dart';
import '../options/recognition_level.dart';
import '../options/text_sight_options.dart';
import '../results/confidence_scale.dart';
import '../results/recognized_line.dart';
import '../results/text_sight_capture.dart';
import '../states/camera_permission_status.dart';
import '../states/preview_geometry.dart';
import '../states/text_sight_readiness_state.dart';
import '../states/text_sight_session_state.dart';
import 'messages.g.dart';
import 'text_sight_platform.dart';

/// The default [TextSightPlatform]: Pigeon for calls and native's pushes, a plain `EventChannel`
/// for the per-frame results.
///
/// The one place public types meet their Pigeon twins.
final class PigeonTextSightPlatform() extends TextSightPlatform implements TextSightFlutterApi {
  /// Only registers as the handler for native's pushes, with no platform call, so a test can build
  /// one without mocks.
  this {
    TextSightFlutterApi.setUp(this);
  }

  // Each name must match its native `EventChannel` exactly.
  static const _capturesChannel = EventChannel('com.lahaluhem.text_sight/captures');
  static const _readinessChannel = EventChannel('com.lahaluhem.text_sight/readiness');

  final _hostApi = TextSightHostApi();

  late final Stream<TextSightCapture> _captures = _capturesChannel.receiveBroadcastStream().map(
    _decodeCapture,
  );

  late final Stream<TextSightReadinessState> _readiness = _readinessChannel
      .receiveBroadcastStream()
      .map(_decodeReadiness);

  // Never closed: they live as long as the platform does, like the EventChannel streams above.
  final _sessionStates = StreamController<TextSightSessionState>.broadcast();
  final _previews = StreamController<PreviewGeometry>.broadcast();

  @override
  Future<int> initialize(TextSightOptions options, CaptureResolution resolution) =>
      _hostApi.initialize(options._toMessage(), resolution._toMessage());

  @override
  Future<void> start() => _hostApi.start();

  @override
  Future<void> pauseRecognition() => _hostApi.pauseRecognition();

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

  /// Cached, since native picks the engine once, when the plugin registers.
  late final Future<ConfidenceScale> _confidenceScale = _hostApi.confidenceScale().then(
    (message) => message._toPublic(),
  );

  @override
  Future<ConfidenceScale> get confidenceScale => _confidenceScale;

  @override
  Stream<TextSightCapture> get captures => _captures;

  @override
  Stream<TextSightSessionState> get sessionStates => _sessionStates.stream;

  @override
  void onSessionStateChanged(SessionStateMessage state) => _sessionStates.add(state._toPublic());

  @override
  Stream<PreviewGeometry> get previews => _previews.stream;

  @override
  void onPreviewChanged(PreviewMessage preview) => _previews.add((
    textureId: preview.textureId,
    size: Size(preview.width.toDouble(), preview.height.toDouble()),
    quarterTurns: preview.quarterTurns,
  ));

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

extension on TextSightOptions {
  TextSightOptionsMessage _toMessage() => TextSightOptionsMessage(
    level: darwin.recognitionLevel._toMessage(),
    usesLanguageCorrection: darwin.usesLanguageCorrection,
    languages: darwin.preferredLanguages._toLanguageTags(),
    minimumTextHeight: darwin.minimumTextHeight,
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

extension on ConfidenceScaleMessage {
  ConfidenceScale _toPublic() => switch (this) {
    .visionGraded => .visionGraded,
    .visionCoarse => .visionCoarse,
    .mlKit => .mlKit,
  };
}

extension on SessionStateMessage {
  TextSightSessionState _toPublic() => switch (this) {
    SessionIdleMessage() => const SessionIdle(),
    SessionActiveMessage() => const SessionActive(),
    SessionPausedMessage(:final reason, :final details) => SessionPaused(
      reason: reason._toPublic(),
      details: details,
    ),
    SessionFailedMessage(:final details) => SessionFailed(details: details),
  };
}

extension on SessionPauseReasonMessage {
  SessionPauseReason _toPublic() => switch (this) {
    .appBackgrounded => .appBackgrounded,
    .interrupted => .interrupted,
  };
}

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

TextSightCapture _decodeCapture(Object? event) {
  final frameMap = event! as Map<Object?, Object?>;
  final rawLines = frameMap['lines']! as List<Object?>;

  return TextSightCapture(
    imageSize: Size(
      (frameMap['imageWidth']! as num).toDouble(),
      (frameMap['imageHeight']! as num).toDouble(),
    ),
    // Absent on a source that's already upright, like a still.
    quarterTurns: (frameMap['quarterTurns'] as num?)?.toInt() ?? 0,
    lines: rawLines.map(_decodeLine).toList(growable: false),
  );
}

/// Skips `elements`, which native never fills yet.
RecognizedLine _decodeLine(Object? rawLine) {
  final lineMap = rawLine! as Map<Object?, Object?>;

  return RecognizedLine(
    text: lineMap['text']! as String,
    boundingBox: Rect.fromLTWH(
      (lineMap['left']! as num).toDouble(),
      (lineMap['top']! as num).toDouble(),
      (lineMap['width']! as num).toDouble(),
      (lineMap['height']! as num).toDouble(),
    ),
    confidence: (lineMap['confidence']! as num).toDouble(),
  );
}

/// The stream and [PigeonTextSightPlatform.ensureModelReady] send the same map.
TextSightReadinessState _decodeReadiness(Object? event) {
  final stateMap = event! as Map<Object?, Object?>;

  return switch (stateMap['state']! as String) {
    'ready' => const ModelReady(),
    'downloading' => ModelDownloading(progress: (stateMap['progress'] as num?)?.toDouble()),
    'unavailable' => ModelUnavailable(
      reason: _decodeUnavailableReason(stateMap['reason'] as String?),
      details: stateMap['details'] as String?,
    ),
    // Both ends of this channel are ours, so an unknown tag means a prepare that didn't finish.
    _ => const ModelUnavailable(reason: ModelUnavailableReason.downloadFailed),
  };
}

ModelUnavailableReason _decodeUnavailableReason(String? tag) => switch (tag) {
  'playServicesUnavailable' => ModelUnavailableReason.playServicesUnavailable,
  _ => ModelUnavailableReason.downloadFailed,
};
