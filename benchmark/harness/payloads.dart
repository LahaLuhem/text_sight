// The profile enum is intentionally defined before the file's main type, for
// enum-first readability.
// ignore_for_file: prefer-match-file-name

import 'dart:math';

import 'bench_capture.dart';

/// Realistic OCR-frame profiles, parameterised by rough line count and text.
/// Each value is a representative use case the suite reports on.
enum PayloadProfile {
  /// A street sign or label: a few short lines.
  sign(minLines: 1, maxLines: 3, minTextLen: 3, maxTextLen: 14),

  /// A receipt: many short lines.
  receipt(minLines: 18, maxLines: 30, minTextLen: 4, maxTextLen: 28),

  /// A page of body text: many medium lines (the realistic stress case).
  document(minLines: 45, maxLines: 70, minTextLen: 20, maxTextLen: 60),

  /// Worst case: a very dense frame.
  dense(minLines: 100, maxLines: 140, minTextLen: 8, maxTextLen: 40);

  const PayloadProfile({
    required this.minLines,
    required this.maxLines,
    required this.minTextLen,
    required this.maxTextLen,
  });

  /// Inclusive lower bound on the generated line count.
  final int minLines;

  /// Inclusive upper bound on the generated line count.
  final int maxLines;

  /// Inclusive lower bound on per-line text length, in characters.
  final int minTextLen;

  /// Inclusive upper bound on per-line text length, in characters.
  final int maxTextLen;
}

/// Deterministic, seeded generators for benchmark capture payloads.
///
/// Seeds are fixed functions of the parameters, so every run on every machine
/// produces byte-identical payloads — a prerequisite for comparable numbers.
abstract final class Payloads {
  /// Line counts swept to chart how each candidate scales with frame size.
  static const sweepLineCounts = [1, 5, 10, 25, 50, 100];

  static const _confidenceChance = 0.9;
  static const _alphabet = 'abcdefghijklmnopqrstuvwxyz      ';

  /// Builds a fixed-size frame of [lineCount] lines (the scaling sweep).
  static BenchCapture sweep(int lineCount) =>
      _build(Random(lineCount + 0x51770000), lineCount, minTextLen: 12, maxTextLen: 24);

  /// Builds a frame matching [profile] (a realistic use case).
  static BenchCapture profile(PayloadProfile profile) {
    final rng = Random(profile.index + 0x51760000);
    final span = profile.maxLines - profile.minLines + 1;
    final lineCount = profile.minLines + rng.nextInt(span);

    return _build(rng, lineCount, minTextLen: profile.minTextLen, maxTextLen: profile.maxTextLen);
  }

  static BenchCapture _build(
    Random rng,
    int lineCount, {
    required int minTextLen,
    required int maxTextLen,
  }) {
    final textSpan = maxTextLen - minTextLen + 1;
    final lines = <BenchLine>[
      for (var i = 0; i < lineCount; i++)
        BenchLine(
          text: _text(rng, minTextLen + rng.nextInt(textSpan)),
          confidence: rng.nextDouble() < _confidenceChance ? rng.nextDouble() / 2.0 + 0.5 : null,
          left: rng.nextDouble() * 0.9,
          top: rng.nextDouble() * 0.95,
          width: rng.nextDouble() * 0.35 + 0.05,
          height: rng.nextDouble() * 0.04 + 0.01,
        ),
    ];

    return BenchCapture(imageWidth: 1080, imageHeight: 1920, quarterTurns: 0, lines: lines);
  }

  static String _text(Random rng, int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_alphabet[rng.nextInt(_alphabet.length)]);
    }

    return buffer.toString();
  }
}
