/// @docImport 'recognized_line.dart';
library;

/// What a [RecognizedLine.confidence] number means, which is down to the engine that produced it.
///
/// Two scales are never comparable, not across platforms and not across OS versions.
enum ConfidenceScale({
  /// Whether sorting lines by confidence inside one capture tells you anything. Branch on this
  /// rather than the enum value, and a new scale can't break you.
  required final bool isRankable,
}) {
  /// Spread across `[0, 1]`, so ranking lines within one capture means something.
  visionGraded(isRankable: true),

  /// Clustered near `1.0`, so ranking within a capture says almost nothing.
  visionCoarse(isRankable: false),

  /// ML Kit's own scale, spread enough to rank within a capture.
  mlKit(isRankable: true),
}
