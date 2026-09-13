/// @docImport 'recognized_line.dart';
library;

/// What a [RecognizedLine.confidence] value means, which depends on the engine that produced it.
///
/// Named for how the numbers behave rather than who made them, so a third engine slots in without
/// consumers learning its name. Different scales are never comparable, across platforms or OS
/// versions.
enum ConfidenceScale({
  /// Whether ordering lines by confidence inside one capture tells you anything.
  ///
  /// Branch on this rather than the value's name, and a new scale cannot break you.
  required final bool isRankable,
}) {
  /// Spread across `[0, 1]`, so ranking lines within one capture means something.
  visionGraded(isRankable: true),

  /// Clustered near `1.0`, so ranking within a capture says almost nothing.
  visionCoarse(isRankable: false),

  /// ML Kit's own scale, spread enough to rank within a capture.
  mlKit(isRankable: true),
}
