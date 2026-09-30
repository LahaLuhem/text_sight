import 'dart:io' show exit;

import 'package:pigeon/pigeon.dart';
// Pigeon doesn't export this flag, so a Pigeon release can drop it.
import 'package:pigeon/src/generator_tools.dart' show includeVersionInGeneratedWarning;

Future<void> main() async {
  // Without the version in the headers, a Pigeon bump that changes no code leaves no diff.
  includeVersionInGeneratedWarning = false;
  exit(await Pigeon.run(['--input', 'pigeons/text_sight.dart']));
}
