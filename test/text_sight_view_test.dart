// Tests
// ignore_for_file: prefer-match-file-name

import 'dart:async';
import 'dart:math' show pi;

import 'package:checks/checks.dart';
import 'package:flutter/rendering.dart' show ClipRectLayer;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_sight/src/capture/preview_geometry.dart';
import 'package:text_sight/src/platform/text_sight_platform.dart';
import 'package:text_sight/text_sight.dart';

// Plain `testWidgets`: bdd_framework scenarios get no `WidgetTester`.
void main() {
  testWidgets('The view mounts with no Directionality above it', (tester) async {
    final platform = await _pumpView(tester);
    platform.previewPushes.add(_portrait);
    await tester.pump();

    check(tester.takeException()).isNull();
    // The preview rendered, so the check above isn't vacuous.
    check(find.byType(Texture).evaluate()).length.equals(1);
  });

  testWidgets('The preview turns with native geometry, no capture needed', (tester) async {
    final platform = await _pumpView(tester);

    platform.previewPushes.add(_portrait);
    await tester.pump();
    check(_quarterTurns(tester)).equals(1);

    platform.previewPushes.add((textureId: 7, size: const Size(1280, 960), quarterTurns: 2));
    await tester.pump();
    check(_quarterTurns(tester)).equals(2);
  });

  const unlikeTheView = [
    (
      name: 'a tall frame fills the width',
      preview: _portrait,
      view: Size(300, 600),
      shown: Rect.fromLTWH(0, 100, 300, 400),
    ),
    (
      name: 'a wide frame fills the height',
      preview: (textureId: 7, size: Size(1280, 960), quarterTurns: 0),
      view: Size(800, 300),
      shown: Rect.fromLTWH(200, 0, 400, 300),
    ),
  ];
  for (final (:name, :preview, :view, :shown) in unlikeTheView) {
    testWidgets('By default the whole frame shows undistorted and centred: $name', (tester) async {
      final platform = await _pumpView(tester, size: view);
      platform.previewPushes.add(preview);
      await tester.pump();

      check(_shownRect(tester)).equals(shown);
    });
  }

  testWidgets("The overlay gets the shown frame's box", (tester) async {
    BoxConstraints? given;
    final platform = await _pumpView(
      tester,
      view: (controller) => TextSightView(
        controller: controller,
        overlayBuilder: (context, capture, constraints) {
          given = constraints;

          return const SizedBox.expand(key: _overlay);
        },
      ),
    );
    platform.previewPushes.add(_portrait);
    platform.capturePushes.add(const TextSightCapture(lines: [], imageSize: Size(960, 1280)));
    await tester.pump();

    final shown = _shownRect(tester);
    check(tester.getRect(find.byKey(_overlay))).equals(shown);
    check(given).equals(BoxConstraints.tight(shown.size));
  });

  testWidgets('Cover fills the view and clips what spills past it', (tester) async {
    const view = Size(600, 400);
    final platform = await _pumpView(
      tester,
      size: view,
      view: (controller) => TextSightView(controller: controller, fit: .cover),
    );
    platform.previewPushes.add(_portrait);
    await tester.pump();

    // Full width, spilling past the top and bottom alike.
    check(_shownRect(tester)).equals(const Rect.fromLTWH(0, -200, 600, 800));
    check(tester.layers.whereType<ClipRectLayer>().map((clip) => clip.clipRect))
        .contains(Offset.zero & view);
  });

  testWidgets('A view squeezed to nothing lays out without throwing', (tester) async {
    final platform = await _pumpView(tester, size: Size.zero);
    platform.previewPushes.add(_portrait);
    await tester.pump();

    check(tester.takeException()).isNull();
    // Past the placeholder, so the check above isn't vacuous.
    check(find.byType(Texture).evaluate()).length.equals(1);
  });
}

/// A 3:4 frame needing one turn, as an upright phone sends it.
const _portrait = (textureId: 7, size: Size(960, 1280), quarterTurns: 1);

const _overlay = ValueKey('overlay');

/// Mounts [view] (a plain one by default) top left, on a started controller native hasn't pushed
/// to yet.
Future<_PreviewPlatform> _pumpView(
  WidgetTester tester, {
  Size size = const Size(300, 600),
  TextSightView Function(TextSightController controller)? view,
}) async {
  final platform = _PreviewPlatform();
  TextSightPlatform.instance = platform;
  final controller = TextSightController();
  addTearDown(controller.dispose);
  await controller.start();
  await tester.pumpWidget(
    Align(
      alignment: .topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: view?.call(controller) ?? TextSightView(controller: controller),
      ),
    ),
  );

  return platform;
}

/// The clockwise quarter turns the texture is drawn at, read off where its top edge points.
int _quarterTurns(WidgetTester tester) {
  final texture = tester.renderObject<RenderBox>(find.byType(Texture));
  final topEdge =
      texture.localToGlobal(Offset(texture.size.width, 0)) - texture.localToGlobal(.zero);

  return (topEdge.direction / (pi / 2)).round() % 4;
}

/// Where the texture shows on screen, rounded off the float noise of a quarter turn.
Rect _shownRect(WidgetTester tester) {
  final shown = tester.getRect(find.byType(Texture));

  return Rect.fromLTRB(
    shown.left.roundToDouble(),
    shown.top.roundToDouble(),
    shown.right.roundToDouble(),
    shown.bottom.roundToDouble(),
  );
}

/// Sends only what a test pushes.
final class _PreviewPlatform() extends TextSightPlatform {
  // Sync, so one pump shows a push.
  final previewPushes = StreamController<PreviewGeometry>.broadcast(sync: true);
  final capturePushes = StreamController<TextSightCapture>.broadcast(sync: true);

  @override
  Future<int> initialize(TextSightOptions options, CaptureResolution resolution) async => 7;

  @override
  Future<void> start() => Future.value();

  @override
  Future<void> dispose() async {
    await previewPushes.close();
    await capturePushes.close();
  }

  @override
  Stream<TextSightCapture> get captures => capturePushes.stream;

  @override
  Stream<TextSightSessionState> get sessionStates => const Stream.empty();

  @override
  Stream<PreviewGeometry> get previews => previewPushes.stream;
}
