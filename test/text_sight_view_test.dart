// Tests
// ignore_for_file: prefer-match-file-name

import 'dart:async';
import 'dart:math' show pi;

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_sight/src/capture/preview_geometry.dart';
import 'package:text_sight/src/platform/text_sight_platform.dart';
import 'package:text_sight/text_sight.dart';

// Plain `testWidgets`: bdd_framework scenarios get no `WidgetTester`.
void main() {
  testWidgets('The view mounts with no Directionality above it', (tester) async {
    final platform = await _pumpView(tester);
    platform.previewPushes.add((textureId: 7, size: const Size(960, 1280), quarterTurns: 1));
    await tester.pump();

    check(tester.takeException()).isNull();
    // The preview rendered, so the check above isn't vacuous.
    check(find.byType(Texture).evaluate()).length.equals(1);
  });

  testWidgets('The preview turns with native geometry, no capture needed', (tester) async {
    final platform = await _pumpView(tester);

    platform.previewPushes.add((textureId: 7, size: const Size(960, 1280), quarterTurns: 1));
    await tester.pump();
    check(_quarterTurns(tester)).equals(1);

    platform.previewPushes.add((textureId: 7, size: const Size(1280, 960), quarterTurns: 2));
    await tester.pump();
    check(_quarterTurns(tester)).equals(2);
  });
}

/// Mounts a view on a started controller, before native has pushed anything.
Future<_PreviewPlatform> _pumpView(WidgetTester tester) async {
  final platform = _PreviewPlatform();
  TextSightPlatform.instance = platform;
  final controller = TextSightController();
  addTearDown(controller.dispose);
  await controller.start();
  await tester.pumpWidget(TextSightView(controller: controller));

  return platform;
}

/// The clockwise quarter turns the texture is drawn at, read off where its top edge points.
int _quarterTurns(WidgetTester tester) {
  final texture = tester.renderObject<RenderBox>(find.byType(Texture));
  final topEdge =
      texture.localToGlobal(Offset(texture.size.width, 0)) - texture.localToGlobal(.zero);

  return (topEdge.direction / (pi / 2)).round() % 4;
}

/// Never sends a capture.
final class _PreviewPlatform() extends TextSightPlatform {
  // Sync, so one pump shows a push.
  final previewPushes = StreamController<PreviewGeometry>.broadcast(sync: true);

  @override
  Future<int> initialize(TextSightOptions options, CaptureResolution resolution) async => 7;

  @override
  Future<void> start() => Future.value();

  @override
  Future<void> dispose() => previewPushes.close();

  @override
  Stream<TextSightCapture> get captures => const Stream.empty();

  @override
  Stream<TextSightSessionState> get sessionStates => const Stream.empty();

  @override
  Stream<PreviewGeometry> get previews => previewPushes.stream;
}
