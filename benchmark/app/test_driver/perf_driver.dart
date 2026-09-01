// perf_driver is a flutter_driver driver (run via `flutter drive`), not a `flutter test` file, so it
// does not follow the `_test.dart` naming convention.
// ignore_for_file: prefer-correct-test-file-name

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Writes what a scenario accumulated in `binding.reportData` to the `--dart-define=OUTPUT` path,
/// as a JSON array matching `harness/result_writer.dart`.
Future<void> main() => integrationDriver(
  // The 20-minute default turns a wedged device into a half-hour stall.
  timeout: const Duration(minutes: 5),
  responseDataCallback: (data) async {
    if (data == null) return;

    final outputPath = data['output_path'] as String?;
    final records = data['records'];
    if (outputPath == null || outputPath.isEmpty || records == null) return;

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(records));
  },
);
