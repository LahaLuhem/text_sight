// Tests
// ignore_for_file: prefer-match-file-name

import 'package:checks/checks.dart';
import 'package:example/features/core/widgets/core_widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

// Its own file on purpose: the scale is a process-wide static, so "never resolved" only exists in
// a fresh isolate, and `flutter test` gives each file one. Nothing here calls resolve().
void main() {
  testWidgets('An unresolved scale leaves the chip plain, so nothing implies a tier', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(child: ConfidenceChip(confidence: 1)));

    final chip = tester.widget<PlatformChip>(find.byType(PlatformChip));
    check(chip.side).isNull();
    check(chip.backgroundColor).isNull();
  });

  testWidgets('An unresolved scale shows no note either, since nothing is known yet', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(child: ConfidenceScaleNote()));

    expect(find.textContaining('Coarse confidence'), findsNothing);
  });
}

class _Host extends StatelessWidget {
  final Widget child;

  const new({required this.child});

  // Scaffolded like the real screens, because a Material Chip needs a Material ancestor.
  @override
  Widget build(BuildContext context) => PlatformApp(home: PlatformScaffold(body: child));
}
