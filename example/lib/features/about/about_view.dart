import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart' show Icons, Theme;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/core_widgets.dart';
import 'about_view_model.dart';

/// "Under the hood": the design decisions behind text_sight, as a list of cards.
class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: AboutViewModel(),
    viewBuilder: (context, _) => PlatformScaffold(
      appBarData: const PlatformAppBar(title: Text('Under the hood')),
      body: SafeArea(
        child: ListView(
          padding: const .all(16),
          children: [
            const DemoIntro(
              title: 'Why text_sight',
              description:
                  'A live, cross-platform OCR plugin that links zero third-party ML libraries on '
                  'iOS — here is how.',
            ),
            const Gap(16),
            _NuanceCard(
              icon: Icon(
                context.platformIcon(
                  material: Icons.verified_user_outlined,
                  cupertino: CupertinoIcons.shield,
                ),
              ),
              title: 'Zero third-party ML on iOS',
              body:
                  'iOS uses Apple Vision, a system framework, so the iOS build links no GoogleMLKit '
                  '— and none of the arm64 / Swift Package Manager warnings that come from running '
                  'ML Kit on iOS. ML Kit lives only in the Android Gradle build; no recognition '
                  'library ever enters your Dart dependencies.',
            ),
            const Gap(12),
            _NuanceCard(
              icon: Icon(
                context.platformIcon(
                  material: Icons.smartphone,
                  cupertino: CupertinoIcons.device_phone_portrait,
                ),
              ),
              title: 'A native engine per platform',
              body:
                  'iOS recognizes with Apple Vision (the Swift RecognizeTextRequest, iOS 18+); '
                  'Android with ML Kit Text Recognition v2 (Latin). One Dart API drives both.',
            ),
            const Gap(12),
            _NuanceCard(
              icon: Icon(
                context.platformIcon(
                  material: Icons.crop_free,
                  cupertino: CupertinoIcons.fullscreen,
                ),
              ),
              title: 'One coordinate contract',
              body:
                  'Bounding boxes are normalized [0,1] with a top-left origin on both platforms, '
                  'converted natively — so an overlay painter never branches on platform.',
            ),
            const Gap(12),
            _NuanceCard(
              icon: Icon(
                context.platformIcon(material: Icons.speed, cupertino: CupertinoIcons.speedometer),
              ),
              title: 'Confidence, with a caveat',
              body:
                  'Both engines report a per-line confidence, but the scales are not comparable '
                  'across platforms. A null confidence means the engine supplied none — not low '
                  'confidence.',
            ),
            const Gap(12),
            _NuanceCard(
              icon: Icon(
                context.platformIcon(
                  material: Icons.swap_horiz,
                  cupertino: CupertinoIcons.arrow_right_arrow_left,
                ),
              ),
              title: 'Two drivers, one recognizer',
              body:
                  'The live camera (TextSightController + TextSightView) and the static one-shot '
                  '(TextSight.recognizeImage / recognizePath) share the same recognizer and result '
                  'models. The one-shot needs no camera, session, or permission.',
            ),
          ],
        ),
      ),
    ),
  );
}

/// One design-decision card: a leading icon beside a title and explanatory body.
class _NuanceCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final String body;

  const _NuanceCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => PlatformCard(
    child: Padding(
      padding: const .all(16),
      child: Row(
        crossAxisAlignment: .start,
        spacing: 12,
        children: [
          icon,
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: 4,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
