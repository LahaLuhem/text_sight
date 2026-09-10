// Tests
// ignore_for_file: prefer-match-file-name

import 'package:checks/checks.dart';
import 'package:example/features/core/data/engine_confidence.dart';
import 'package:example/features/core/widgets/core_widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:text_sight/src/platform/text_sight_platform.dart';
import 'package:text_sight/text_sight.dart';

// Plain `testWidgets` rather than bdd_framework: its scenarios run on `test()`, which hands out no
// `WidgetTester`. The scale is driven by swapping the platform, so nothing needs a test backdoor.
void main() {
  const cases = [
    (ConfidenceScale.visionCoarse, false),
    (ConfidenceScale.visionGraded, true),
    (ConfidenceScale.mlKit, true),
  ];

  for (final (scale, isTiered) in cases) {
    testWidgets('${scale.name} ${isTiered ? "tints" : "leaves plain"} the chip', (tester) async {
      await _install(scale);

      await tester.pumpWidget(const _Host(child: ConfidenceChip(confidence: 1)));

      final chip = tester.widget<PlatformChip>(find.byType(PlatformChip));
      check(chip.side == null, because: 'the border tracks the tier').equals(!isTiered);
      check(chip.backgroundColor == null, because: 'the fill tracks the tier').equals(!isTiered);
    });

    testWidgets('${scale.name} ${isTiered ? "hides" : "shows"} the note', (tester) async {
      await _install(scale);

      await tester.pumpWidget(const _Host(child: ConfidenceScaleNote()));

      expect(find.textContaining('Coarse confidence'), isTiered ? findsNothing : findsOneWidget);
    });
  }
}

Future<void> _install(ConfidenceScale scale) {
  TextSightPlatform.instance = _ScalePlatform(scale);

  return EngineConfidence.resolve();
}

/// Enough of a platform to answer the one question [EngineConfidence] asks.
final class _ScalePlatform extends TextSightPlatform {
  final ConfidenceScale scale;

  new(this.scale);

  @override
  Future<ConfidenceScale> get confidenceScale async => scale;
}

class _Host extends StatelessWidget {
  final Widget child;

  const new({required this.child});

  @override
  // Scaffolded like the real screens, because a Material Chip needs a Material ancestor.
  Widget build(BuildContext context) => PlatformApp(home: PlatformScaffold(body: child));
}
