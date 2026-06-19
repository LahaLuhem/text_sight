import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons, MaterialPageRoute, Navigator;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/about/about_view.dart';
import '/features/live_scanner/live_scanner_view.dart';
import '/features/one_shot/one_shot_view.dart';
import '/features/playground/playground_view.dart';
import '../widgets/platform/platform_card.dart';
import 'home_view_model.dart';

/// Landing hub: one tile per feature demo, each pushed as its own route.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: HomeViewModel(),
    viewBuilder: (context, _) => PlatformScaffold(
      appBarData: const PlatformAppBar(title: Text('TextSight')),
      body: SafeArea(
        child: ListView(
          padding: const .symmetric(vertical: 8),
          children: [
            _DemoTile(
              icon: Icon(
                context.platformIcon(material: Icons.camera_alt, cupertino: CupertinoIcons.camera),
              ),
              title: 'Live scanner',
              description:
                  'Real-time camera OCR with a confidence-coloured overlay, torch, and a '
                  'recognized-text panel.',
              pageBuilder: (_) => const LiveScannerView(),
            ),
            _DemoTile(
              icon: Icon(
                context.platformIcon(material: Icons.image, cupertino: CupertinoIcons.photo),
              ),
              title: 'One-shot',
              description:
                  'Recognize a still image from bytes or a file path — no camera, session, or '
                  'permission.',
              pageBuilder: (_) => const OneShotView(),
            ),
            _DemoTile(
              icon: Icon(
                context.platformIcon(
                  material: Icons.tune,
                  cupertino: CupertinoIcons.slider_horizontal_3,
                ),
              ),
              title: 'Playground',
              description:
                  'Tune RecognitionLevel and the region-of-interest on a still image and compare '
                  'the output.',
              pageBuilder: (_) => const PlaygroundView(),
            ),
            _DemoTile(
              icon: Icon(
                context.platformIcon(material: Icons.info_outline, cupertino: CupertinoIcons.info),
              ),
              title: 'Under the hood',
              description:
                  'How text_sight links zero ML libraries on iOS, and the native engine behind '
                  'each platform.',
              pageBuilder: (_) => const AboutView(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DemoTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final String description;
  final WidgetBuilder pageBuilder;

  const _DemoTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.pageBuilder,
  });

  @override
  Widget build(BuildContext context) => PlatformCard(
    margin: const .symmetric(horizontal: 16, vertical: 4),
    child: PlatformListTile(
      leading: icon,
      title: Text(title),
      subtitle: Text(description),
      trailing: Icon(
        context.platformIcon(
          material: Icons.chevron_right,
          cupertino: CupertinoIcons.right_chevron,
        ),
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: pageBuilder)),
    ),
  );
}
