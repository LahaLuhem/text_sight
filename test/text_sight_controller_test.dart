// Tests
// ignore_for_file: prefer-match-file-name

import 'dart:ui' show Locale;

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
      .scenario('Updating options forwards them and republishes them')
      .given('a controller on a recording platform')
      .when('updateOptions is called with the <level> level')
      .then('the platform receives it, the getter reports it, and listeners are told once')
      .example(val('level', RecognitionLevel.accurate))
      .example(val('level', RecognitionLevel.fast))
      .run((ctx) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final controller = TextSightController();
        final level = ctx.example.val('level') as RecognitionLevel;
        var notifications = 0;
        controller.addListener(() => notifications++);

        await controller.updateOptions(TextSightOptions(level: level));

        check(platform.lastOptions?.level).equals(level);
        check(controller.options.level).equals(level);
        check(notifications).equals(1);
      });

  Bdd(lifecycle)
      .scenario('Repeated languages collapse, and the order given survives')
      .given('a controller on a recording platform')
      .when('updateOptions is called with <given>')
      .then('the platform and the getter both see <kept>')
      .example(
        val('given', const [Locale('fr'), Locale('en', 'US'), Locale('fr')]),
        val('kept', const ['fr', 'en-US']),
      )
      .example(
        val('given', const [Locale('en', 'US'), Locale('en', 'US')]),
        val('kept', const ['en-US']),
      )
      .run((ctx) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final controller = TextSightController();
        final kept = ctx.example.val('kept') as List<String>;

        await controller.updateOptions(
          TextSightOptions(languages: ctx.example.val('given') as Iterable<Locale>),
        );

        check(_tags(platform.lastOptions!.languages)).deepEquals(kept);
        check(_tags(controller.options.languages)).deepEquals(kept);
      });

  Bdd(lifecycle)
      .scenario('The languages list is snapshotted, so the caller cannot mutate it afterwards')
      .given('a controller built from a growable language list')
      .when('the caller appends to that same list')
      .then('the controller still reports the languages it was given')
      .run((ctx) {
        TextSightPlatform.instance = _RecordingPlatform();
        final languages = <Locale>[const Locale('en', 'US')];
        final controller = TextSightController(options: TextSightOptions(languages: languages));

        languages.add(const Locale('fr'));

        check<Iterable<Object?>>(controller.options.languages).length.equals(1);
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

/// The BCP-47 tags [locales] carry, in order.
List<String> _tags(Iterable<Locale> locales) => [
  for (final locale in locales) locale.toLanguageTag(),
];

/// Counts the teardown calls the controller makes, and can fail [initialize] on demand.
final class _RecordingPlatform extends TextSightPlatform {
  new({this.failsToInitialize = false});

  final bool failsToInitialize;
  var disposeCalls = 0;
  CaptureResolution? lastResolution;
  TextSightOptions? lastOptions;

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
  Future<void> updateOptions(TextSightOptions options) async => lastOptions = options;

  @override
  Future<void> dispose() async => disposeCalls++;
}
