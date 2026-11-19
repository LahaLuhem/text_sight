import 'dart:io';

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:example/features/core/data/constants/core_constants.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:text_sight/text_sight.dart';

/// Runs the real recognizer over the bundled sample through both one-shot calls, on a device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final oneShot = BddFeature('Static one-shot recognition (on-device)');

  Bdd(oneShot)
      .scenario('recognizeImage recognizes a still from encoded bytes')
      .given('the bundled sample image bytes, already upright')
      .when('TextSight.recognizeImage is awaited on them')
      .then("the capture is upright, the sample's own size")
      .and('its recognized lines include <token>')
      .example(val('token', 'TextSight'))
      .run((ctx) async {
        final capture = await TextSight.recognizeImage(await _sampleBytes());

        _checkUprightSample(ctx, capture);
      });

  Bdd(oneShot)
      .scenario('recognizePath recognizes a still from a file path')
      .given('the bundled sample image written to a temp file, already upright')
      .when('TextSight.recognizePath is awaited on its path')
      .then("the capture is upright, the sample's own size")
      .and('its recognized lines include <token>')
      .example(val('token', 'TextSight'))
      .run((ctx) async {
        final capture = await TextSight.recognizePath(await _writeTempCopy(await _sampleBytes()));

        _checkUprightSample(ctx, capture);
      });
}

/// The bundled sample image's encoded bytes.
Future<Uint8List> _sampleBytes() async =>
    (await rootBundle.load(ConstMedia.sampleText.keyName)).buffer.asUint8List();

/// Writes [bytes] to a temp file and returns its path.
Future<String> _writeTempCopy(Uint8List bytes) async {
  final file = File('${Directory.systemTemp.path}/text_sight_it_sample.png');
  await file.writeAsBytes(bytes);

  return file.path;
}

/// Checks [capture] is the sample: its size, which a turn would swap, and a line with the token.
void _checkUprightSample(BddContext ctx, TextSightCapture capture) {
  check(capture.imageSize).equals(ConstMedia.sampleText.size!);

  // OCR may vary inter-word spacing, so normalize before matching the strongest token.
  final token = (ctx.example.val('token') as String).toLowerCase();
  final joined = capture.lines.map((line) => line.text).join(' ').toLowerCase();
  check(joined.replaceAll(' ', '')).contains(token);
}
