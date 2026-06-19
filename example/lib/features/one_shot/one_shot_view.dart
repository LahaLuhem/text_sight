import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

import '../core/widgets/core_widgets.dart';

/// Static one-shot recognition over a still image. Fleshed out in a later step.
class OneShotView extends StatelessWidget {
  const OneShotView({super.key});

  @override
  Widget build(BuildContext context) => const PlatformScaffold(
    appBarData: PlatformAppBar(title: Text('One-shot')),
    body: SafeArea(
      child: Padding(
        padding: .all(16),
        child: DemoIntro(
          title: 'One-shot',
          description:
              'Recognize a still image from bytes or a file path — no camera, session, or '
              'permission.',
        ),
      ),
    ),
  );
}
