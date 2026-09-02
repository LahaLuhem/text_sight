import 'dart:io';

/// Builds one record in the shape `harness/result_writer.dart` writes, so device scenarios and the
/// AOT micros feed the same report layer. `candidate` is the recognition level, `payload` the page
/// profile; `platform` is additive, since this suite compares iOS against Android.
Map<String, Object?> buildLatencyRecord({
  required String benchmark,
  required String candidate,
  required String payload,
  required int lineCount,
  required int iteration,
  required List<int> latencyMicros,
  required int linesRecognized,
}) => {
  'benchmark': benchmark,
  'candidate': candidate,
  'payload': payload,
  'line_count': lineCount,
  'iteration': iteration,
  'platform': Platform.operatingSystem,
  'sdk_version': Platform.version.split(' ').first,
  'package_version': const String.fromEnvironment('PKG_VERSION', defaultValue: 'unknown'),
  'git_sha': const String.fromEnvironment('GIT_SHA', defaultValue: 'unknown'),
  'started_at': DateTime.now().toUtc().toIso8601String(),
  'samples': {'latency_microseconds': latencyMicros},
  'summary': {
    'latency_microseconds': percentile(latencyMicros, 50),
    'p95_latency_microseconds': percentile(latencyMicros, 95),
    'max_latency_microseconds': latencyMicros.reduce((a, b) => a > b ? a : b),
    'lines_recognized': linesRecognized,
  },
};

/// The [rank]th percentile of [values], nearest-rank. Median over mean: one GC pause skews a mean.
int percentile(List<int> values, int rank) {
  final sorted = [...values]..sort();
  final index = ((rank / 100) * (sorted.length - 1)).round().clamp(0, sorted.length - 1);

  return sorted[index];
}

/// Builds a record in `micro/codec_roundtrip.dart`'s exact shape, so device codec results feed the
/// same report path as the host ones. `platform` is the only addition.
Map<String, Object?> buildCodecRecord({
  required String candidate,
  required String payload,
  required int lineCount,
  required int iteration,
  required double encodeMicros,
  required double decodeMicros,
  required int wireBytes,
}) => {
  'benchmark': 'codec_roundtrip',
  'candidate': candidate,
  'payload': payload,
  'line_count': lineCount,
  'iteration': iteration,
  'platform': Platform.operatingSystem,
  'sdk_version': Platform.version.split(' ').first,
  'package_version': const String.fromEnvironment('PKG_VERSION', defaultValue: 'unknown'),
  'git_sha': const String.fromEnvironment('GIT_SHA', defaultValue: 'unknown'),
  'started_at': DateTime.now().toUtc().toIso8601String(),
  'samples': {
    'decode_microseconds': [decodeMicros],
    'encode_microseconds': [encodeMicros],
  },
  'summary': {
    'decode_microseconds': decodeMicros,
    'encode_microseconds': encodeMicros,
    'wire_bytes': wireBytes,
  },
};
