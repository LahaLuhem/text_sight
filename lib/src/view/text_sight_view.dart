import 'dart:async';

import 'package:flutter/widgets.dart';

import '../capture/text_sight_controller.dart';
import '../recognition/text_sight_capture.dart';

/// Builds an overlay painted over the live preview from the latest [capture].
///
/// The [constraints] are the preview's, so a painter can map a line's
/// normalized box onto the displayed pixels.
typedef TextSightOverlayBuilder = Widget Function(
  BuildContext context,
  TextSightCapture capture,
  BoxConstraints constraints,
);

/// A live camera preview that recognizes text, driven by a [TextSightController].
///
/// Shows the preview the right way up, fitted by [fit]. Each [TextSightCapture] goes to [onResult]
/// and to [overlayBuilder] for drawing boxes over the preview.
///
/// The view never starts or stops the session. The consumer drives the controller, so lifecycle
/// (including pausing on app background) stays in one place.
final class const TextSightView({
  /// The controller that owns the session this view renders.
  required final TextSightController controller,

  /// Called with every capture as it arrives.
  final void Function(TextSightCapture capture)? onResult,

  /// Builds an overlay stacked over the preview from the latest capture.
  final TextSightOverlayBuilder? overlayBuilder,

  /// Builds what shows until the camera opens, before [TextSightController.start] too.
  final WidgetBuilder? placeholderBuilder,

  /// How the preview fills the view, centred. Any space it leaves is transparent.
  final BoxFit fit = .contain,
  super.key,
}) extends StatefulWidget {
  /// Creates a view bound to [controller].
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
      final preview = widget.controller.preview;
      // Native says which way up the texture goes, so showing it sooner flashes it mis-rotated.
      if (preview == null) {
        return widget.placeholderBuilder?.call(context) ?? const SizedBox.shrink();
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final view = constraints.biggest;
          final fittedSizes = applyBoxFit(widget.fit, preview.size, view);
          // `source` is the part that shows, so the whole frame scales by the same factor. An
          // empty view would make that 0 / 0.
          final frame = view.isEmpty
              ? Rect.zero
              : Rect.fromCenter(
                  center: view.center(.zero),
                  width:
                      preview.size.width * fittedSizes.destination.width / fittedSizes.source.width,
                  height:
                      preview.size.height *
                      fittedSizes.destination.height /
                      fittedSizes.source.height,
                );
          final capture = _capture;
          final overlayBuilder = widget.overlayBuilder;

          // Its default clip trims what `fit` spills past the view.
          return Stack(
            // Non-directional, so the view needs no Directionality.
            alignment: .topLeft,
            children: [
              Positioned.fromRect(
                rect: frame,
                child: RotatedBox(
                  quarterTurns: preview.quarterTurns,
                  child: Texture(textureId: preview.textureId),
                ),
              ),
              // Unrotated, since the boxes arrive upright.
              if (overlayBuilder != null && capture != null)
                Positioned.fromRect(
                  rect: frame,
                  child: overlayBuilder(context, capture, .tight(frame.size)),
                ),
            ],
          );
        },
      );
    },
  );

  void _subscribe() => _subscription = widget.controller.captures.listen((capture) {
    widget.onResult?.call(capture);

    // Only the overlay draws captures, so without one there's nothing to rebuild.
    if (widget.overlayBuilder == null) {
      _capture = capture;
    } else {
      setState(() => _capture = capture);
    }
  });
}
