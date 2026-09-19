import 'dart:async';

import 'package:flutter/widgets.dart';

import '../capture/text_sight_controller.dart';
import '../recognition/text_sight_capture.dart';

/// Builds the overlay drawn over the preview. [constraints] are the preview's, so a painter can map
/// a normalized box onto real pixels.
typedef TextSightOverlayBuilder = Widget Function(
  BuildContext context,
  TextSightCapture capture,
  BoxConstraints constraints,
);

/// A live camera preview that recognizes text, driven by a [TextSightController].
///
/// It never starts or stops the session. You drive the controller, so the lifecycle (pausing on app
/// background included) stays in one place.
final class const TextSightView({
  /// Owns the session this renders.
  required final TextSightController controller,

  /// Called with every capture as it arrives.
  final void Function(TextSightCapture capture)? onResult,

  /// Stacked over the preview, rebuilt on every capture.
  final TextSightOverlayBuilder? overlayBuilder,

  /// Shows until the first capture lands, which includes everything before
  /// [TextSightController.start].
  final WidgetBuilder? placeholderBuilder,
  super.key,
}) extends StatefulWidget {
  /// Creates it.
  this;

  @override
  State<TextSightView> createState() => _TextSightViewState();
}

class _TextSightViewState() extends State<TextSightView> {
  StreamSubscription<TextSightCapture>? _subscription;
  TextSightCapture? _capture;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(TextSightView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _subscription?.cancel().ignore();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final textureId = widget.controller.textureId;
      final capture = _capture;
      // The texture is raw and its rotation rides on the capture, so showing it any sooner flashes
      // it sideways.
      if (textureId == null || capture == null) {
        return widget.placeholderBuilder?.call(context) ?? const SizedBox.shrink();
      }

      final overlayBuilder = widget.overlayBuilder;

      return Stack(
        fit: .expand,
        children: [
          RotatedBox(
            quarterTurns: capture.quarterTurns,
            child: Texture(textureId: textureId),
          ),
          // Deliberately not rotated: the overlay's boxes are already display-oriented.
          if (overlayBuilder != null)
            LayoutBuilder(
              builder: (context, constraints) => overlayBuilder(context, capture, constraints),
            ),
        ],
      );
    },
  );

  void _subscribe() => _subscription = widget.controller.captures.listen((capture) {
    widget.onResult?.call(capture);

    // With no overlay, an unchanged rotation has nothing new to paint, so skip the rebuild.
    final rotationChanged = capture.quarterTurns != _capture?.quarterTurns;
    if (widget.overlayBuilder != null || rotationChanged) {
      setState(() => _capture = capture);
    } else {
      _capture = capture;
    }
  });
}
