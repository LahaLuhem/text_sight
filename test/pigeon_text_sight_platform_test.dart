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
  final oneShot = BddFeature('TextSight one-shot recognition');
  final readiness = BddFeature('TextSight model readiness');

  Bdd(control)
      .scenario('Recognition level is sent as its Pigeon twin')
      .given('a platform talking to a mocked host')
      .when('updateRecognitionLevel is called with the <level> level')
      .then('the host receives the <twin> message')
      .example(val('level', RecognitionLevel.fast), val('twin', RecognitionLevelMessage.fast))
      .example(
        val('level', RecognitionLevel.accurate),
        val('twin', RecognitionLevelMessage.accurate),
      )
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        final call = _mockHostMethod(messenger, 'setRecognitionLevel');

        await platform.updateRecognitionLevel(ctx.example.val('level') as RecognitionLevel);

        check(call.payload).isA<Iterable<Object?>>().deepEquals(<Object?>[ctx.example.val('twin')]);
      });

  Bdd(control)
      .scenario('Torch state is forwarded to the host')
      .given('a platform talking to a mocked host')
      .when('updateTorchEnabled is called with <enabled>')
      .then('the host receives <enabled>')
      .example(val('enabled', true))
      .example(val('enabled', false))
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        final call = _mockHostMethod(messenger, 'setTorchEnabled');
        final enabled = ctx.example.val('enabled') as bool;

        await platform.updateTorchEnabled(enabled: enabled);

        check(call.payload).isA<Iterable<Object?>>().deepEquals(<Object?>[enabled]);
      });

  Bdd(control)
      .scenario('Locales are mapped to BCP-47 tags, in preference order')
      .given('a platform talking to a mocked host')
      .when('updateLanguages is called with <locales>')
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

        await platform.updateLanguages(ctx.example.val('locales') as Iterable<Locale>);

        check(call.payload).isA<Iterable<Object?>>().deepEquals(<Object?>[ctx.example.val('tags')]);
      });

  Bdd(control)
      .scenario('A region-of-interest rect is mapped to its twin')
      .given('a platform talking to a mocked host')
      .when('updateRegionOfInterest is called with the rect <roi>')
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

        await platform.updateRegionOfInterest(ctx.example.val('roi') as Rect);

        final roi = (call.payload! as List<Object?>).single! as RegionOfInterestMessage;
        check(roi.left).isCloseTo(ctx.example.val('left') as double, _floatTolerance);
        check(roi.top).isCloseTo(ctx.example.val('top') as double, _floatTolerance);
        check(roi.width).isCloseTo(ctx.example.val('width') as double, _floatTolerance);
        check(roi.height).isCloseTo(ctx.example.val('height') as double, _floatTolerance);
      });

  Bdd(control)
      .scenario('A null region-of-interest clears the scan box (whole frame)')
      .given('a platform talking to a mocked host')
      .when('updateRegionOfInterest is called with null')
      .then('the host receives null')
      .run((_) async {
        final platform = PigeonTextSightPlatform();
        final call = _mockHostMethod(messenger, 'setRegionOfInterest');

        await platform.updateRegionOfInterest(null);

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
      .and('the capture reports quarterTurns <quarterTurns>')
      .and('each decoded line matches the lines table (text, confidence, box)')
      .example(val('imageWidth', 1920), val('imageHeight', 1080), val('quarterTurns', 1))
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        final imageWidth = ctx.example.val('imageWidth') as int;
        final imageHeight = ctx.example.val('imageHeight') as int;
        final quarterTurns = ctx.example.val('quarterTurns') as int;
        final lineRows = ctx.table('lines').rows;

        _mockCaptures(messenger, <Object?>[
          <Object?, Object?>{
            'imageWidth': imageWidth.toDouble(),
            'imageHeight': imageHeight.toDouble(),
            'quarterTurns': quarterTurns,
            'lines': [for (final lineRow in lineRows) _wireLine(lineRow)],
          },
        ]);

        final capture = await platform.captures.first;

        check(capture.imageSize).equals(Size(imageWidth.toDouble(), imageHeight.toDouble()));
        check(capture.quarterTurns).equals(quarterTurns);
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
      .and('quarterTurns defaults to 0 when the frame omits it')
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
        // quarterTurns is absent from this frame map → defaults to 0.
        check(capture.quarterTurns).equals(0);
      });

  Bdd(oneShot)
      .scenario('recognizeImage sends the bytes and mapped options, then decodes the reply')
      .given('a host that replies with a still-image capture sized <imageWidth> by <imageHeight>')
      .when('recognizeImage is called with bytes and the <level> level')
      .then('the host receives the bytes and an options twin carrying <twin>')
      .and('the decoded capture is sized <imageWidth> by <imageHeight>, quarterTurns 0, one line')
      .example(
        val('level', RecognitionLevel.accurate),
        val('twin', RecognitionLevelMessage.accurate),
        val('imageWidth', 800),
        val('imageHeight', 600),
      )
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        final imageWidth = ctx.example.val('imageWidth') as int;
        final imageHeight = ctx.example.val('imageHeight') as int;
        final bytes = Uint8List.fromList(const [0, 1, 2, 3, 4]);
        final call = _mockHostMethod(
          messenger,
          'recognizeImage',
          reply: _stillReply(imageWidth, imageHeight),
        );

        final capture = await platform.recognizeImage(
          bytes,
          TextSightOptions(level: ctx.example.val('level') as RecognitionLevel),
        );

        final payload = call.payload! as List<Object?>;
        check<Iterable<int>>(payload.first! as Uint8List).deepEquals(bytes);
        check(
          (payload[1]! as TextSightOptionsMessage).level,
        ).equals(ctx.example.val('twin') as RecognitionLevelMessage);
        check(capture.imageSize).equals(Size(imageWidth.toDouble(), imageHeight.toDouble()));
        check(capture.quarterTurns).equals(0);
        check<Iterable<Object?>>(capture.lines).length.equals(1);
        check(capture.lines.single.text).equals('STILL');
      });

  Bdd(oneShot)
      .scenario('recognizePath sends the path and mapped options, then decodes the reply')
      .given('a host that replies with a still-image capture sized <imageWidth> by <imageHeight>')
      .when('recognizePath is called with the path <path>')
      .then('the host receives <path> and an accurate options twin')
      .and('the decoded capture is sized <imageWidth> by <imageHeight> with quarterTurns 0')
      .example(val('path', '/tmp/sign.jpg'), val('imageWidth', 1024), val('imageHeight', 768))
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        final path = ctx.example.val('path') as String;
        final imageWidth = ctx.example.val('imageWidth') as int;
        final imageHeight = ctx.example.val('imageHeight') as int;
        final call = _mockHostMethod(
          messenger,
          'recognizePath',
          reply: _stillReply(imageWidth, imageHeight),
        );

        final capture = await platform.recognizePath(
          path,
          const TextSightOptions(level: RecognitionLevel.accurate),
        );

        final payload = call.payload! as List<Object?>;
        check(payload.first).equals(path);
        check(
          (payload[1]! as TextSightOptionsMessage).level,
        ).equals(RecognitionLevelMessage.accurate);
        check(capture.imageSize).equals(Size(imageWidth.toDouble(), imageHeight.toDouble()));
        check(capture.quarterTurns).equals(0);
      });

  Bdd(oneShot)
      .scenario('TextSight.recognizeImage defaults the recognition level to accurate')
      .given('the default platform instance talking to a mocked host')
      .when('TextSight.recognizeImage is called without options')
      .then('the host receives an options twin whose level is accurate')
      .run((_) async {
        final call = _mockHostMethod(messenger, 'recognizeImage', reply: _stillReply(1, 1));

        await TextSight.recognizeImage(Uint8List.fromList(const [9]));

        final options = (call.payload! as List<Object?>)[1]! as TextSightOptionsMessage;
        check(options.level).equals(RecognitionLevelMessage.accurate);
      });

  Bdd(readiness)
      .scenario('ensureModelReady decodes a ready terminal reply')
      .given('a host that replies with a ready state')
      .when('ensureModelReady is awaited')
      .then('it resolves to ModelReady')
      .run((_) async {
        final platform = PigeonTextSightPlatform();
        _mockHostMethod(messenger, 'ensureModelReady', reply: <String, Object?>{'state': 'ready'});

        final state = await platform.ensureModelReady();

        check(state).isA<ModelReady>();
      });

  Bdd(readiness)
      .scenario('ensureModelReady decodes an unavailable reply, mapping the reason tag')
      .given('a host that replies unavailable with <wireReason> and <details>')
      .when('ensureModelReady is awaited')
      .then('it resolves to ModelUnavailable carrying <reason> and <details>')
      .example(
        val('wireReason', 'playServicesUnavailable'),
        val('reason', ModelUnavailableReason.playServicesUnavailable),
        val('details', 'Play Services missing'),
      )
      .example(
        val('wireReason', 'downloadFailed'),
        val('reason', ModelUnavailableReason.downloadFailed),
        val('details', null),
      )
      .example(
        // An unknown tag is treated defensively as a failed download (we own both ends).
        val('wireReason', 'somethingUnknown'),
        val('reason', ModelUnavailableReason.downloadFailed),
        val('details', null),
      )
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        _mockHostMethod(
          messenger,
          'ensureModelReady',
          reply: <String, Object?>{
            'state': 'unavailable',
            'reason': ctx.example.val('wireReason'),
            'details': ctx.example.val('details'),
          },
        );

        final state = await platform.ensureModelReady();

        final unavailable = check(state).isA<ModelUnavailable>();
        unavailable
            .has((s) => s.reason, 'reason')
            .equals(ctx.example.val('reason') as ModelUnavailableReason);
        unavailable.has((s) => s.details, 'details').equals(ctx.example.val('details') as String?);
      });

  Bdd(readiness)
      .scenario('The readiness stream decodes a downloading event with its progress')
      .given('the host emits a downloading event at <progress>')
      .when('the platform receives the first readiness state')
      .then('it is ModelDownloading carrying <progress>')
      .example(val('progress', 0.42))
      .example(val('progress', null))
      .run((ctx) async {
        final platform = PigeonTextSightPlatform();
        _mockReadiness(messenger, <Object?>[
          <Object?, Object?>{'state': 'downloading', 'progress': ctx.example.val('progress')},
        ]);

        final state = await platform.modelReadiness.first;

        check(state)
            .isA<ModelDownloading>()
            .has((s) => s.progress, 'progress')
            .equals(ctx.example.val('progress') as double?);
      });

  Bdd(readiness)
      .scenario('The readiness stream decodes a ready event')
      .given('the host emits a ready event')
      .when('the platform receives the first readiness state')
      .then('it is ModelReady')
      .run((_) async {
        final platform = PigeonTextSightPlatform();
        _mockReadiness(messenger, <Object?>[
          <Object?, Object?>{'state': 'ready'},
        ]);

        final state = await platform.modelReadiness.first;

        check(state).isA<ModelReady>();
      });

  Bdd(readiness)
      .scenario('TextSightModel.ensureReady resolves through the default platform')
      .given('the default platform instance talking to a mocked host that replies ready')
      .when('TextSightModel.ensureReady is awaited')
      .then('it resolves to ModelReady')
      .run((_) async {
        _mockHostMethod(messenger, 'ensureModelReady', reply: <String, Object?>{'state': 'ready'});

        final state = await TextSightModel.ensureReady();

        check(state).isA<ModelReady>();
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
  const channel = EventChannel('com.lahaluhem.text_sight/captures');
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

/// Mocks the readiness `EventChannel` to emit [states] in order, then close.
void _mockReadiness(TestDefaultBinaryMessenger messenger, List<Object?> states) {
  const channel = EventChannel('com.lahaluhem.text_sight/readiness');
  messenger.setMockStreamHandler(
    channel,
    MockStreamHandler.inline(
      onListen: (arguments, events) {
        states.forEach(events.success);
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

/// A one-shot host reply: the same captures wire map a single upright line would
/// produce (`quarterTurns` 0), sized [imageWidth] by [imageHeight].
Map<String, Object?> _stillReply(int imageWidth, int imageHeight) => <String, Object?>{
  'imageWidth': imageWidth.toDouble(),
  'imageHeight': imageHeight.toDouble(),
  'quarterTurns': 0,
  'lines': <Object?>[
    <String, Object?>{
      'text': 'STILL',
      'confidence': 0.9,
      'left': 0.1,
      'top': 0.1,
      'width': 0.5,
      'height': 0.1,
      'elements': null,
    },
  ],
};
