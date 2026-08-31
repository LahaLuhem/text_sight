import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:text_sight/src/platform/text_sight_platform.dart';
import 'package:text_sight/text_sight.dart';

/// Measures how long the platform thread is unavailable while a large `recognizeImage` payload
/// crosses the control channel. That is the slice `@TaskQueue(serialBackgroundThread)` moves: the
/// channel's message decode currently runs on the platform thread before the handler is invoked.
///
/// The probe is `checkCameraPermission`, a synchronous host method, so its round trip is dominated
/// by how long it waits for the platform thread. Run it before and after the annotation and diff.
///
/// Not isolated: Dart-isolate scheduling and the engine's own hop are inside the measurement. It
/// bounds the effect rather than attributing it precisely.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('platform-thread stall during a large one-shot payload', (tester) async {
    const payloadMiB = 8;
    const bursts = 40;
    final payload = Uint8List(payloadMiB * 1024 * 1024);

    // Undecodable on purpose: this times the channel hop, not ML inference.
    await _warmUp(payload);

    final idle = await _probeFor(const Duration(milliseconds: 600), busy: null);
    final loaded = await _probeFor(
      null,
      busy: () async {
        for (var i = 0; i < bursts; i++) {
          await _expectDecodeFailure(payload);
        }
      },
    );

    _report('idle', idle);
    _report('loaded ($bursts x ${payloadMiB}MiB)', loaded);
    expect(loaded, isNotEmpty, reason: 'no probe samples were collected under load');
  });
}

/// One probe round trip: a synchronous host call, so it queues behind whatever holds the platform
/// thread.
Future<void> _ping() => TextSightPlatform.instance.checkCameraPermission();

Future<void> _warmUp(Uint8List payload) async {
  await _ping();
  await _expectDecodeFailure(payload);
}

Future<void> _expectDecodeFailure(Uint8List payload) async {
  try {
    await TextSight.recognizeImage(payload);
    fail('a non-image payload should not decode');
  } on Object {
    // Expected: the bytes crossed the channel, which is the part being timed.
  }
}

/// Samples ping latency, either for [window] or until [busy] finishes.
Future<List<int>> _probeFor(Duration? window, {required Future<void> Function()? busy}) async {
  final samples = <int>[];
  var running = true;

  final probe = () async {
    while (running) {
      final stopwatch = Stopwatch()..start();
      await _ping();
      samples.add(stopwatch.elapsedMicroseconds);
    }
  }();

  if (busy != null) {
    await busy();
  } else {
    await Future<void>.delayed(window!);
  }
  running = false;
  await probe;

  return samples;
}

void _report(String label, List<int> samples) {
  final sorted = [...samples]..sort();
  final p50 = sorted[sorted.length ~/ 2];
  final p95 = sorted[(sorted.length * 95) ~/ 100];
  final max = sorted.last;
  // ignore: avoid_print, this is the benchmark's only output channel on device.
  print('BENCH $label n=${sorted.length} p50=${p50}us p95=${p95}us max=${max}us');
}
