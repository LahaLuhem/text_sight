import 'package:flutter/widgets.dart';

import '../data/constants/const_theme.dart';
import '../data/engine_confidence.dart';
import 'platform/platform_chip.dart';

/// A small pill showing a recognized line's [confidence] (`[0, 1]`).
///
/// Tinted by tier, green (high) through orange to red (low), only where the engine's scale can
/// actually be ranked. On a coarse scale every line reads the same number, so the pill stays plain
/// rather than painting a tier that means nothing.
class ConfidenceChip extends StatelessWidget {
  final double confidence;

  const new({required this.confidence, super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: EngineConfidence.scaleListenable,
    builder: (context, scale, _) {
      final label = Text('${(confidence * 100).toStringAsFixed(2)}%');
      if (!(scale?.isRankable ?? false)) return PlatformChip(label: label);

      final color = ConstTheme.confidence(context, confidence);

      return PlatformChip(
        label: label,
        backgroundColor: color.withValues(alpha: ConstTheme.confidenceFillAlpha),
        side: BorderSide(color: color),
      );
    },
  );
}
