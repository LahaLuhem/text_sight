import '../platform/text_sight_platform.dart';
import '../recognition/confidence_scale.dart';

/// Facts about the recognition engine running on this device.
///
/// A pure namespace, like `TextSightModel`, but for what the engine's output *means* rather than
/// whether it is ready.
abstract final class TextSightEngine {
  /// What a recognized line's confidence means here.
  ///
  /// Fixed for the life of the process (the engine is picked once), so the first call crosses to
  /// native and the rest are free.
  static Future<ConfidenceScale> get confidenceScale => TextSightPlatform.instance.confidenceScale;
}
