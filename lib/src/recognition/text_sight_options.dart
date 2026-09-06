import 'dart:ui' show Rect;

import 'darwin_options.dart';

/// What the recognizer needs, shared by the live driver and the one-shot.
///
/// Only [roi] works the same everywhere. Everything Vision alone can do sits under [darwin], so a
/// setting that a platform ignores cannot be reached without naming that platform. Session-only
/// things like the torch live on the controller instead, since a still image has no such concept.
///
/// Two fields, so rebuilding one is a line. There is no `copyWith` here on purpose: clearing [roi]
/// would need a sentinel, and `TextSightOptions(darwin: options.darwin)` already says it plainly.
/// [DarwinOptions.copyWith] is where it earns its keep.
final class TextSightOptions {
  /// The scan-box recognition is restricted to: a normalized `[0, 1]`, top-left `Rect`, or `null`
  /// for the whole frame.
  ///
  /// Vision gets a true region. Android crops the still and, on the live path, keeps the lines whose
  /// centre lands inside.
  final Rect? roi;

  /// Settings only Apple Vision honours. Android ignores every one of them.
  final DarwinOptions darwin;

  /// Creates recognizer options. Every field has a live-oriented default.
  const new({this.roi, this.darwin = const DarwinOptions()});

  @override
  String toString() => 'TextSightOptions(roi: $roi, darwin: $darwin)';
}
