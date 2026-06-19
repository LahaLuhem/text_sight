import 'dart:ui' show Locale, Rect, Size;

import 'package:flutter/services.dart';

import '../recognition/recognition_level.dart';
import '../recognition/recognized_line.dart';
import '../recognition/text_sight_capture.dart';
import '../recognition/text_sight_options.dart';
import 'messages.g.dart';
import 'text_sight_platform.dart';

/// The default [TextSightPlatform], backed by the Pigeon control channel plus a
/// plain `EventChannel` for the per-frame results stream.
///
/// The single seam between the public Dart API and the native sides: control
/// calls go through the generated [TextSightHostApi], mapping each public type to
/// its transport twin, while recognition results arrive as self-describing maps
/// on the captures [EventChannel] and are decoded into [TextSightCapture]s. The
/// preview texture id is the return of [initialize]. Registered as
/// [TextSightPlatform.instance] by default; a future federated platform package
/// can replace it.
final class PigeonTextSightPlatform extends TextSightPlatform {
  /// The native→Dart per-frame results stream. The name is mirrored verbatim by
  /// the native `EventChannel` registration on each platform.
  static const _capturesChannel = EventChannel('com.LahaLuhem.text_sight/captures');

  final _hostApi = TextSightHostApi();

  late final Stream<TextSightCapture> _captures = _capturesChannel.receiveBroadcastStream().map(
    _decodeCapture,
  );

  @override
  Future<int> initialize(TextSightOptions options) => _hostApi.initialize(options._toMessage());

  @override
  Future<void> start() => _hostApi.start();

  @override
  Future<void> stop() => _hostApi.stop();

  @override
  Future<void> dispose() => _hostApi.dispose();

  @override
  Future<void> updateRegionOfInterest(Rect? roi) => _hostApi.setRegionOfInterest(roi?._toMessage());

  @override
  Future<void> updateRecognitionLevel(RecognitionLevel level) =>
      _hostApi.setRecognitionLevel(level._toMessage());

  @override
  Future<void> updateLanguages(Iterable<Locale> languages) =>
      _hostApi.setLanguages(languages._toLanguageTags());

  @override
  Future<void> updateTorchEnabled({required bool enabled}) => _hostApi.setTorchEnabled(enabled);

  @override
  Stream<TextSightCapture> get captures => _captures;

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
    roi: roi?._toMessage(),
  );
}

extension on RecognitionLevel {
  RecognitionLevelMessage _toMessage() => switch (this) {
    .fast => .fast,
    .accurate => .accurate,
  };
}

extension on Rect {
  RegionOfInterestMessage _toMessage() =>
      RegionOfInterestMessage(left: left, top: top, width: width, height: height);
}

extension on Iterable<Locale> {
  List<String> _toLanguageTags() => map((locale) => locale.toLanguageTag()).toList(growable: false);
}

/// Decodes one per-frame [PigeonTextSightPlatform.captures] event — a
/// self-describing map — into a [TextSightCapture].
TextSightCapture _decodeCapture(Object? event) {
  final frameMap = event! as Map<Object?, Object?>;
  final rawLines = frameMap['lines']! as List<Object?>;

  return TextSightCapture(
    imageSize: Size(
      (frameMap['imageWidth']! as num).toDouble(),
      (frameMap['imageHeight']! as num).toDouble(),
    ),
    // Absent on an already-upright source (e.g. the static one-shot); defaults to no rotation.
    quarterTurns: (frameMap['quarterTurns'] as num?)?.toInt() ?? 0,
    lines: rawLines.map(_decodeLine).toList(growable: false),
  );
}

/// Decodes one line entry into a [RecognizedLine]. `elements` stays `null` in v1
/// (reserved — the wire carries the slot for a future additive change).
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
