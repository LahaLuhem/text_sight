import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Chip;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// Material [Chip] on Android, a rounded icon-and-label pill on Cupertino. Stands in until
/// `platform_adaptive_widgets` grows a `PlatformChip`.
///
/// A bare Material [Chip] throws "No Material widget found" on the iOS branch, since a
/// `CupertinoPageScaffold` gives it no `Material` ancestor.
class const PlatformChip({
  required final Widget label,

  /// Typically a small [Icon].
  final Widget? avatar,
  final Color? backgroundColor,
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
