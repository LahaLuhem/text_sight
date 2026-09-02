import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../harness/bench_capture.dart';
import '../../harness/capture_codec.dart';
import '../../harness/payloads.dart';
import 'support/bench_record.dart';

/// The codec micro-benchmark on phone silicon, checking a claim the host numbers cannot: decode as a
/// fraction of a frame budget. Same payloads and schema as `micro/codec_roundtrip.dart`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('codec encode and decode on device', (tester) async {
    // Imported from harness/, so a `receipt` here is byte-identical to the micro's.
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

/// Median microseconds per call, batched. Hand-rolled because `benchmark_harness`'s window is tuned
/// for a host.
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
