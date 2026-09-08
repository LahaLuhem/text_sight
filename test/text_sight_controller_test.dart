// Tests
// ignore_for_file: prefer-match-file-name

import 'dart:async';
import 'dart:ui' show Locale;

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_sight/src/platform/text_sight_platform.dart';
import 'package:text_sight/text_sight.dart';

void main() {
  final lifecycle = BddFeature('TextSightController lifecycle');
  final sessionState = BddFeature('TextSightController session state');

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
      .scenario('pauseRecognition flips the recognizing intent and reaches the platform')
      .given('a started controller')
      .when('pauseRecognition is called')
      .then('isRecognizing drops, the platform is told, and listeners hear both changes')
      .run((_) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final controller = TextSightController();
        var notifications = 0;
        controller.addListener(() => notifications++);

        await controller.start();
        check(controller.isRecognizing).isTrue();

        await controller.pauseRecognition();

        check(controller.isRecognizing).isFalse();
        check(platform.log).contains('pauseRecognition');
        check(notifications).equals(2);
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

        await controller.updateOptions(
          TextSightOptions(darwin: DarwinOptions(recognitionLevel: level)),
        );

        check(platform.lastOptions?.darwin.recognitionLevel).equals(level);
        check(controller.options.darwin.recognitionLevel).equals(level);
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
          TextSightOptions(
            darwin: DarwinOptions(preferredLanguages: ctx.example.val('given') as Iterable<Locale>),
          ),
        );

        check(_tags(platform.lastOptions!.darwin.preferredLanguages)).deepEquals(kept);
        check(_tags(controller.options.darwin.preferredLanguages)).deepEquals(kept);
      });

  Bdd(lifecycle)
      .scenario('The languages list is snapshotted, so the caller cannot mutate it afterwards')
      .given('a controller built from a growable language list')
      .when('the caller appends to that same list')
      .then('the controller still reports the languages it was given')
      .run((ctx) {
        TextSightPlatform.instance = _RecordingPlatform();
        final languages = <Locale>[const Locale('en', 'US')];
        final controller = TextSightController(
          options: TextSightOptions(darwin: DarwinOptions(preferredLanguages: languages)),
        );

        languages.add(const Locale('fr'));

        check<Iterable<Object?>>(controller.options.darwin.preferredLanguages).length.equals(1);
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

  Bdd(sessionState)
      .scenario('Starting subscribes to session states before opening the camera')
      .given('a controller on a recording platform')
      .when('it is started')
      .then('the platform saw the listen before initialize, and start after')
      .run((_) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;

        await TextSightController().start();

        check(platform.log).deepEquals(['listen', 'initialize', 'start']);
      });

  Bdd(sessionState)
      .scenario('A reported state becomes the current value and notifies once')
      .given('a started controller, idle until native reports')
      .when('native reports <state>')
      .then('sessionState is <state> and listeners were told once')
      .example(val('state', const SessionActive()))
      .example(
        val('state', const SessionPaused(reason: SessionPauseReason.interrupted, details: 'call')),
      )
      .example(val('state', const SessionFailed(details: 'camera died')))
      .run((ctx) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final controller = TextSightController();
        await controller.start();
        check(controller.sessionState).equals(const SessionIdle());
        var notifications = 0;
        controller.addListener(() => notifications++);
        final state = ctx.example.val('state') as TextSightSessionState;

        await platform.report(state);

        check(controller.sessionState).equals(state);
        check(notifications).equals(1);
      });

  Bdd(sessionState)
      .scenario('An equal report is dropped, a different one is not')
      .given('a started controller that native has reported active')
      .when('native reports active again, then paused')
      .then('listeners hear the paused change only')
      .run((_) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final controller = TextSightController();
        await controller.start();
        await platform.report(const SessionActive());
        var notifications = 0;
        controller.addListener(() => notifications++);

        await platform.report(const SessionActive());
        check(notifications).equals(0);

        await platform.report(const SessionPaused(reason: SessionPauseReason.appBackgrounded));
        check(notifications).equals(1);
        check(controller.sessionState)
            .equals(const SessionPaused(reason: SessionPauseReason.appBackgrounded));
      });

  Bdd(sessionState)
      .scenario('Disposing returns to idle and stops listening')
      .given('a started controller that native has reported active')
      .when('it is disposed and native reports again')
      .then('sessionState is idle and no listener is notified')
      .run((_) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final controller = TextSightController();
        await controller.start();
        await platform.report(const SessionActive());
        var notifications = 0;
        controller
          ..addListener(() => notifications++)
          ..dispose();

        await platform.report(const SessionFailed());

        check(controller.sessionState).equals(const SessionIdle());
        check(notifications).equals(0);
        check(platform.states.hasListener).isFalse();
      });
}

/// The BCP-47 tags [locales] carry, in order.
List<String> _tags(Iterable<Locale> locales) => [
  for (final locale in locales) locale.toLanguageTag(),
];

/// Logs the controller's calls in order, can fail [initialize] on demand, and lets a test play
/// native by reporting session states.
final class _RecordingPlatform extends TextSightPlatform {
  new({this.failsToInitialize = false});

  final bool failsToInitialize;
  final log = <String>[];
  late final states = StreamController<TextSightSessionState>.broadcast(
    onListen: () => log.add('listen'),
  );
  var disposeCalls = 0;
  CaptureResolution? lastResolution;
  TextSightOptions? lastOptions;

  /// Reports [state] the way native would, and lets it reach the controller.
  Future<void> report(TextSightSessionState state) {
    states.add(state);

    return pumpEventQueue();
  }

  @override
  Future<int> initialize(TextSightOptions options, CaptureResolution resolution) async {
    log.add('initialize');
    if (failsToInitialize) throw StateError('no camera here');
    lastResolution = resolution;

    return 7;
  }

  @override
  Future<void> start() async => log.add('start');

  @override
  Future<void> pauseRecognition() async => log.add('pauseRecognition');

  @override
  Future<void> updateOptions(TextSightOptions options) async => lastOptions = options;

  @override
  Future<void> dispose() async => disposeCalls++;

  @override
  Stream<TextSightSessionState> get sessionStates => states.stream;
}
