import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoColors, CupertinoDynamicColor;
import 'package:flutter/widgets.dart' show BuildContext, Color;
import 'package:material_ui/material_ui.dart' show Colors;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// Material hues on Android, and the matching system colours on iOS, which follow light and dark.
abstract final class ConstTheme() {
  /// Alpha for a confidence-tinted chip fill.
  static const confidenceFillAlpha = 0.15;

  /// From here up, a line is high confidence.
  static const highConfidence = 0.8;

  /// From here up, a line is medium confidence. Below is low.
  static const mediumConfidence = 0.5;

  /// The tier colour for a confidence in `[0, 1]`.
  static Color confidence(BuildContext context, double value) => switch (value) {
    final v when v >= highConfidence => green(context),
    final v when v >= mediumConfidence => orange(context),
    _ => red(context),
  };

  /// For confidences that can't be ranked. Off the tier hues, so it doesn't read as graded.
  static Color neutral(BuildContext context) =>
      _resolve(context, material: Colors.blue, cupertino: CupertinoColors.systemBlue);

  /// The scan box. Off the line-box hues, so a line crossing its edge still shows.
  static Color scanBox(BuildContext context) =>
      _resolve(context, material: Colors.purple, cupertino: CupertinoColors.systemPurple);

  /// High confidence.
  static Color green(BuildContext context) =>
      _resolve(context, material: Colors.green, cupertino: CupertinoColors.systemGreen);

  /// Medium confidence.
  static Color orange(BuildContext context) =>
      _resolve(context, material: Colors.orange, cupertino: CupertinoColors.systemOrange);

  /// Low confidence.
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
