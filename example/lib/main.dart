import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

import 'features/core/data/engine_confidence.dart';
import 'features/core/data/fake_camera_platform.dart';
import 'features/core/views/home_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FakeCameraPlatform.installWhenSimulated();
  // Unawaited: nothing needs it to paint, and consumers show plain values until it lands.
  unawaited(EngineConfidence.resolve());
  runApp(const TextSightExampleApp());
}

/// Showcase app for `text_sight`: a landing hub onto each feature demo.
class TextSightExampleApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlatformApp(title: 'text_sight example', home: HomeView());
}
