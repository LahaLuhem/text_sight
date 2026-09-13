import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Theme;

/// A feature screen's title + one-line description, shown at the top of each demo.
class const DemoIntro({required final String title, required final String description, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    spacing: 4,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      Text(description, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}
