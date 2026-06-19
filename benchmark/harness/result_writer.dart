import 'dart:convert';
import 'dart:io';

/// Writes codec-roundtrip results as a JSON array — one record per
/// (candidate, payload, iteration) — to a per-run output file.
///
/// Schema mirrors the sibling benchmark (header + `samples` + `summary`) with
/// the `candidate` / `payload` / `line_count` pivots this suite sweeps. One
/// writer per process: [open], one [writeRecord] per measurement, then [close].
final class ResultWriter {
  ResultWriter._(
    this._sink, {
    required this.benchmark,
    required this.sdkVersion,
    required this.packageVersion,
    required this.gitSha,
  });

  /// The benchmark name (e.g. `codec_roundtrip`).
  final String benchmark;

  /// Dart SDK version the run was captured on; a change invalidates baselines.
  final String sdkVersion;

  /// The package version under test.
  final String packageVersion;

  /// The git SHA of the working tree under test.
  final String gitSha;

  final IOSink _sink;
  var _firstRecord = true;

  /// Opens [outputPath] for writing and emits the JSON-array prefix.
  static Future<ResultWriter> open({
    required String outputPath,
    required String benchmark,
    required String sdkVersion,
    required String packageVersion,
    required String gitSha,
  }) async {
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    // Held for the writer's lifetime and closed by [close]; the lint can't
    // trace ownership across the factory boundary.
    // ignore: close_sinks
    final sink = file.openWrite()..write('[\n');

    return ResultWriter._(
      sink,
      benchmark: benchmark,
      sdkVersion: sdkVersion,
      packageVersion: packageVersion,
      gitSha: gitSha,
    );
  }

  /// Appends one record. [samples] holds the raw per-metric measurement
  /// arrays; [summary] holds pre-computed scalars (recomputable from samples).
  void writeRecord({
    required int iteration,
    required String candidate,
    required String payload,
    required int lineCount,
    required Map<String, List<num>> samples,
    required Map<String, num> summary,
  }) {
    final record = {
      'benchmark': benchmark,
      'candidate': candidate,
      'payload': payload,
      'line_count': lineCount,
      'iteration': iteration,
      'sdk_version': sdkVersion,
      'package_version': packageVersion,
      'git_sha': gitSha,
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'samples': samples,
      'summary': summary,
    };

    if (!_firstRecord) _sink.write(',\n');
    _sink.write(const JsonEncoder.withIndent('  ').convert(record));
    _firstRecord = false;
  }

  /// Writes the closing bracket and flushes the sink.
  Future<void> close() async {
    _sink.write('\n]\n');
    await _sink.flush();
    await _sink.close();
  }
}

/// Forces a young-gen GC by allocating, then dropping, memory pressure.
/// Imperfect (the VM may defer) but the canonical "clean slate before
/// measuring" hook. Call immediately before opening a measurement window.
void forceGc() {
  // ~8 MB of immediately-unreachable garbage to provoke a young-gen sweep.
  // ignore: unused_local_variable
  final pressure = List.generate(64, (_) => List<int>.filled(16384, 0));
}
