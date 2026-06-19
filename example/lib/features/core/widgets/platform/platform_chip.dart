import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Chip;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// A platform-adaptive chip — Material [Chip] on Android, and a rounded
/// icon-and-label pill on Cupertino.
///
/// Gap-plugging stand-in: `platform_adaptive_widgets` exposes no `PlatformChip`, and a
/// bare Material [Chip] throws "No Material widget found" on the iOS branch (a
/// `CupertinoPageScaffold` provides no `Material` ancestor). The example owns one until
/// the base library grows it.
class PlatformChip extends StatelessWidget {
  /// Leading widget, typically a small [Icon]. Optional.
  final Widget? avatar;

  /// The chip's label.
  final Widget label;

  /// Fill colour of the chip.
  final Color? backgroundColor;

  /// Outline of the chip.
  final BorderSide? side;

  const PlatformChip({
    required this.label,
    this.avatar,
    this.backgroundColor,
    this.side,
    super.key,
  });

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
