// Tests
// ignore_for_file: prefer-match-file-name

import 'dart:ui' show Locale, Rect, Size;

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_sight/src/platform/messages.g.dart';
import 'package:text_sight/src/platform/pigeon_text_sight_platform.dart';
import 'package:text_sight/text_sight.dart';

/// Tolerance for round-tripped `Rect` extents: `Rect` stores L/T/R/B and derives
/// width/height (`right - left`), so they carry sub-epsilon float error.
const _floatTolerance = 1e-9;

void main() {
  final messenger = TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;

  final control = BddFeature('TextSight control channel');
  final captures = BddFeature('TextSight captures stream');

  Bdd(control)
      .scenario('Recognition level is sent as its Pigeon twin')
      .given('a platform talking to a mocked host')
      .when('setRecognitionLevel is called with the <level> level')
      .then('the host receives the <twin> message')
      .example(val('level', RecognitionLevel.fast), val('twin', RecognitionLevelMessage.fast))
      .example(
        val('level', RecognitionLevel.accurate),
        val('twin', RecognitionLevelMessage.accurate),
      )
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        final call = _mockHostMethod(messenger, 'setRecognitionLevel');

        await platform.setRecognitionLevel(ctx.example.val('level') as RecognitionLevel);

        check(call.payload).isA<Iterable<Object?>>().deepEquals(<Object?>[ctx.example.val('twin')]);
      });

  Bdd(control)
      .scenario('Torch state is forwarded to the host')
      .given('a platform talking to a mocked host')
      .when('setTorchEnabled is called with <enabled>')
      .then('the host receives <enabled>')
      .example(val('enabled', true))
      .example(val('enabled', false))
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        final call = _mockHostMethod(messenger, 'setTorchEnabled');
        final enabled = ctx.example.val('enabled') as bool;

        await platform.setTorchEnabled(enabled: enabled);

        check(call.payload).isA<Iterable<Object?>>().deepEquals(<Object?>[enabled]);
      });

  Bdd(control)
      .scenario('Locales are mapped to BCP-47 tags, in preference order')
      .given('a platform talking to a mocked host')
      .when('setLanguages is called with <locales>')
      .then('the host receives <tags>')
      .example(
        val('locales', const [
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          Locale('en', 'US'),
        ]),
        val('tags', const ['zh-Hans', 'en-US']),
      )
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        final call = _mockHostMethod(messenger, 'setLanguages');

        await platform.setLanguages(ctx.example.val('locales') as Iterable<Locale>);

        check(call.payload).isA<Iterable<Object?>>().deepEquals(<Object?>[ctx.example.val('tags')]);
      });

  Bdd(control)
      .scenario('A region-of-interest rect is mapped to its twin')
      .given('a platform talking to a mocked host')
      .when('setRegionOfInterest is called with the rect <roi>')
      .then('the host receives a twin with <left>, <top>, <width>, <height>')
      .example(
        val('roi', const Rect.fromLTWH(0.1, 0.2, 0.3, 0.4)),
        val('left', 0.1),
        val('top', 0.2),
        val('width', 0.3),
        val('height', 0.4),
      )
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        final call = _mockHostMethod(messenger, 'setRegionOfInterest');

        await platform.setRegionOfInterest(ctx.example.val('roi') as Rect);

        final roi = (call.payload! as List<Object?>).single! as RegionOfInterestMessage;
        check(roi.left).isCloseTo(ctx.example.val('left') as double, _floatTolerance);
        check(roi.top).isCloseTo(ctx.example.val('top') as double, _floatTolerance);
        check(roi.width).isCloseTo(ctx.example.val('width') as double, _floatTolerance);
        check(roi.height).isCloseTo(ctx.example.val('height') as double, _floatTolerance);
      });

  Bdd(control)
      .scenario('A null region-of-interest clears the scan box (whole frame)')
      .given('a platform talking to a mocked host')
      .when('setRegionOfInterest is called with null')
      .then('the host receives null')
      .run((_) async {
        final platform = PigeonTextSightPlatform();
        final call = _mockHostMethod(messenger, 'setRegionOfInterest');

        await platform.setRegionOfInterest(null);

        check(call.payload).isA<Iterable<Object?>>().deepEquals(<Object?>[null]);
      });

  Bdd(control)
      .scenario('Initialize sends the mapped options and returns the texture id')
      .given('a host that replies with texture id <textureId>')
      .when('initialize is called with the <level> level and <locales>')
      .then('the host receives options carrying <twin> and <tags>, with no roi')
      .and('initialize returns <textureId>')
      .example(
        val('level', RecognitionLevel.fast),
        val('twin', RecognitionLevelMessage.fast),
        val('locales', const [Locale.fromSubtags(languageCode: 'en', countryCode: 'US')]),
        val('tags', const ['en-US']),
        val('textureId', 7),
      )
      .example(
        val('level', RecognitionLevel.accurate),
        val('twin', RecognitionLevelMessage.accurate),
        val('locales', const [Locale('en'), Locale('fr')]),
        val('tags', const ['en', 'fr']),
        val('textureId', 1),
      )
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        final textureId = ctx.example.val('textureId') as int;
        final call = _mockHostMethod(messenger, 'initialize', reply: textureId);

        final returned = await platform.initialize(
          TextSightOptions(
            level: ctx.example.val('level') as RecognitionLevel,
            languages: ctx.example.val('locales') as Iterable<Locale>,
          ),
        );

        final options = (call.payload! as List<Object?>).single! as TextSightOptionsMessage;
        check(options.level).equals(ctx.example.val('twin') as RecognitionLevelMessage);
        check<Iterable<Object?>>(
          options.languages,
        ).deepEquals(ctx.example.val('tags') as List<String>);
        check(options.roi).isNull();
        check(returned).equals(textureId);
      });

  Bdd(control)
      .scenario('Start, stop, and dispose complete against the host')
      .given('a platform with mocked start, stop, and dispose')
      .when('each lifecycle call is awaited')
      .then('every future completes without error')
      .run((_) async {
        final platform = PigeonTextSightPlatform();
        _mockHostMethod(messenger, 'start');
        _mockHostMethod(messenger, 'stop');
        _mockHostMethod(messenger, 'dispose');

        await check(platform.start()).completes();
        await check(platform.stop()).completes();
        await check(platform.dispose()).completes();
      });

  Bdd(captures)
      .scenario('A frame decodes into a capture with normalized lines')
      .given('the camera emits one frame sized <imageWidth> by <imageHeight>')
      .and('the frame carries these recognized lines')
      .table(
        'lines',
        row(
          val('text', 'HELLO'),
          val('confidence', 0.97),
          val('left', 0.1),
          val('top', 0.2),
          val('width', 0.3),
          val('height', 0.05),
        ),
        row(
          val('text', 'WORLD'),
          val('confidence', null),
          val('left', 0.05),
          val('top', 0.6),
          val('width', 0.4),
          val('height', 0.05),
        ),
      )
      .when('the platform receives the first capture')
      .then('the capture size is <imageWidth> by <imageHeight>')
      .and('each decoded line matches the lines table (text, confidence, box)')
      .example(val('imageWidth', 1920), val('imageHeight', 1080))
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        final imageWidth = ctx.example.val('imageWidth') as int;
        final imageHeight = ctx.example.val('imageHeight') as int;
        final lineRows = ctx.table('lines').rows;

        _mockCaptures(messenger, <Object?>[
          <Object?, Object?>{
            'imageWidth': imageWidth.toDouble(),
            'imageHeight': imageHeight.toDouble(),
            'lines': [for (final lineRow in lineRows) _wireLine(lineRow)],
          },
        ]);

        final capture = await platform.captures.first;

        check(capture.imageSize).equals(Size(imageWidth.toDouble(), imageHeight.toDouble()));
        check<Iterable<Object?>>(capture.lines).length.equals(lineRows.length);

        for (final (index, expected) in lineRows.indexed) {
          final line = capture.lines[index];
          check(line.text).equals(expected.val('text') as String);
          check(line.confidence).equals(expected.val('confidence') as double?);
          check(line.boundingBox).equals(
            Rect.fromLTWH(
              expected.val('left') as double,
              expected.val('top') as double,
              expected.val('width') as double,
              expected.val('height') as double,
            ),
          );
        }
      });

  Bdd(captures)
      .scenario('A frame with no lines decodes to an empty capture')
      .given('the camera emits one frame sized <imageWidth> by <imageHeight> with no lines')
      .when('the platform receives the first capture')
      .then('the capture has no lines, sized <imageWidth> by <imageHeight>')
      .example(val('imageWidth', 640), val('imageHeight', 480))
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        final imageWidth = ctx.example.val('imageWidth') as int;
        final imageHeight = ctx.example.val('imageHeight') as int;

        _mockCaptures(messenger, <Object?>[
          <Object?, Object?>{
            'imageWidth': imageWidth.toDouble(),
            'imageHeight': imageHeight.toDouble(),
            'lines': <Object?>[],
          },
        ]);

        final capture = await platform.captures.first;

        check<Iterable<Object?>>(capture.lines).isEmpty();
        check(capture.imageSize).equals(Size(imageWidth.toDouble(), imageHeight.toDouble()));
      });
}

/// Records the decoded argument payload a mocked host method receives.
final class _HostCall {
  Object? payload;
}

/// Installs a mock handler for the Pigeon `@HostApi` [method], recording the
/// decoded argument payload it receives into the returned [_HostCall] and
/// replying with the success envelope wrapping [reply].
_HostCall _mockHostMethod(TestDefaultBinaryMessenger messenger, String method, {Object? reply}) {
  final call = _HostCall();
  final channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.text_sight.TextSightHostApi.$method',
    TextSightHostApi.pigeonChannelCodec,
  );
  messenger.setMockDecodedMessageHandler<Object?>(channel, (message) {
    call.payload = message;

    return Future<Object?>.syncValue(<Object?>[reply]);
  });
  addTearDown(() => messenger.setMockDecodedMessageHandler<Object?>(channel, null));

  return call;
}

/// Mocks the captures `EventChannel` to emit [frames] in order, then close.
void _mockCaptures(TestDefaultBinaryMessenger messenger, List<Object?> frames) {
  const channel = EventChannel('com.LahaLuhem.text_sight/captures');
  messenger.setMockStreamHandler(
    channel,
    MockStreamHandler.inline(
      onListen: (arguments, events) {
        frames.forEach(events.success);
        events.endOfStream();
      },
    ),
  );
  addTearDown(() => messenger.setMockStreamHandler(channel, null));
}

/// Builds one per-frame wire-line map from a `lines` table [row].
Map<String, Object?> _wireLine(BddTableValues row) => <String, Object?>{
  'text': row.val('text'),
  'confidence': row.val('confidence'),
  'left': row.val('left'),
  'top': row.val('top'),
  'width': row.val('width'),
  'height': row.val('height'),
  'elements': null,
};
