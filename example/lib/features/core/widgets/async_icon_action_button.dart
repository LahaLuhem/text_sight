import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

/// A [PlatformButton.icon] that locks itself while [onPressed] is in flight.
///
/// Re-arms the moment the work finishes, and keeps the in-flight gate on the view rather than the
/// view model.
class const AsyncIconActionButton({
  required final Future<void> Function() onPressed,
  required final PlatformIcons idleIcon,
  required final String idleLabel,
  required final String busyLabel,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TapDebouncer(
    onTap: onPressed,
    cooldown: .zero,
    builder: (_, onTap) => PlatformButton.icon(
      onPressed: onTap ?? onPressed,
      isEnabled: onTap != null,
      icon: onTap == null
          ? const SizedBox(
              width: 16,
              height: 16,
              child: PlatformProgressIndicator(
                materialProgressIndicatorData: MaterialProgressIndicatorData(strokeWidth: 2),
                cupertinoProgressIndicatorData: CupertinoProgressIndicatorData(radius: 8),
              ),
            )
          : PlatformIcon(idleIcon),
      label: Text(onTap == null ? busyLabel : idleLabel),
    ),
  );
}
