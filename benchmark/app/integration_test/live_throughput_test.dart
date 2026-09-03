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

    for (final level in RecognitionLevel.values) {
      await controller.updateRecognitionLevel(level);

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
            candidate: level.name,
            iteration: iteration,
            windowMicros: elapsed.elapsedMicroseconds,
            interArrivalMicros: arrivals,
            lineCounts: lineCounts,
            frameSize: frameSize,
          ),
        );
        debugPrint(
          'BENCH live ${level.name} captures=${lineCounts.length} '
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
const _settleWindow = Duration(seconds: 2);
const _measureWindow = Duration(seconds: 8);
const _outputPath = String.fromEnvironment('OUTPUT');
