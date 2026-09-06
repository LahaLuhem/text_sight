import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:text_sight/text_sight.dart';

import 'support/bench_record.dart';
import 'support/text_page.dart';

/// Round-trip latency of `TextSight.recognizeImage`, by page profile, level and language
/// correction. One number covers decode, inference, native encode and the channel hop, so it is
/// what a call costs an app, not inference time. Both knobs are no-ops on Android, so its four
/// series should land on top of each other.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('one-shot recognition latency by profile and level', (tester) async {
    final records = <Map<String, Object?>>[];

    for (final profile in PageProfile.values) {
      // Rendered outside the timed region: only the recognition call is measured.
      final page = await renderPage(profile);
      expect(page.inkPixels, greaterThan(0), reason: 'the ${profile.name} page rendered blank');
      debugPrint(
        'PAGE ${profile.name} lines=${page.lineCount} ${page.width}x${page.height} '
        'font=${page.fontSize.toStringAsFixed(1)} bytes=${page.pngBytes.length} '
        'ink=${page.inkPixels}',
      );

      for (final level in RecognitionLevel.values) {
        // Correction rides its own axis now: it trades latency against accuracy independently of
        // the level, and what it costs on `fast` is the open question.
        for (final corrected in const [false, true]) {
          final options = TextSightOptions(
            darwin: DarwinOptions(recognitionLevel: level, usesLanguageCorrection: corrected),
          );
          final candidate = corrected ? '${level.name}+corrected' : level.name;
          // Warm up, so lazy first-call setup stays out of the samples.
          await TextSight.recognizeImage(page.pngBytes, options: options);

          for (var iteration = 0; iteration < _iterations; iteration++) {
            final latencies = <int>[];
            var lines = 0;

            for (var call = 0; call < _callsPerRecord; call++) {
              final stopwatch = Stopwatch()..start();
              final capture = await TextSight.recognizeImage(page.pngBytes, options: options);
              latencies.add(stopwatch.elapsedMicroseconds);
              lines = capture.lines.length;
            }

            records.add(
              buildLatencyRecord(
                benchmark: 'one_shot_latency',
                candidate: candidate,
                payload: profile.name,
                lineCount: page.lineCount,
                iteration: iteration,
                latencyMicros: latencies,
                linesRecognized: lines,
              ),
            );
            debugPrint(
              'BENCH one_shot ${profile.name}/$candidate lines=$lines '
              'p50=${percentile(latencies, 50)}us p95=${percentile(latencies, 95)}us',
            );
          }
        }
      }
    }

    binding.reportData = {'output_path': _outputPath, 'records': records};

    // Zero recognitions for one combination is data (see the class docs). Zero everywhere means the
    // harness itself is broken, which is worth failing on.
    expect(
      records.any((record) => _linesOf(record) > 0),
      isTrue,
      reason: 'nothing was recognized on any page at any level',
    );
  });
}

int _linesOf(Map<String, Object?> record) {
  final summary = record['summary']! as Map<String, Object?>;

  return summary['lines_recognized']! as int;
}

/// Repeats of the whole sweep, mirroring the micros' `--iterations`.
const _iterations = int.fromEnvironment('ITERATIONS', defaultValue: 3);

/// Small on purpose: the full sweep has to finish inside the driver's 5-minute cap.
const _callsPerRecord = 3;

const _outputPath = String.fromEnvironment('OUTPUT');
