import 'dart:io';
import 'dart:ui' show Size;

/// One record in `harness/result_writer.dart`'s shape, so device runs feed the same report layer.
/// `candidate` is the level, `payload` the page profile. `platform` is additive.
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

/// The [rank]th percentile of [values], nearest-rank. Median over mean: a GC pause skews a mean.
int percentile(List<int> values, int rank) {
  final sorted = [...values]..sort();
  final index = ((rank / 100) * (sorted.length - 1)).round().clamp(0, sorted.length - 1);

  return sorted[index];
}

/// `micro/codec_roundtrip.dart`'s exact shape, so `report` renders device results unchanged.
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

/// A live-throughput record. `payload` is fixed at `live`: the input is whatever the camera sees.
Map<String, Object?> buildLiveRecord({
  required String candidate,
  required int iteration,
  required int windowMicros,
  required List<int> interArrivalMicros,
  required List<int> lineCounts,
  required Size? frameSize,
}) {
  final captures = lineCounts.length;
  final seconds = windowMicros / Duration.microsecondsPerSecond;

  return {
    'benchmark': 'live_throughput',
    'candidate': candidate,
    'payload': 'live',
    'line_count': lineCounts.isEmpty ? 0 : percentile(lineCounts, 50),
    'iteration': iteration,
    'platform': Platform.operatingSystem,
    'sdk_version': Platform.version.split(' ').first,
    'package_version': const String.fromEnvironment('PKG_VERSION', defaultValue: 'unknown'),
    'git_sha': const String.fromEnvironment('GIT_SHA', defaultValue: 'unknown'),
    'started_at': DateTime.now().toUtc().toIso8601String(),
    // `lines_median` rides along because throughput with nothing readable in frame means nothing.
    'samples': {'inter_arrival_microseconds': interArrivalMicros},
    'summary': {
      // Display-oriented, as delivered: 1080x1920 is a portrait 1080p frame.
      'frame_width': frameSize?.width.round() ?? 0,
      'frame_height': frameSize?.height.round() ?? 0,
      'capture_count': captures,
      'captures_per_second': seconds > 0 ? captures / seconds : 0,
      'inter_arrival_microseconds': interArrivalMicros.isEmpty
          ? 0
          : percentile(interArrivalMicros, 50),
      'p95_inter_arrival_microseconds': interArrivalMicros.isEmpty
          ? 0
          : percentile(interArrivalMicros, 95),
      'lines_median': lineCounts.isEmpty ? 0 : percentile(lineCounts, 50),
      'window_milliseconds': windowMicros ~/ 1000,
    },
  };
}
