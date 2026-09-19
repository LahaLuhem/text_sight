import 'dart:io';

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:text_sight/text_sight.dart';

/// On-device smoke test: runs the real recognizer over the bundled sample and checks each entry
/// point hands back a populated, upright capture.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final oneShot = BddFeature('Static one-shot recognition (on-device)');

  Bdd(oneShot)
      .scenario('recognizeImage recognizes a still from encoded bytes')
      .given('the bundled sample image bytes, already upright')
      .when('TextSight.recognizeImage is awaited on them')
      .then('the capture is upright (quarterTurns <quarterTurns>), sized <width> by <height>')
      .and('its recognized lines include <token>')
      .example(
        val('quarterTurns', 0),
        val('width', 1000),
        val('height', 620),
        val('token', 'TextSight'),
      )
      .run((ctx) async {
        final capture = await TextSight.recognizeImage(await _sampleBytes());

        _checkUprightSample(ctx, capture);
      });

  Bdd(oneShot)
      .scenario('recognizePath recognizes a still from a file path')
      .given('the bundled sample image written to a temp file, already upright')
      .when('TextSight.recognizePath is awaited on its path')
      .then('the capture is upright (quarterTurns <quarterTurns>), sized <width> by <height>')
      .and('its recognized lines include <token>')
      .example(
        val('quarterTurns', 0),
        val('width', 1000),
        val('height', 620),
        val('token', 'TextSight'),
      )
      .run((ctx) async {
        final capture = await TextSight.recognizePath(await _writeTempCopy(await _sampleBytes()));

        _checkUprightSample(ctx, capture);
      });
}

const _asset = 'assets/sample_text.png';

/// The bundled sample image's encoded bytes.
Future<Uint8List> _sampleBytes() async => (await rootBundle.load(_asset)).buffer.asUint8List();

/// Writes [bytes] to a temp file and returns its path, exercising the path entry point.
Future<String> _writeTempCopy(Uint8List bytes) async {
  final file = File('${Directory.systemTemp.path}/text_sight_it_sample.png');
  await file.writeAsBytes(bytes);

  return file.path;
}

/// Checks [capture] against the current scenario's example row.
void _checkUprightSample(BddContext ctx, TextSightCapture capture) {
  check(capture.quarterTurns).equals(ctx.example.val('quarterTurns') as int);
  check(capture.imageSize).equals(
    Size(
      (ctx.example.val('width') as int).toDouble(),
      (ctx.example.val('height') as int).toDouble(),
    ),
  );

  // OCR may vary inter-word spacing, so normalize before matching the strongest token.
  final token = (ctx.example.val('token') as String).toLowerCase();
  final joined = capture.lines.map((line) => line.text).join(' ').toLowerCase();
  check<Iterable<Object?>>(capture.lines).isNotEmpty();
  check(joined.replaceAll(' ', '')).contains(token);
}
