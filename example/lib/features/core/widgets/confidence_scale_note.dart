import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Theme;

import '../data/engine_confidence.dart';

/// Says why the confidence tiers are switched off, and renders nothing when they are not.
///
/// The demo would otherwise look broken on iOS 18+, where every line reads the same number.
class ConfidenceScaleNote extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: EngineConfidence.scaleListenable,
    builder: (context, scale, _) => scale?.isRankable ?? true
        ? const SizedBox.shrink()
        : Padding(
            padding: const .symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Coarse confidence on this engine, so every line lands on the same value and the '
              'tier colours are off. ConfidenceScale.isRankable is what says so.',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
  );
}
