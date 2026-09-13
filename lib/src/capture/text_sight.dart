import 'dart:typed_data' show Uint8List;

import '../platform/text_sight_platform.dart';
import '../recognition/darwin_options.dart';
import '../recognition/normalized_roi.dart';
import '../recognition/recognition_level.dart';
import '../recognition/text_sight_capture.dart';
import '../recognition/text_sight_options.dart';

/// One-shot, still-image text recognition: the static counterpart to the live `TextSightController`.
///
/// Same recognizer and result models as the live driver, but no camera, session, texture, or
/// permission. Defaults to [RecognitionLevel.accurate], having no per-frame budget to protect,
/// and `quarterTurns` is always `0`.
// Nothing to construct here, so a primary constructor would only add a public member.
// ignore: use_primary_constructors
abstract final class TextSight {
  /// Recognizes text in the encoded image [bytes] (PNG, JPEG, …) at [options].
  ///
  /// Resolves to a [TextSightCapture] of every recognized line.
  /// Throws a `PlatformException` if [bytes] cannot be decoded as an image.
  static Future<TextSightCapture> recognizeImage(
    Uint8List bytes, {
    TextSightOptions options = const TextSightOptions(
      darwin: DarwinOptions(recognitionLevel: .accurate),
    ),
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
    TextSightOptions options = const TextSightOptions(
      darwin: DarwinOptions(recognitionLevel: .accurate),
    ),
  }) {
    assert(
      options.roi.isNormalizedRoi,
      'Region-of-interest must be a normalized [0,1] rect with positive extent.',
    );

    return TextSightPlatform.instance.recognizePath(path, options);
  }
}
