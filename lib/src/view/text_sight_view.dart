import 'dart:async';

import 'package:flutter/widgets.dart';

import '../capture/text_sight_controller.dart';
import '../recognition/text_sight_capture.dart';

/// Builds an overlay painted over the live preview from the latest [capture].
///
/// The [constraints] are the preview's, so a painter can map a line's
/// normalized box onto the displayed pixels.
typedef TextSightOverlayBuilder =
    Widget Function(BuildContext context, TextSightCapture capture, BoxConstraints constraints);

/// A live camera preview that recognizes text, driven by a [TextSightController].
///
/// Renders the controller's [TextSightController.textureId] and rebuilds as the
/// session state changes. Each [TextSightCapture] is delivered to [onResult]
/// (for consumers that only need the text) and to [overlayBuilder] (for drawing
/// boxes over the preview). Before a texture exists — the controller's
/// [TextSightController.start] has not run yet — [placeholderBuilder] is shown.
///
/// The view does not start or stop the session itself; the consumer drives the
/// controller, so session lifecycle (including pausing on app background) stays
/// in one place.
class TextSightView extends StatefulWidget {
  /// The controller that owns the session this view renders.
  final TextSightController controller;

  /// Called with every capture as it arrives.
  final void Function(TextSightCapture capture)? onResult;

  /// Builds an overlay stacked over the preview from the latest capture.
  final TextSightOverlayBuilder? overlayBuilder;

  /// Builds what shows before a preview texture is available.
  final WidgetBuilder? placeholderBuilder;

  /// Creates a view bound to [controller].
  const TextSightView({
    required this.controller,
    this.onResult,
    this.overlayBuilder,
    this.placeholderBuilder,
    super.key,
  });

  @override
  State<TextSightView> createState() => _TextSightViewState();
}

class _TextSightViewState extends State<TextSightView> {
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
      if (textureId == null) {
        return widget.placeholderBuilder?.call(context) ?? const SizedBox.shrink();
      }

      final overlayBuilder = widget.overlayBuilder;
      final capture = _capture;

      return Stack(
        fit: .expand,
        children: [
          Texture(textureId: textureId),
          if (overlayBuilder != null && capture != null)
            LayoutBuilder(
              builder: (context, constraints) => overlayBuilder(context, capture, constraints),
            ),
        ],
      );
    },
  );

  void _subscribe() => _subscription = widget.controller.captures.listen((capture) {
    widget.onResult?.call(capture);
    if (widget.overlayBuilder != null) setState(() => _capture = capture);
  });
}
