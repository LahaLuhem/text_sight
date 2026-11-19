import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Chip;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// A Material [Chip] on Android, and a rounded pill on iOS.
///
/// Stands in until `platform_adaptive_widgets` has a `PlatformChip`. A bare [Chip] throws "No
/// Material widget found" on iOS, where `CupertinoPageScaffold` gives no `Material` ancestor.
class const PlatformChip({
  /// The chip's label.
  required final Widget label,

  /// Leading widget, usually a small [Icon].
  final Widget? avatar,

  /// Fill colour of the chip.
  final Color? backgroundColor,

  /// Outline of the chip.
  final BorderSide? side,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PlatformWidget(
    materialBuilder: (_) =>
        Chip(avatar: avatar, label: label, backgroundColor: backgroundColor, side: side),
    cupertinoBuilder: (_) {
      final side = this.side;

      return DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const .all(.circular(20)),
          border: side == null ? null : Border.fromBorderSide(side),
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 8, vertical: 4),
          child: Row(mainAxisSize: .min, spacing: 8, children: [?avatar, label]),
        ),
      );
    },
  );
}
