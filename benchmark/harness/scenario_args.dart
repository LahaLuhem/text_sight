import 'dart:io';

/// Parsed CLI flags shared by benchmark entrypoints so the (future) Python
/// orchestrator can drive them uniformly:
///
/// * `--iterations N` — required; the entrypoint loops `0..N-1`, emitting one
///   record set per iteration. Batching in one process amortises startup.
/// * `--output PATH` — required; JSON result file to write.
/// * `--git-sha SHA` — required; recorded in each record for traceability.
/// * `--package-version V` — required; recorded in each record.
///
/// Hand-parsed — the surface is too small to justify a `package:args` dep.
final class ScenarioArgs {
  const ScenarioArgs._({
    required this.iterations,
    required this.outputPath,
    required this.gitSha,
    required this.packageVersion,
  });

  /// Parses [argv]; exits with code 64 (`EX_USAGE`) on any parse failure —
  /// benchmarks are non-interactive, so there is no one to catch a throw.
  factory ScenarioArgs.parse(List<String> argv) {
    final flags = <String, String>{};
    for (var i = 0; i < argv.length; i++) {
      final arg = argv[i];
      if (!arg.startsWith('--')) _die('unexpected positional arg: $arg');
      if (i + 1 >= argv.length) _die('flag $arg missing value');
      flags[arg.replaceFirst('--', '')] = argv[++i];
    }

    final iterations = _requiredInt(flags, 'iterations');
    if (iterations <= 0) _die('--iterations must be >= 1, got: $iterations');

    return ScenarioArgs._(
      iterations: iterations,
      outputPath: _required(flags, 'output'),
      gitSha: _required(flags, 'git-sha'),
      packageVersion: _required(flags, 'package-version'),
    );
  }

  /// Iterations to run in this process invocation.
  final int iterations;

  /// Path to write the JSON result file to.
  final String outputPath;

  /// Git SHA of the working tree under test.
  final String gitSha;

  /// Package version under test.
  final String packageVersion;

  /// The Dart SDK version (`Platform.version`), recorded in each record. A
  /// change invalidates captured baselines.
  static String get sdkVersion => Platform.version.split(' ').first;

  static String _required(Map<String, String> flags, String name) {
    final value = flags[name];
    if (value == null || value.isEmpty) _die('missing required flag: --$name');

    return value;
  }

  static int _requiredInt(Map<String, String> flags, String name) {
    final raw = _required(flags, name);
    final parsed = int.tryParse(raw);
    if (parsed == null) _die('flag --$name expects an int, got: $raw');

    return parsed;
  }

  static Never _die(String message) {
    stderr.writeln('scenario_args: $message');
    exit(64);
  }
}
