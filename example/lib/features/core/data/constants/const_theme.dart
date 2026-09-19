import 'package:flutter/cupertino.dart' show CupertinoColors, CupertinoDynamicColor;
import 'package:flutter/widgets.dart' show BuildContext, Color;
import 'package:material_ui/material_ui.dart' show Colors;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// Confidence-tier palette for the demo: Material hues on Android, `CupertinoColors.system*` on
/// iOS, resolved so iOS still follows light and dark.
abstract final class ConstTheme() {
  /// Alpha for a confidence-tinted chip fill.
  static const confidenceFillAlpha = 0.15;

  /// At or above this, a line counts as high.
  static const highConfidence = 0.8;

  /// At or above this, medium. Below it, low.
  static const mediumConfidence = 0.5;

  /// The tier colour for a line's confidence.
  static Color confidence(BuildContext context, double value) => switch (value) {
    final v when v >= highConfidence => green(context),
    final v when v >= mediumConfidence => orange(context),
    _ => red(context),
  };

  /// For a scale that can't be ranked. Deliberately not one of the tier hues, so an unranked
  /// overlay can't be mistaken for a graded one.
  static Color neutral(BuildContext context) =>
      _resolve(context, material: Colors.blue, cupertino: CupertinoColors.systemBlue);

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
