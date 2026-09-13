import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Card;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// A platform-adaptive card: Material [Card] on Android, and a rounded, filled
/// surface in the iOS idiom on Cupertino (which ships no native card).
///
/// Gap-plugging stand-in until `platform_adaptive_widgets` grows a `PlatformCard`. The child
/// supplies its own padding, as a Material [Card] expects. Both branches clip to the rounded
/// corners so a tappable child's feedback stays inside the curve, which is why Cupertino uses a
/// [Container]: `DecoratedBox` cannot clip its child.
class const PlatformCard({
  /// Content of the card.
  required final Widget child,

  /// Outer margin. Defaults to Material [Card]'s own default on both platforms.
  final EdgeInsetsGeometry? margin,
  super.key,
}) extends StatelessWidget {
  /// Mirror of Material [Card]'s default margin, applied on the Cupertino branch (the
  /// Material branch lets [Card] apply its own when [margin] is null).
  static const _defaultMargin = EdgeInsets.all(4);

  /// Corner radius of the Cupertino surface, shared by its fill and its clip.
  static const _cupertinoRadius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) => PlatformWidget(
    materialBuilder: (_) => Card(margin: margin, clipBehavior: .antiAlias, child: child),
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
