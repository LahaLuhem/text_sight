import 'package:flutter/widgets.dart';

import '../data/constants/const_theme.dart';
import 'platform/platform_chip.dart';

/// A small pill showing a recognized line's [confidence] (`[0, 1]`), tinted by tier:
/// green (high), orange (medium), red (low), grey when the engine supplied none.
class ConfidenceChip extends StatelessWidget {
  final double? confidence;

  const ConfidenceChip({required this.confidence, super.key});

  @override
  Widget build(BuildContext context) {
    final color = ConstTheme.confidence(context, confidence);
    final value = confidence;

    return PlatformChip(
      label: Text(value == null ? '—' : '${(value * 100).toStringAsFixed(2)}%'),
      backgroundColor: color.withValues(alpha: ConstTheme.confidenceFillAlpha),
      side: BorderSide(color: color),
    );
  }
}
