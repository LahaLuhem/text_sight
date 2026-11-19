import 'dart:typed_data' show Uint8List;

import '../options/darwin_options.dart';
import '../options/recognition_level.dart';
import '../options/text_sight_options.dart';
import '../platform/text_sight_platform.dart';
import '../results/text_sight_capture.dart';
import 'normalized_roi.dart';

/// Reads text in a still image.
///
/// Same results as the live camera, with no session, texture or permission. Defaults to
/// [RecognitionLevel.accurate], since there's no frame rate to keep up.
abstract final class TextSight {
  /// Reads text in the encoded image [bytes] (PNG, JPEG, …).
  ///
  /// Throws a `PlatformException` if [bytes] doesn't decode as an image.
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

  /// Reads text in the image file at [path].
  ///
  /// Throws a `PlatformException` if there's no readable image at [path].
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
