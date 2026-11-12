// Tests
// ignore_for_file: prefer-match-file-name

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_sight/src/platform/text_sight_platform.dart';
import 'package:text_sight/text_sight.dart';

// Plain `testWidgets`: bdd_framework scenarios get no `WidgetTester`.
void main() {
  testWidgets('The view mounts with no Directionality above it', (tester) async {
    final platform = _FramePlatform();
    TextSightPlatform.instance = platform;
    final controller = TextSightController();
    addTearDown(controller.dispose);
    await controller.start();

    await tester.pumpWidget(TextSightView(controller: controller));
    platform.frames.add(
      const TextSightCapture(lines: [], imageSize: Size(1080, 1920), quarterTurns: 1),
    );
    await tester.pump();

    check(tester.takeException()).isNull();
    // The preview rendered, so the check above isn't vacuous.
    check(find.byType(Texture).evaluate()).length.equals(1);
  });
}

final class _FramePlatform() extends TextSightPlatform {
  // Sync, so one pump renders an added capture.
  final frames = StreamController<TextSightCapture>.broadcast(sync: true);

  @override
  Future<int> initialize(TextSightOptions options, CaptureResolution resolution) async => 7;

  @override
  Future<void> start() => Future.value();

  @override
  Future<void> dispose() => frames.close();

  @override
  Stream<TextSightCapture> get captures => frames.stream;

  @override
  Stream<TextSightSessionState> get sessionStates => const Stream.empty();
}
