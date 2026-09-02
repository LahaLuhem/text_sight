import 'dart:convert';
import 'dart:io';

/// Writes results as a JSON array, one record per (candidate, payload, iteration).
///
/// Schema mirrors the sibling suites: header, `samples`, `summary`. One writer per process:
/// [open], a [writeRecord] per measurement, then [close].
final class ResultWriter {
  new _(
    this._sink, {
    required this.benchmark,
    required this.sdkVersion,
    required this.packageVersion,
    required this.gitSha,
  });

  final String benchmark;

  /// A change invalidates captured baselines.
  final String sdkVersion;

  final String packageVersion;

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

  /// [samples] holds the raw arrays, [summary] the scalars derived from them.
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

/// Provokes a young-gen GC before a measurement window. Imperfect: the VM may defer.
void forceGc() {
  // Allocated only to be dropped, so the variable is meant to be unused.
  // ignore: unused_local_variable
  final pressure = List.generate(64, (_) => List<int>.filled(16384, 0));
}
