import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';
import 'package:text_sight/text_sight.dart';

import '/features/core/data/constants/core_constants.dart';
import '/features/core/data/engine_confidence.dart';
import '/features/core/data/fake_camera_platform.dart';
import '/features/core/widgets/core_widgets.dart';
import 'live_scanner_view_model.dart';

/// Live camera OCR: the preview with a confidence-coloured box overlay and the recognized text.
class const LiveScannerView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: LiveScannerViewModel(),
    viewBuilder: (context, viewModel) => PlatformScaffold(
      appBarData: const PlatformAppBar(title: Text('Live scanner')),
      useSafeArea: true,
      body: ValueListenableBuilder(
        valueListenable: viewModel.sessionStatusListenable,
        builder: (context, status, _) => switch (status) {
          // Only shows progress, since ensureReady() in the view model is the gate. A download only
          // happens on Android with the unbundled model.
          .preparingModel => Center(
            child: StreamBuilder(
              stream: TextSightModel.readiness,
              builder: (context, snapshot) => switch (snapshot.data) {
                ModelDownloading(:final progress) => _PreparingModel(
                  progress: progress,
                  message: progress == null
                      ? 'Fetching the recognition model…'
                      : 'Fetching the recognition model… ${(progress * 100).round()}%',
                ),
                ModelUnavailable() => const _PreparingModel(
                  message: 'Recognition model unavailable.',
                ),
                ModelReady() ||
                null => const _PreparingModel(message: 'Preparing the recognition model…'),
              },
            ),
          ),
          .requesting => const Center(child: PlatformProgressIndicator()),
          .denied => _MessageView(
            icon: Icon(
              context.platformIcon(
                material: Icons.no_photography_outlined,
                cupertino: CupertinoIcons.camera_circle,
              ),
              size: 48,
            ),
            message: 'Camera permission is required to recognize text.',
            actionLabel: 'Allow access',
            onAction: viewModel.onRetryPressed,
          ),
          .permanentlyDenied => _MessageView(
            icon: Icon(
              context.platformIcon(
                material: Icons.no_photography_outlined,
                cupertino: CupertinoIcons.camera_circle,
              ),
              size: 48,
            ),
            message: 'Camera access is off. Enable it in Settings, then try again.',
            actionLabel: 'Try again',
            onAction: viewModel.onRetryPressed,
          ),
          .failed => _MessageView(
            icon: Icon(
              context.platformIcon(
                material: Icons.error_outline,
                cupertino: CupertinoIcons.exclamationmark_circle,
              ),
              size: 48,
            ),
            message: viewModel.failure,
            actionLabel: 'Retry',
            onAction: viewModel.onRetryPressed,
          ),
          // Swapping the scanner out also drops the stale overlay the view would keep painting.
          .paused => _MessageView(
            icon: const PlatformIcon(PlatformIcons.pauseCircle, size: 48),
            message: viewModel.pauseMessage,
          ),
          .ready => _ScannerView(viewModel: viewModel),
        },
      ),
    ),
  );
}

/// The ready state: the preview, its controls and the recognized text.
class const _ScannerView({required final LiveScannerViewModel viewModel}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final simulatedFrames = viewModel.simulatedFrames;

    return Stack(
      fit: .expand,
      children: [
        ValueListenableBuilder(
          valueListenable: viewModel.boxFitListenable,
          builder: (context, boxFit, _) => TextSightView(
            controller: viewModel.controller,
            fit: boxFit,
            // Also rebuilt on the controller, so a toggled scan box shows while reading is paused.
            overlayBuilder: (context, capture, constraints) => ListenableBuilder(
              listenable: viewModel.controller,
              builder: (context, _) {
                final scanBox = viewModel.controller.options.roi;
                final size = constraints.biggest;

                return Stack(
                  fit: .expand,
                  children: [
                    // No preview texture on the Simulator, so paint the frame the boxes came from.
                    // The overlay has its shape, so `.fill` doesn't stretch it.
                    if (simulatedFrames != null)
                      ValueListenableBuilder(
                        valueListenable: simulatedFrames,
                        // A capture only follows a published frame, so there is one.
                        builder: (context, frame, _) => Image.memory(
                          frame!.bytes,
                          fit: .fill,
                          gaplessPlayback: true,
                          // Stands in for the preview texture, which screen readers skip too.
                          excludeFromSemantics: true,
                        ),
                      ),
                    if (scanBox != null)
                      Positioned(
                        left: scanBox.left * size.width,
                        top: scanBox.top * size.height,
                        width: scanBox.width * size.width,
                        height: scanBox.height * size.height,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: .all(color: ConstTheme.scanBox(context), width: 3),
                          ),
                        ),
                      ),
                    ValueListenableBuilder(
                      valueListenable: EngineConfidence.scaleListenable,
                      builder: (context, scale, _) {
                        // One stroke colour for every box unless the engine's numbers can be ranked.
                        final isTiered = scale?.isRankable ?? false;

                        return CustomPaint(
                          size: size,
                          painter: _ConfidenceBoxPainter(
                            capture.lines,
                            isTiered: isTiered,
                            colorFor: isTiered
                                ? (confidence) => ConstTheme.confidence(context, confidence)
                                : (_) => ConstTheme.neutral(context),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            placeholderBuilder: (_) => const Center(child: PlatformProgressIndicator()),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Wrap(
            alignment: .end,
            spacing: 8,
            runSpacing: 8,
            children: [
              ListenableBuilder(
                listenable: viewModel.controller,
                builder: (context, _) {
                  final isRecognizing = viewModel.controller.isRecognizing;

                  return PlatformButton.icon(
                    onPressed: viewModel.onRecognitionToggled,
                    emphasis: .medium,
                    icon: PlatformIcon(
                      isRecognizing ? PlatformIcons.pauseFilled : PlatformIcons.playFilled,
                    ),
                    label: Text(isRecognizing ? 'Pause' : 'Resume'),
                  );
                },
              ),
              ValueListenableBuilder(
                valueListenable: viewModel.shouldEnableTorchListenable,
                builder: (context, isTorchOn, _) => PlatformButton.icon(
                  onPressed: viewModel.onTorchToggled,
                  emphasis: .medium,
                  icon: Icon(
                    context.platformIcon(
                      material: isTorchOn ? Icons.flash_on : Icons.flash_off,
                      cupertino: isTorchOn
                          ? CupertinoIcons.bolt_fill
                          : CupertinoIcons.bolt_slash_fill,
                    ),
                  ),
                  label: Text(isTorchOn ? 'On' : 'Off'),
                ),
              ),
              ValueListenableBuilder(
                valueListenable: viewModel.boxFitListenable,
                child: const PlatformIcon(PlatformIcons.fullScreen),
                builder: (context, boxFit, fullScreenIconWidget) => PlatformActionsMenu(
                  actions: {
                    for (final fit in BoxFit.values)
                      .normal(label: fit.name, onPressed: () => viewModel.onBoxFitSelected(fit)),
                  },
                  // Menu items can't show a tick, so the button names the current fit.
                  builder: (context, onPressed) => PlatformButton.icon(
                    onPressed: onPressed,
                    emphasis: .medium,
                    icon: fullScreenIconWidget!,
                    label: Text(boxFit.name),
                  ),
                ),
              ),
              // No visible label, since the outline shows whether it's on.
              ListenableBuilder(
                listenable: viewModel.controller,
                builder: (context, _) => PlatformButton.iconOnly(
                  onPressed: viewModel.onScanBoxPressed,
                  emphasis: .medium,
                  icon: const PlatformIcon(PlatformIcons.crop),
                  label: viewModel.controller.options.roi == null ? 'Scan box off' : 'Scan box on',
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            spacing: 8,
            children: [
              if (simulatedFrames != null)
                _SimulatedCameraControls(viewModel: viewModel, frames: simulatedFrames),
              StreamBuilder(
                stream: viewModel.controller.captures,
                builder: (context, snapshot) => _RecognizedTextPanel(capture: snapshot.data),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Names where the frames come from, and fires the two session events that need real hardware.
class const _SimulatedCameraControls({
  required final LiveScannerViewModel viewModel,
  required final ValueListenable<SimulatedFrame?> frames,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PlatformCard(
    child: Padding(
      padding: const .all(8),
      child: Row(
        spacing: 8,
        children: [
          ValueListenableBuilder(
            valueListenable: frames,
            builder: (context, frame, _) => Text(switch (frame?.isBridged) {
              true => 'Mac camera',
              false => 'Sample image',
              null => 'Starting…',
            }),
          ),
          PlatformButton(
            onPressed: viewModel.onInterruptPressed,
            emphasis: .mediumNeutral,
            child: const Text('Interrupt'),
          ),
          PlatformButton(
            onPressed: viewModel.onFailPressed,
            emphasis: .mediumNeutral,
            child: const Text('Fail'),
          ),
        ],
      ),
    ),
  );
}

/// A bottom panel listing the most recent recognized lines, each with a confidence chip.
class const _RecognizedTextPanel({required final TextSightCapture? capture})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lines = capture?.lines ?? const <RecognizedLine>[];

    return PlatformCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 176),
        child: lines.isEmpty
            ? const Padding(padding: .all(16), child: Text('Point the camera at some text…'))
            : ListView(
                padding: const .all(8),
                shrinkWrap: true,
                children: [
                  for (final line in lines) RecognizedLineRow(line: line),
                  const ConfidenceScaleNote(),
                ],
              ),
      ),
    );
  }
}

/// Strokes each recognized line's normalized box, tinted by its confidence tier.
class _ConfidenceBoxPainter(
  final List<RecognizedLine> lines, {

  /// Whether [colorFor] varies by confidence, so a repaint is needed when it flips.
  required final bool isTiered,
  required final Color Function(double confidence) colorFor,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      final box = line.boundingBox;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colorFor(line.confidence);
      canvas.drawRect(
        Rect.fromLTWH(
          box.left * size.width,
          box.top * size.height,
          box.width * size.width,
          box.height * size.height,
        ),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_ConfidenceBoxPainter oldDelegate) =>
      oldDelegate.lines != lines || oldDelegate.isTiered != isTiered;
}

/// A bar while a download reports [progress], otherwise a spinner.
class const _PreparingModel({required final String message, final double? progress})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final progress = this.progress;

    return Padding(
      padding: const .all(24),
      child: Column(
        mainAxisSize: .min,
        spacing: 16,
        children: [
          if (progress == null)
            const PlatformProgressIndicator()
          else
            PlatformProgressBar(value: progress),
          Text(message, textAlign: .center),
        ],
      ),
    );
  }
}

/// A centred icon and message, with a button for the states the user can act on.
class const _MessageView({
  required final Widget icon,
  required final String message,
  final String? actionLabel,
  final VoidCallback? onAction,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final (actionLabel, onAction) = (this.actionLabel, this.onAction);

    return Center(
      child: Padding(
        padding: const .all(24),
        child: Column(
          mainAxisSize: .min,
          spacing: 16,
          children: [
            icon,
            Text(message, textAlign: .center),
            if (actionLabel != null && onAction != null)
              PlatformButton(onPressed: onAction, emphasis: .high, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
