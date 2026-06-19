import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

import '../core/widgets/core_widgets.dart';

/// "Under the hood" — the no-bundling story and per-platform engines. Fleshed out later.
class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) => const PlatformScaffold(
    appBarData: PlatformAppBar(title: Text('Under the hood')),
    body: SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: DemoIntro(
          title: 'Under the hood',
          description:
              'How text_sight links zero ML libraries on iOS, and the native engine behind each '
              'platform.',
        ),
      ),
    ),
  );
}
