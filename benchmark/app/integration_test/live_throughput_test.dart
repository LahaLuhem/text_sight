import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:text_sight/text_sight.dart';

import 'support/bench_record.dart';

/// Recognized frames per second, per level. Directional: the numbers depend on what the camera sees.
/// Only recognized frames are visible from Dart, so the drop ratio needs native counters.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live recognition throughput by level', (tester) async {
    final controller = TextSightController();
    addTearDown(controller.dispose);

    // Nothing can pre-grant this: `flutter drive` uninstalls the app afterwards, taking the grant.
    final permission = await _awaitCameraPermission(controller);
    expect(
      permission,
      CameraPermissionStatus.granted,
      reason: 'camera permission is $permission after waiting $_permissionWindow',
    );

    final records = <Map<String, Object?>>[];

    // Same four series as the one-shot, so the two reports line up.
    final sweep = [
      for (final level in RecognitionLevel.values)
        for (final corrected in const [false, true]) (level: level, corrected: corrected),
    ];

    // Burn the device in before measuring anything. Whichever candidate went first read ~75%
    // high, and running the sweep backwards showed the gap followed the position rather than the
    // candidate. Measured on a Sony XQ-BQ52: it holds ~8 captures/s for about 40 s, drops off a
    // thermal cliff, then sits flat at ~4.5 for the rest of the run. So this window has to outlast
    // the cliff, not just the first cold frames.
    await controller.start();
    await Future<void>.delayed(_warmUpWindow);
    await controller.stop();

    // With that burned off, a gap that survives here is the candidate. `--reverse` re-runs the
    // sweep backwards, which is how to confirm that.
    for (final entry in _reverseSweep ? sweep.reversed : sweep) {
      await controller.updateOptions(
        TextSightOptions(
          darwin: DarwinOptions(
            recognitionLevel: entry.level,
            usesLanguageCorrection: entry.corrected,
          ),
        ),
      );
      final candidate = entry.corrected ? '${entry.level.name}+corrected' : entry.level.name;

      for (var iteration = 0; iteration < _iterations; iteration++) {
        final arrivals = <int>[];
        final lineCounts = <int>[];
        // What `.high` actually hands over is device-dependent, so record it rather than assume.
        Size? frameSize;
        final elapsed = Stopwatch();
        var previousMicros = 0;

        final subscription = controller.captures.listen((capture) {
          // Window only: settle captures would inflate a rate measured over the window alone.
          if (!elapsed.isRunning) return;

          final now = elapsed.elapsedMicroseconds;
          if (previousMicros > 0) arrivals.add(now - previousMicros);
          previousMicros = now;
          lineCounts.add(capture.lines.length);
          frameSize = capture.imageSize;
        });

        await controller.start();
        // The first frames carry camera warm-up.
        await Future<void>.delayed(_settleWindow);
        elapsed.start();
        await Future<void>.delayed(_measureWindow);
        elapsed.stop();
        await controller.stop();
        await subscription.cancel();

        records.add(
          buildLiveRecord(
            candidate: candidate,
            iteration: iteration,
            windowMicros: elapsed.elapsedMicroseconds,
            interArrivalMicros: arrivals,
            lineCounts: lineCounts,
            frameSize: frameSize,
          ),
        );
        debugPrint(
          'BENCH live $candidate captures=${lineCounts.length} '
          'window=${elapsed.elapsedMilliseconds}ms',
        );
      }
    }

    binding.reportData = {'output_path': _outputPath, 'records': records};

    expect(
      records.any((record) => _capturesOf(record) > 0),
      isTrue,
      reason: 'no captures at any level, so the camera delivered nothing',
    );
  });
}

int _capturesOf(Map<String, Object?> record) {
  final summary = record['summary']! as Map<String, Object?>;

  return summary['capture_count']! as int;
}

/// Prompts, then polls until something grants it: adb on Android, a human tap on iOS.
Future<CameraPermissionStatus> _awaitCameraPermission(TextSightController controller) async {
  var status = await controller.checkCameraPermission();
  if (status == CameraPermissionStatus.granted) return status;

  // Not awaited: on iOS it only completes once the dialog is answered.
  unawaited(controller.requestCameraPermission());

  final deadline = DateTime.now().add(_permissionWindow);
  while (status != CameraPermissionStatus.granted && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    status = await controller.checkCameraPermission();
  }

  return status;
}

const _permissionWindow = Duration(seconds: 45);
const _iterations = int.fromEnvironment('ITERATIONS', defaultValue: 2);

/// Runs the sweep backwards, to separate a real candidate difference from an order effect.
const _reverseSweep = bool.fromEnvironment('REVERSE_SWEEP');
const _settleWindow = Duration(seconds: 2);
const _warmUpWindow = Duration(seconds: 45);
const _measureWindow = Duration(seconds: 8);
const _outputPath = String.fromEnvironment('OUTPUT');
