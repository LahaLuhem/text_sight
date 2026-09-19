import '../platform/text_sight_platform.dart';
import '../recognition/confidence_scale.dart';

/// Facts about the recognition engine on this device.
// Nothing to construct here, so a primary constructor would only add a public member.
// ignore: use_primary_constructors
abstract final class TextSightEngine {
  /// What a recognized line's confidence means here. The engine gets picked once per process, so
  /// only the first call crosses to native.
  static Future<ConfidenceScale> get confidenceScale => TextSightPlatform.instance.confidenceScale;
}
