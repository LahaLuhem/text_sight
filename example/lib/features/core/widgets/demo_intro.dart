import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Theme;

/// A feature screen's title + one-line description, shown at the top of each demo.
class DemoIntro extends StatelessWidget {
  final String title;
  final String description;

  const DemoIntro({required this.title, required this.description, super.key});

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
