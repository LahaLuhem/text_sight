// Tests
// ignore_for_file: prefer-match-file-name

import 'dart:async';
import 'dart:ui' show Locale, Size;

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_sight/src/platform/text_sight_platform.dart';
import 'package:text_sight/src/states/preview_geometry.dart';
import 'package:text_sight/text_sight.dart';

void main() {
  final lifecycle = BddFeature('TextSightController lifecycle');
  final sessionState = BddFeature('TextSightController session state');
  final preview = BddFeature('TextSightController preview geometry');

  Bdd(lifecycle)
      .scenario('A failed initialize throws at the start() call site')
      .given('a platform whose initialize fails')
      .when('the controller is started')
      .then('start() throws that failure')
      .run((ctx) async {
        TextSightPlatform.instance = _RecordingPlatform(failsToInitialize: true);

        await check(TextSightController().start()).throws<StateError>();
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
        check(notifications).equals(1);

        await controller.pauseRecognition();

        check(controller.isRecognizing).isFalse();
        check(platform.log).contains('pauseRecognition');
        check(notifications).equals(2);
      });

  // Accurate, since the live default is fast and the getter would report that untouched.
  Bdd(lifecycle)
      .scenario('Updating options forwards them and republishes them')
      .given('a controller on a recording platform')
      .when('updateOptions is called with the accurate level')
      .then('the platform receives it, the getter reports it, and listeners are told once')
      .run((ctx) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final controller = TextSightController();
        var notifications = 0;
        controller.addListener(() => notifications++);

        await controller.updateOptions(
          const TextSightOptions(
            darwin: DarwinOptions(recognitionLevel: RecognitionLevel.accurate),
          ),
        );

        check(platform.lastOptions?.darwin.recognitionLevel).equals(RecognitionLevel.accurate);
        check(controller.options.darwin.recognitionLevel).equals(RecognitionLevel.accurate);
        check(notifications).equals(1);
      });

  Bdd(lifecycle)
      .scenario('Repeated languages collapse, and the order given survives')
      .given('a controller on a recording platform')
      .when('updateOptions is called with fr, en-US and fr again')
      .then('the platform and the getter both see fr, then en-US')
      .run((ctx) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final controller = TextSightController();

        await controller.updateOptions(
          const TextSightOptions(
            darwin: DarwinOptions(
              preferredLanguages: [Locale('fr'), Locale('en', 'US'), Locale('fr')],
            ),
          ),
        );

        check(_tags(platform.lastOptions!.darwin.preferredLanguages)).deepEquals(['fr', 'en-US']);
        check(_tags(controller.options.darwin.preferredLanguages)).deepEquals(['fr', 'en-US']);
      });

  Bdd(lifecycle)
      .scenario('The languages list is snapshotted, so the caller cannot mutate it afterwards')
      .given('a controller built from a growable language list')
      .when('the caller appends to that same list')
      .then('the controller still reports the languages it was given')
      .run((ctx) {
        TextSightPlatform.instance = _RecordingPlatform();
        // Not the default list, so a constructor that dropped the options couldn't pass.
        final languages = <Locale>[const Locale('fr')];
        final controller = TextSightController(
          options: TextSightOptions(darwin: DarwinOptions(preferredLanguages: languages)),
        );

        languages.add(const Locale('de'));

        check(_tags(controller.options.darwin.preferredLanguages)).deepEquals(['fr']);
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
      .when('native reports a paused state')
      .then('sessionState is that state and listeners were told once')
      .run((ctx) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final controller = TextSightController();
        await controller.start();
        check(controller.sessionState).equals(const SessionIdle());
        var notifications = 0;
        controller.addListener(() => notifications++);
        const state = SessionPaused(reason: SessionPauseReason.interrupted, details: 'call');

        platform.states.add(state);

        check(controller.sessionState).equals(state);
        check(notifications).equals(1);
      });

  Bdd(sessionState)
      .scenario('An equal report is dropped, a different one is not')
      .given('a started controller that native has reported interrupted')
      .when('native reports the same interruption again, then a backgrounding')
      .then('listeners hear the backgrounding only')
      .run((_) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final controller = TextSightController();
        await controller.start();
        // Built at runtime, as Pigeon decodes them, so only `==` can drop the repeat.
        // ignore: prefer_const_constructors
        platform.states.add(SessionPaused(reason: SessionPauseReason.interrupted, details: 'call'));
        var notifications = 0;
        controller.addListener(() => notifications++);

        // An equal report, but a separate instance.
        // ignore: prefer_const_constructors
        platform.states.add(SessionPaused(reason: SessionPauseReason.interrupted, details: 'call'));
        check(notifications).equals(0);

        platform.states.add(const SessionPaused(reason: SessionPauseReason.appBackgrounded));
        check(notifications).equals(1);
        check(controller.sessionState)
            .equals(const SessionPaused(reason: SessionPauseReason.appBackgrounded));
      });

  Bdd(sessionState)
      .scenario('Disposing returns to idle and stops listening')
      .given('a started controller that native has reported active')
      .when('it is disposed and native reports again')
      .then('sessionState is idle and nothing listens to native any more')
      .run((_) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final controller = TextSightController();
        await controller.start();
        platform.states.add(const SessionActive());
        check(controller.sessionState).equals(const SessionActive());

        controller.dispose();
        platform.states.add(const SessionFailed());

        check(controller.sessionState).equals(const SessionIdle());
        check(platform.states.hasListener).isFalse();
      });

  Bdd(preview)
      .scenario('Only geometry for the open texture becomes the preview')
      .given('a controller started on texture 7')
      .when('native reports geometry for texture <texture>')
      .then('the preview is that geometry: <shown>')
      .example(val('texture', 7), val('shown', true))
      .example(val('texture', 8), val('shown', false))
      .run((ctx) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final controller = TextSightController();
        await controller.start();
        final geometry = (
          textureId: ctx.example.val('texture') as int,
          size: const Size(960, 1280),
          quarterTurns: 1,
        );

        platform.previewPushes.add(geometry);

        check(controller.preview).equals(ctx.example.val('shown') as bool ? geometry : null);
      });

  Bdd(preview)
      .scenario('Geometry reported while the camera opens is kept')
      .given('a platform that reports geometry before initialize returns the texture id')
      .when('the controller is started')
      .then('the preview is that geometry')
      .run((_) async {
        const geometry = (textureId: 7, size: Size(960, 1280), quarterTurns: 1);
        TextSightPlatform.instance = _RecordingPlatform(previewOnOpen: geometry);
        final controller = TextSightController();

        await controller.start();

        check(controller.preview).equals(geometry);
      });

  Bdd(preview)
      .scenario('An equal report is dropped, a different one is not')
      .given('a started controller showing geometry for its texture')
      .when('native reports the same geometry, then a turned one')
      .then('listeners hear the turn only')
      .run((_) async {
        final platform = _RecordingPlatform();
        TextSightPlatform.instance = platform;
        final controller = TextSightController();
        await controller.start();
        const portrait = (textureId: 7, size: Size(960, 1280), quarterTurns: 1);
        platform.previewPushes.add(portrait);
        var notifications = 0;
        controller.addListener(() => notifications++);

        platform.previewPushes.add(portrait);
        check(notifications).equals(0);

        platform.previewPushes.add((textureId: 7, size: const Size(1280, 960), quarterTurns: 2));
        check(notifications).equals(1);
      });
}

/// The BCP-47 tags [locales] carry, in order.
List<String> _tags(Iterable<Locale> locales) => [
  for (final locale in locales) locale.toLanguageTag(),
];

/// Logs the controller's calls in order, can fail [initialize] on demand, and lets a test play
/// native by reporting session states and preview geometry.
final class _RecordingPlatform({
  final bool failsToInitialize = false,
  final PreviewGeometry? previewOnOpen,
}) extends TextSightPlatform {
  final log = <String>[];

  // Sync, so a report has reached the controller by the time `add` returns.
  late final states = StreamController<TextSightSessionState>.broadcast(
    onListen: () => log.add('listen'),
    sync: true,
  );
  final previewPushes = StreamController<PreviewGeometry>.broadcast(sync: true);
  var disposeCalls = 0;
  CaptureResolution? lastResolution;
  TextSightOptions? lastOptions;

  // At the test's end, not on dispose: a scenario reports after the controller has disposed.
  this {
    addTearDown(() => states.close());
    addTearDown(previewPushes.close);
  }

  @override
  Future<int> initialize(TextSightOptions options, CaptureResolution resolution) async {
    log.add('initialize');
    if (failsToInitialize) throw StateError('no camera here');
    lastResolution = resolution;
    final preview = previewOnOpen;
    if (preview != null) previewPushes.add(preview);

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

  @override
  Stream<PreviewGeometry> get previews => previewPushes.stream;
}
