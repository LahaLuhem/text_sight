import 'package:flutter/cupertino.dart' show CupertinoColors, CupertinoDynamicColor;
import 'package:flutter/widgets.dart' show BuildContext, Color;
import 'package:material_ui/material_ui.dart' show Colors;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// Confidence-tier palette for the demo, resolved per platform.
///
/// Each colour returns the Material hue on Android and the matching
/// `CupertinoColors.system*` colour on iOS, picked via [platformValue]
/// (`defaultTargetPlatform`, the same dispatch as `context.platformIcon`) and then run
/// through [CupertinoDynamicColor.resolve] so the iOS system colours follow light/dark
/// mode. Recognized lines are tinted by confidence: [green] high, [orange] medium,
/// [red] low, [blueGrey] when the engine supplies none.
abstract final class ConstTheme {
  /// Alpha for a confidence-tinted chip fill.
  static const confidenceFillAlpha = 0.15;

  /// Confidence at or above which a line is treated as high (green).
  static const highConfidence = 0.8;

  /// Confidence at or above which a line is treated as medium (orange); below is low (red).
  static const mediumConfidence = 0.5;

  /// The tier colour for a line [value] in `[0, 1]`: [green] high, [orange] medium,
  /// [red] low, [blueGrey] when the engine supplied none (`null`).
  static Color confidence(BuildContext context, double? value) => switch (value) {
    null => blueGrey(context),
    final v when v >= highConfidence => green(context),
    final v when v >= mediumConfidence => orange(context),
    _ => red(context),
  };

  /// High confidence — [Colors.green] / [CupertinoColors.systemGreen].
  static Color green(BuildContext context) =>
      _resolve(context, material: Colors.green, cupertino: CupertinoColors.systemGreen);

  /// Medium confidence — [Colors.orange] / [CupertinoColors.systemOrange].
  static Color orange(BuildContext context) =>
      _resolve(context, material: Colors.orange, cupertino: CupertinoColors.systemOrange);

  /// Low confidence — [Colors.red] / [CupertinoColors.systemRed].
  static Color red(BuildContext context) =>
      _resolve(context, material: Colors.red, cupertino: CupertinoColors.systemRed);

  /// Unknown confidence (the engine supplied none) — [Colors.blueGrey] /
  /// [CupertinoColors.systemGrey].
  static Color blueGrey(BuildContext context) =>
      _resolve(context, material: Colors.blueGrey, cupertino: CupertinoColors.systemGrey);

  static Color _resolve(
    BuildContext context, {
    required Color material,
    required Color cupertino,
  }) => CupertinoDynamicColor.resolve(
    platformValue(material: material, cupertino: cupertino),
    context,
  );
}
