/// Micro-benchmark: encode + decode CPU and wire size of one recognition frame
/// across transport candidates (`capture_codec.dart`), swept over frame size
/// and realistic OCR profiles (`payloads.dart`).
///
/// Scope — the only perf-relevant slice measurable in pure Dart. Native ML
/// inference and real on-device frame latency are out of scope and dominate
/// end-to-end; these numbers bound the *upside* of a transport change, no more.
/// Decode is the headline: in production only the decode runs on the Dart UI
/// isolate per frame (the encode happens natively).
///
/// `exercise()` is overridden to a single `run()` so `measure()` returns
/// microseconds per one encode / decode, not per the harness default of ten.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';

import '../harness/bench_capture.dart';
import '../harness/capture_codec.dart';
import '../harness/payloads.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

/// One payload to measure every candidate against.
typedef _Case = ({String payload, int lineCount, BenchCapture capture});

/// One measurement row, accumulated for the end-of-run stdout summary.
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

  final cases = <_Case>[];
  for (final count in Payloads.sweepLineCounts) {
    cases.add((payload: 'sweep', lineCount: count, capture: Payloads.sweep(count)));
  }
  for (final profile in PayloadProfile.values) {
    final capture = Payloads.profile(profile);
    cases.add((payload: profile.name, lineCount: capture.lines.length, capture: capture));
  }

  final rows = <_Row>[];
  for (var i = 0; i < args.iterations; i++) {
    for (final benchCase in cases) {
      for (final codec in allCodecs) {
        forceGc();
        final encoded = codec.encode(benchCase.capture);
        final encodeUs = _EncodeBench(codec, benchCase.capture).measure();
        final decodeUs = _DecodeBench(codec, encoded).measure();

        writer.writeRecord(
          iteration: i,
          candidate: codec.name,
          payload: benchCase.payload,
          lineCount: benchCase.lineCount,
          samples: <String, List<num>>{
            'decode_microseconds': <num>[decodeUs],
            'encode_microseconds': <num>[encodeUs],
          },
          summary: <String, num>{
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

/// Decodes a fixed encoded buffer per `run()`. The result feeds a checksum so
/// the optimiser cannot eliminate the decode as dead code.
final class _DecodeBench extends BenchmarkBase {
  _DecodeBench(this._codec, this._bytes) : super('decode');

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

/// Encodes a fixed capture per `run()`, checksumming the byte length for the
/// same dead-code-elimination guard as [_DecodeBench].
final class _EncodeBench extends BenchmarkBase {
  _EncodeBench(this._codec, this._capture) : super('encode');

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

/// Prints a compact median table to stdout — a Phase-0 standalone view until
/// the Python `report` layer (charts + SUMMARY.md) lands.
void _printSummary(List<_Row> rows) {
  final buffer = StringBuffer()
    ..writeln()
    ..writeln('codec_roundtrip — median decode µs / wire bytes per (payload, lines)')
    ..writeln('Δ vs map_std baseline; negative = smaller / faster')
    ..writeln();

  final groups = <String, List<_Row>>{};
  for (final row in rows) {
    groups.putIfAbsent('${row.payload}|${row.lineCount}', () => <_Row>[]).add(row);
  }

  for (final entry in groups.entries) {
    final decodeByCandidate = <String, List<double>>{};
    final bytesByCandidate = <String, int>{};
    for (final row in entry.value) {
      decodeByCandidate.putIfAbsent(row.candidate, () => <double>[]).add(row.decodeUs);
      bytesByCandidate[row.candidate] = row.bytes;
    }

    final baseDecode = _median(decodeByCandidate['map_std'] ?? const <double>[]);
    final baseBytes = bytesByCandidate['map_std'] ?? 0;
    buffer.writeln(entry.key.replaceFirst('|', '  ·  lines='));
    for (final codec in allCodecs) {
      final decode = _median(decodeByCandidate[codec.name] ?? const <double>[]);
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
