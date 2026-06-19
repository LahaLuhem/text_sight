import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

import 'features/core/views/home_view.dart';

void main() => runApp(const TextSightExampleApp());

/// Showcase app for `text_sight` — a landing hub onto each feature demo.
class TextSightExampleApp extends StatelessWidget {
  const TextSightExampleApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlatformApp(title: 'text_sight example', home: HomeView());
}
