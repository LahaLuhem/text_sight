import '../platform/text_sight_platform.dart';
import '../results/confidence_scale.dart';

/// Facts about the recognition engine on this device.
abstract final class TextSightEngine {
  /// What a recognized line's confidence means here.
  ///
  /// The engine is picked once per app run, so only the first call asks native.
  static Future<ConfidenceScale> get confidenceScale => TextSightPlatform.instance.confidenceScale;
}
