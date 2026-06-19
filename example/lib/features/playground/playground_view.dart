import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

import '/features/core/widgets/core_widgets.dart';

/// Recognizer-config playground (level + ROI) on a still. Fleshed out in a later step.
class PlaygroundView extends StatelessWidget {
  const PlaygroundView({super.key});

  @override
  Widget build(BuildContext context) => const PlatformScaffold(
    appBarData: PlatformAppBar(title: Text('Playground')),
    body: SafeArea(
      child: Padding(
        padding: .all(16),
        child: DemoIntro(
          title: 'Playground',
          description:
              'Tune RecognitionLevel and the region-of-interest on a still image and compare '
              'the output.',
        ),
      ),
    ),
  );
}
