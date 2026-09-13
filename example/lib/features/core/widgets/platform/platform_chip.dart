import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Chip;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// A platform-adaptive chip: Material [Chip] on Android, and a rounded
/// icon-and-label pill on Cupertino.
///
/// Gap-plugging stand-in until `platform_adaptive_widgets` grows a `PlatformChip`. A bare Material
/// [Chip] throws "No Material widget found" on the iOS branch, since a `CupertinoPageScaffold`
/// provides no `Material` ancestor.
class const PlatformChip({
  /// The chip's label.
  required final Widget label,

  /// Leading widget, typically a small [Icon]. Optional.
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
    cupertinoBuilder: (_) => DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const .all(.circular(20)),
        border: switch (side) {
          null => null,
          final borderSide => Border.fromBorderSide(borderSide),
        },
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 8, vertical: 4),
        child: Row(mainAxisSize: .min, spacing: 8, children: [?avatar, label]),
      ),
    ),
  );
}
