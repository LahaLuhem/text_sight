// Tests
// ignore_for_file: prefer-match-file-name

import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:example/features/core/data/constants/core_constants.dart';
import 'package:example/features/core/data/swaying_frames.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final drift = BddFeature('Swaying fallback frames');

  Bdd(drift)
      .scenario('Each tick is a different image, so recognition has something to track')
      .given('the bundled sample')
      .when('two frames are composed a moment apart')
      .then('they differ, and both keep the source size')
      .run((_) async {
        final sway = await _loadSample();

        final first = await sway.frameAt(Duration.zero);
        final later = await sway.frameAt(const Duration(milliseconds: 1200));

        check(_bytesDiffer(first, later)).isTrue();
        check(await _sizeOf(first)).equals(sway.size);
        check(await _sizeOf(later)).equals(sway.size);
      });

  Bdd(drift)
      .scenario('The drift never shows past the image edge')
      .given('a sweep of phases across the whole motion')
      .when('each frame is decoded')
      .then('every corner pixel is still opaque, so the overscale covers drift plus tilt')
      .run((_) async {
        final sway = await _loadSample();

        // A sweep, not one frame: the drift and tilt peak at different moments, and it is their
        // worst combination that would expose a corner.
        for (var step = 0; step < 40; step++) {
          final frame = await sway.frameAt(Duration(milliseconds: step * 500));

          check(
            await _cornerAlphas(frame),
            because: 'corner went transparent at step $step',
          ).deepEquals([255, 255, 255, 255]);
        }
      });
}

Future<SwayingFrames> _loadSample() async {
  final bytes = (await rootBundle.load(ConstMedia.a12PointText.keyName)).buffer.asUint8List();
  final sway = await SwayingFrames.fromBytes(bytes);
  addTearDown(sway.dispose);

  return sway;
}

bool _bytesDiffer(Uint8List a, Uint8List b) {
  if (a.length != b.length) return true;

  return List.generate(a.length, (i) => i).any((i) => a[i] != b[i]);
}

Future<ui.Size> _sizeOf(Uint8List png) async {
  final image = await _decode(png);
  try {
    return ui.Size(image.width.toDouble(), image.height.toDouble());
  } finally {
    image.dispose();
  }
}

/// The alpha channel at all four corners, clockwise from the top left.
Future<List<int>> _cornerAlphas(Uint8List png) async {
  final image = await _decode(png);
  try {
    final raw = await image.toByteData(); // rawRgba, the default
    if (raw == null) throw StateError('The frame could not be read back.');
    final pixels = raw.buffer.asUint8List();
    final (width, height) = (image.width, image.height);
    const alpha = 3;

    return [
      pixels[alpha],
      pixels[(width - 1) * 4 + alpha],
      pixels[((height - 1) * width + width - 1) * 4 + alpha],
      pixels[(height - 1) * width * 4 + alpha],
    ];
  } finally {
    image.dispose();
  }
}

Future<ui.Image> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();

  return frame.image;
}
