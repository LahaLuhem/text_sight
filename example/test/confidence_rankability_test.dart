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
  // Both widgets only read `isRankable`, so one scale of each kind covers them.
  for (final isRankable in [true, false]) {
    // Picked by `isRankable`, not looked up by name, which is the case the rule is for.
    // ignore: prefer-enums-by-name
    final scale = ConfidenceScale.values.firstWhere((scale) => scale.isRankable == isRankable);

    testWidgets('${scale.name} ${isRankable ? "tints" : "leaves plain"} the chip', (tester) async {
      await _install(scale);

      await tester.pumpWidget(const _Host(child: ConfidenceChip(confidence: 1)));

      final chip = tester.widget<PlatformChip>(find.byType(PlatformChip));
      check(chip.side == null, because: 'the border tracks the tier').equals(!isRankable);
      check(chip.backgroundColor == null, because: 'the fill tracks the tier').equals(!isRankable);
    });

    testWidgets('${scale.name} ${isRankable ? "hides" : "shows"} the note', (tester) async {
      await _install(scale);

      await tester.pumpWidget(const _Host(child: ConfidenceScaleNote()));

      expect(_noteText, isRankable ? findsNothing : findsOneWidget);
    });
  }
}

/// The note's text, found by where it sits rather than what it says.
final _noteText = find.descendant(
  of: find.byType(ConfidenceScaleNote),
  matching: find.byType(Text),
);

Future<void> _install(ConfidenceScale scale) {
  TextSightPlatform.instance = _ScalePlatform(scale);

  return EngineConfidence.resolve();
}

/// Enough of a platform to answer the one question [EngineConfidence] asks.
final class _ScalePlatform(final ConfidenceScale scale) extends TextSightPlatform {
  @override
  Future<ConfidenceScale> get confidenceScale async => scale;
}

class const _Host({required final Widget child}) extends StatelessWidget {
  @override
  // Scaffolded like the real screens, because a Material Chip needs a Material ancestor.
  Widget build(BuildContext context) => PlatformApp(home: PlatformScaffold(body: child));
}
