/// @docImport 'recognized_line.dart';
library;

/// What a [RecognizedLine.confidence] value means, which depends on the engine that produced it.
///
/// Named for what the numbers behave like rather than who made them, so an engine with a third
/// character slots in without every consumer learning its name. Values from different scales are
/// never comparable, not across platforms and not across OS versions.
enum ConfidenceScale {
  /// Spread across `[0, 1]`, so ranking lines within one capture means something.
  visionGraded(isRankable: true),

  /// Clustered near `1.0`, so ranking within a capture says almost nothing.
  visionCoarse(isRankable: false),

  /// ML Kit's own scale, spread enough to rank within a capture.
  mlKit(isRankable: true);

  /// Whether ordering lines by confidence inside one capture tells you anything.
  ///
  /// Branch on this rather than the value's name, and a new scale cannot break you.
  final bool isRankable;

  new({required this.isRankable});
}
