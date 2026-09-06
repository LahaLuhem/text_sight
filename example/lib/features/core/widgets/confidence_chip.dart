import 'package:flutter/widgets.dart';

import '../data/constants/const_theme.dart';
import 'platform/platform_chip.dart';

/// A small pill showing a recognized line's [confidence] (`[0, 1]`), tinted by tier:
/// green (high), orange (medium), red (low).
class ConfidenceChip extends StatelessWidget {
  final double confidence;

  const new({required this.confidence, super.key});

  @override
  Widget build(BuildContext context) {
    final color = ConstTheme.confidence(context, confidence);

    return PlatformChip(
      label: Text('${(confidence * 100).toStringAsFixed(2)}%'),
      backgroundColor: color.withValues(alpha: ConstTheme.confidenceFillAlpha),
      side: BorderSide(color: color),
    );
  }
}
