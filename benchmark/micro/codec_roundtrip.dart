/// Encode and decode CPU plus wire size for one recognition frame, across transport candidates.
///
/// Pure Dart, so it bounds the upside of a transport change and nothing more: native inference and
/// real frame latency dominate end-to-end. Decode is the headline, since in production only the
/// decode runs on the Dart UI isolate.
library;

// An entrypoint with only private helpers, so no public class matches the file name.
// ignore_for_file: prefer-match-file-name

import 'dart:io';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';

import '../harness/bench_capture.dart';
import '../harness/capture_codec.dart';
import '../harness/payloads.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

typedef _Case = ({String payload, int lineCount, BenchCapture capture});

/// One row of the end-of-run stdout summary.
typedef _Row = ({String payload, int lineCount, String candidate, double decodeUs, int bytes});

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);
  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    benchmark: 'codec_roundtrip',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );

  final cases = [
    for (final count in Payloads.sweepLineCounts)
      (payload: 'sweep', lineCount: count, capture: Payloads.sweep(count)),
    for (final profile in PayloadProfile.values) _profileCase(profile),
  ];

  final rows = <_Row>[];
  for (var i = 0; i < args.iterations; i++) {
    for (final benchCase in cases) {
      for (final codec in allCodecs) {
        forceGc();
        final encoded = codec.encode(benchCase.capture);
        final encodeUs = _measure(_EncodeBench(codec, benchCase.capture));
        final decodeUs = _measure(_DecodeBench(codec, encoded));

        writer.writeRecord(
          iteration: i,
          candidate: codec.name,
          payload: benchCase.payload,
          lineCount: benchCase.lineCount,
          samples: {
            'decode_microseconds': [decodeUs],
            'encode_microseconds': [encodeUs],
          },
          summary: {
            'decode_microseconds': decodeUs,
            'encode_microseconds': encodeUs,
            'wire_bytes': encoded.length,
          },
        );
        rows.add((
          payload: benchCase.payload,
          lineCount: benchCase.lineCount,
          candidate: codec.name,
          decodeUs: decodeUs,
          bytes: encoded.length,
        ));
      }
    }
  }

  await writer.close();
  _printSummary(rows);
}

/// Generates the capture once, then derives its label fields.
_Case _profileCase(PayloadProfile profile) {
  final capture = Payloads.profile(profile);

  return (payload: profile.name, lineCount: capture.lines.length, capture: capture);
}

/// Shorter than `benchmark_harness`'s fixed 2 s, which would cost ~2 s per cell across a
/// 100-cell matrix. The outer iterations supply the distribution.
const _warmupMillis = 100;
const _measureMillis = 500;

/// Microseconds per `run()` over one window, warming caches first.
double _measure(BenchmarkBase bench) {
  bench.setup();
  BenchmarkBase.measureFor(bench.exercise, _warmupMillis);
  final score = BenchmarkBase.measureFor(bench.exercise, _measureMillis);
  bench.teardown();

  return score;
}

/// Checksums the result so the optimiser cannot drop the decode as dead code.
final class _DecodeBench extends BenchmarkBase {
  new(this._codec, this._bytes) : super('decode');

  final CaptureCodec _codec;
  final Uint8List _bytes;
  var _sink = 0;

  @override
  void exercise() => run();

  @override
  void run() => _sink += _codec.decode(_bytes).lines.length;

  @override
  void teardown() {
    if (_sink < 0) throw StateError('unreachable');
  }
}

/// Checksums the byte length, same dead-code guard as [_DecodeBench].
final class _EncodeBench extends BenchmarkBase {
  new(this._codec, this._capture) : super('encode');

  final CaptureCodec _codec;
  final BenchCapture _capture;
  var _sink = 0;

  @override
  void exercise() => run();

  @override
  void run() => _sink += _codec.encode(_capture).length;

  @override
  void teardown() {
    if (_sink < 0) throw StateError('unreachable');
  }
}

/// A compact median table for reading the run without the Python report layer.
void _printSummary(List<_Row> rows) {
  final buffer = StringBuffer()
    ..writeln()
    ..writeln('codec_roundtrip: median decode µs / wire bytes per (payload, lines)')
    ..writeln('Δ vs map_std baseline; negative = smaller / faster')
    ..writeln();

  final groups = <String, List<_Row>>{};
  for (final row in rows) {
    groups.putIfAbsent('${row.payload}|${row.lineCount}', () => []).add(row);
  }

  for (final entry in groups.entries) {
    final decodeByCandidate = <String, List<double>>{};
    final bytesByCandidate = <String, int>{};
    for (final row in entry.value) {
      decodeByCandidate.putIfAbsent(row.candidate, () => []).add(row.decodeUs);
      bytesByCandidate[row.candidate] = row.bytes;
    }

    final baseDecode = _median(decodeByCandidate['map_std'] ?? const []);
    final baseBytes = bytesByCandidate['map_std'] ?? 0;
    buffer.writeln(entry.key.replaceFirst('|', '  ·  lines='));
    for (final codec in allCodecs) {
      final decode = _median(decodeByCandidate[codec.name] ?? const []);
      final bytes = bytesByCandidate[codec.name] ?? 0;
      final decodeCell = '${decode.toStringAsFixed(2)}µs'.padLeft(11);
      final bytesCell = '${bytes}B'.padLeft(8);
      final decodePct = _pct(baseDecode == 0 ? 0.0 : (decode - baseDecode) / baseDecode * 100);
      final bytesPct = _pct(baseBytes == 0 ? 0.0 : (bytes - baseBytes) / baseBytes * 100);
      buffer.writeln(
        '  ${codec.name.padRight(11)}$decodeCell$bytesCell   '
        'dec ${decodePct.padLeft(6)}   bytes ${bytesPct.padLeft(6)}',
      );
    }
    buffer.writeln();
  }

  stdout.write(buffer.toString());
}

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];

  return (sorted[mid - 1] + sorted[mid]) / 2.0;
}

String _pct(double value) {
  if (value == 0) return '0%';
  final sign = value > 0 ? '+' : '';

  return '$sign${value.toStringAsFixed(0)}%';
}
