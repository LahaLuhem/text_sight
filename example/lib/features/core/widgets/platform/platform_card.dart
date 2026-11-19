import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Card;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

/// A Material [Card] on Android, and a rounded, filled surface on iOS, which has no card.
///
/// Stands in until `platform_adaptive_widgets` has a `PlatformCard`. Both clip to the rounded
/// corners so a tap's ripple stays inside, which is why iOS uses a [Container]: `DecoratedBox`
/// can't clip.
class const PlatformCard({
  /// Content of the card.
  required final Widget child,

  /// Outer margin. Defaults to Material [Card]'s own default on both platforms.
  final EdgeInsetsGeometry? margin,
  super.key,
}) extends StatelessWidget {
  /// [Card]'s own default, for the iOS branch.
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
