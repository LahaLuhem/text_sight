import 'dart:typed_data' show Uint8List;

import '../platform/text_sight_platform.dart';
import '../recognition/darwin_options.dart';
import '../recognition/normalized_roi.dart';
import '../recognition/recognition_level.dart';
import '../recognition/text_sight_capture.dart';
import '../recognition/text_sight_options.dart';

/// Text recognition on a still image. No camera, no session, no permission.
///
/// Same recognizer and same result models as the live `TextSightController`. Defaults to
/// [RecognitionLevel.accurate], with no frame budget to protect, and `quarterTurns` on the result
/// is always `0`.
// Nothing to construct here, so a primary constructor would only add a public member.
// ignore: use_primary_constructors
abstract final class TextSight {
  /// Recognizes text in an encoded image (PNG, JPEG, …). Throws a `PlatformException` when [bytes]
  /// won't decode.
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

  /// Recognizes text in the image file at [path]. Throws a `PlatformException` when there's no
  /// readable image there.
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
