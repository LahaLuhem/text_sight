import 'dart:io';

/// CLI flags shared by the benchmark entrypoints, so the orchestrator drives them uniformly:
/// `--iterations`, `--output`, `--git-sha`, `--package-version`, all required.
///
/// Hand-parsed: too small a surface to justify `package:args`.
final class ScenarioArgs {
  const new _({
    required this.iterations,
    required this.outputPath,
    required this.gitSha,
    required this.packageVersion,
  });

  /// Exits 64 (`EX_USAGE`) on a bad flag: nothing interactive is around to catch a throw.
  factory parse(List<String> argv) {
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

  final int iterations;

  final String outputPath;

  final String gitSha;

  final String packageVersion;

  /// Recorded per record: a change invalidates captured baselines.
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
