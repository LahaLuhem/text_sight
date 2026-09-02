import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../harness/bench_capture.dart';
import '../../harness/capture_codec.dart';
import '../../harness/payloads.dart';
import 'support/bench_record.dart';

/// The codec micro-benchmark, on the phone instead of a laptop.
///
/// Same payloads and same candidates as `micro/codec_roundtrip.dart`, reached by relative import,
/// so a `receipt` here is byte-identical to a `receipt` there. It exists to check one published
/// claim: decode is quoted as a fraction of a 60 fps frame budget, but the committed numbers come
/// from a development machine, and a phone CPU is slower.
///
/// Records match the micro's schema exactly, so `run.py report` renders these unchanged. Point it
/// at a separate `--out`, or it overwrites the host charts.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('codec encode and decode on device', (tester) async {
    final cases = [for (final profile in PayloadProfile.values) _profileCase(profile)];
    final records = <Map<String, Object?>>[];

    for (var iteration = 0; iteration < _iterations; iteration++) {
      for (final benchCase in cases) {
        for (final codec in allCodecs) {
          final encoded = codec.encode(benchCase.capture);
          final encodeMicros = _perOperationMicros(() => codec.encode(benchCase.capture));
          final decodeMicros = _perOperationMicros(() => codec.decode(encoded));

          records.add(
            buildCodecRecord(
              candidate: codec.name,
              payload: benchCase.payload,
              lineCount: benchCase.lineCount,
              iteration: iteration,
              encodeMicros: encodeMicros,
              decodeMicros: decodeMicros,
              wireBytes: encoded.lengthInBytes,
            ),
          );
        }
      }
    }

    binding.reportData = {'output_path': _outputPath, 'records': records};

    final headline = records.where(
      (record) => record['candidate'] == 'map_std' && record['payload'] == 'dense',
    );
    expect(headline, isNotEmpty, reason: 'the shipped candidate never got measured');
    debugPrint('BENCH codec_on_device ${Platform.operatingSystem} ${records.length} records');
  });
}

/// Median microseconds per call across [_batches] batches of [_repsPerBatch], after a warm-up.
///
/// Hand-rolled rather than `benchmark_harness`: its window is tuned for a host, and a batch median
/// is what the micro reports too, so the two stay comparable.
double _perOperationMicros(void Function() operation) {
  for (var warmUp = 0; warmUp < _repsPerBatch; warmUp++) {
    operation();
  }

  final perBatch = <double>[];
  for (var batch = 0; batch < _batches; batch++) {
    final stopwatch = Stopwatch()..start();
    for (var rep = 0; rep < _repsPerBatch; rep++) {
      operation();
    }
    perBatch.add(stopwatch.elapsedMicroseconds / _repsPerBatch);
  }
  perBatch.sort();

  return perBatch[perBatch.length ~/ 2];
}

({String payload, int lineCount, BenchCapture capture}) _profileCase(PayloadProfile profile) {
  final capture = Payloads.profile(profile);

  return (payload: profile.name, lineCount: capture.lines.length, capture: capture);
}

const _iterations = int.fromEnvironment('ITERATIONS', defaultValue: 3);

/// Odd batch count so the median is a real sample, not an average of two.
const _batches = 11;
const _repsPerBatch = 200;

const _outputPath = String.fromEnvironment('OUTPUT');
