import 'dart:typed_data' show Uint8List;

import '../platform/text_sight_platform.dart';
import '../recognition/normalized_roi.dart';
import '../recognition/recognition_level.dart';
import '../recognition/text_sight_capture.dart';
import '../recognition/text_sight_options.dart';

/// One-shot, still-image text recognition — the static counterpart to the live `TextSightController`.
///
/// Shares the recognizer and result models with the live driver but needs no camera, session, texture,
/// or permission: each call hands a still image to a transient native recognizer and returns a [TextSightCapture].
/// Recognition defaults to [RecognitionLevel.accurate] — unlike the live driver's latency-bound `.fast`,
/// a still has no per-frame budget to protect. The returned capture's `quarterTurns` is always `0`,
/// since a still is already upright.
///
/// A pure namespace: every entry point is `static` and it delegates to [TextSightPlatform.instance],
/// so it holds no platform knowledge and is never instantiated.
abstract final class TextSight {
  /// Recognizes text in the encoded image [bytes] (PNG, JPEG, …) at [options].
  ///
  /// Resolves to a [TextSightCapture] of every recognized line.
  /// Throws a `PlatformException` if [bytes] cannot be decoded as an image.
  static Future<TextSightCapture> recognizeImage(
    Uint8List bytes, {
    TextSightOptions options = const TextSightOptions(level: .accurate),
  }) {
    assert(
      options.roi.isNormalizedRoi,
      'Region-of-interest must be a normalized [0,1] rect with positive extent.',
    );

    return TextSightPlatform.instance.recognizeImage(bytes, options);
  }

  /// Recognizes text in the image file at [path] at [options].
  ///
  /// Resolves to a [TextSightCapture] of every recognized line.
  /// Throws a `PlatformException` if no readable image exists at [path].
  static Future<TextSightCapture> recognizePath(
    String path, {
    TextSightOptions options = const TextSightOptions(level: .accurate),
  }) {
    assert(
      options.roi.isNormalizedRoi,
      'Region-of-interest must be a normalized [0,1] rect with positive extent.',
    );

    return TextSightPlatform.instance.recognizePath(path, options);
  }
}
