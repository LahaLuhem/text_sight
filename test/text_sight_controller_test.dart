// Tests
// ignore_for_file: prefer-match-file-name

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_sight/src/platform/text_sight_platform.dart';
import 'package:text_sight/text_sight.dart';

void main() {
  final lifecycle = BddFeature('TextSightController lifecycle');

  Bdd(lifecycle)
      .scenario('Disposing releases the native session after a failed start')
      .given('a controller whose start() failed, so it holds no texture id')
      .when('the controller is disposed')
      .then('the native session is released anyway')
      .run((ctx) async {
        final platform = _RecordingPlatform(failsToInitialize: true);
        TextSightPlatform.instance = platform;
        final controller = TextSightController();
        await check(controller.start()).throws<StateError>();

        controller.dispose();

        // The failed start is exactly the case where native may still own a live session: a hot
        // restart leaves one running and the fresh controller never gets its texture id.
        check(platform.disposeCalls).equals(1);
      });

  Bdd(lifecycle)
      .scenario('The chosen capture resolution reaches the platform')
      .given('a controller built with <resolution>')
      .when('it is started')
      .then('the platform is opened at <resolution>')
      .example(val('resolution', CaptureResolution.high))
      .example(val('resolution', CaptureResolution.low))
      .run((ctx) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final resolution = ctx.example.val('resolution') as CaptureResolution;

        await TextSightController(resolution: resolution).start();

        check(platform.lastResolution).equals(resolution);
      });

  Bdd(lifecycle)
      .scenario('Disposing releases the native session even when start was never called')
      .given('a controller that was built but never started')
      .when('the controller is disposed')
      .then('the native session is released anyway')
      .run((ctx) {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;

        TextSightController().dispose();

        check(platform.disposeCalls).equals(1);
      });
}

/// Counts the teardown calls the controller makes, and can fail [initialize] on demand.
final class _RecordingPlatform extends TextSightPlatform {
  new({this.failsToInitialize = false});

  final bool failsToInitialize;
  var disposeCalls = 0;
  CaptureResolution? lastResolution;

  @override
  Future<int> initialize(TextSightOptions options, CaptureResolution resolution) async {
    if (failsToInitialize) throw StateError('no camera here');
    lastResolution = resolution;

    return 7;
  }

  @override
  // No-op
  // ignore: no-empty-block
  Future<void> start() async {}

  @override
  Future<void> dispose() async => disposeCalls++;
}
