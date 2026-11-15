import 'package:flutter/cupertino.dart' show CupertinoColors, CupertinoDynamicColor;
import 'package:flutter/widgets.dart' show BuildContext, Color;
import 'package:material_ui/material_ui.dart' show Colors;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// The demo's colours: the Material hue on Android, and on iOS the matching system colour, which
/// follows light and dark.
abstract final class ConstTheme() {
  /// Alpha for a confidence-tinted chip fill.
  static const confidenceFillAlpha = 0.15;

  /// Confidence at or above which a line is treated as high (green).
  static const highConfidence = 0.8;

  /// Confidence at or above which a line is treated as medium (orange). Below is low (red).
  static const mediumConfidence = 0.5;

  /// The tier colour for a line [value] in `[0, 1]`: [green] high, [orange] medium, [red] low.
  static Color confidence(BuildContext context, double value) => switch (value) {
    final v when v >= highConfidence => green(context),
    final v when v >= mediumConfidence => orange(context),
    _ => red(context),
  };

  /// A box whose confidence can't be ranked. None of the tier hues, so it doesn't read as graded.
  static Color neutral(BuildContext context) =>
      _resolve(context, material: Colors.blue, cupertino: CupertinoColors.systemBlue);

  /// The live scanner's scan box. None of the line-box hues, so a line cut at its edge still shows.
  static Color scanBox(BuildContext context) =>
      _resolve(context, material: Colors.purple, cupertino: CupertinoColors.systemPurple);

  /// High confidence: [Colors.green] / [CupertinoColors.systemGreen].
  static Color green(BuildContext context) =>
      _resolve(context, material: Colors.green, cupertino: CupertinoColors.systemGreen);

  /// Medium confidence: [Colors.orange] / [CupertinoColors.systemOrange].
  static Color orange(BuildContext context) =>
      _resolve(context, material: Colors.orange, cupertino: CupertinoColors.systemOrange);

  /// Low confidence: [Colors.red] / [CupertinoColors.systemRed].
  static Color red(BuildContext context) =>
      _resolve(context, material: Colors.red, cupertino: CupertinoColors.systemRed);

  static Color _resolve(
    BuildContext context, {
    required Color material,
    required Color cupertino,
  }) => CupertinoDynamicColor.resolve(
    platformValue(material: material, cupertino: cupertino),
    context,
  );
}
