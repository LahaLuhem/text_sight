import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Card;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// Material [Card] on Android, a rounded filled surface on Cupertino, which ships no card of its
/// own. Stands in until `platform_adaptive_widgets` grows a `PlatformCard`. The child brings its
/// own padding.
class const PlatformCard({
  required final Widget child,

  /// Falls back to Material [Card]'s own default on both platforms.
  final EdgeInsetsGeometry? margin,
  super.key,
}) extends StatelessWidget {
  /// Material [Card]'s default, applied on the Cupertino branch only.
  static const _defaultMargin = EdgeInsets.all(4);

  static const _cupertinoRadius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) => PlatformWidget(
    materialBuilder: (_) => Card(margin: margin, clipBehavior: .antiAlias, child: child),
    // A Container, not a DecoratedBox, which cannot clip. Both branches clip so a tappable child's
    // feedback stays inside the curve.
    cupertinoBuilder: (context) => Container(
      margin: margin ?? _defaultMargin,
      clipBehavior: .antiAlias,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: _cupertinoRadius,
      ),
      child: child,
    ),
  );
}
