import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';
import 'package:text_sight/text_sight.dart';

import '/features/core/data/constants/core_constants.dart';
import '/features/core/widgets/core_widgets.dart';
import 'live_scanner_view_model.dart';

/// Live camera OCR: the preview with a confidence-coloured box overlay, a torch
/// toggle, and a scrolling recognized-text panel.
class LiveScannerView extends StatelessWidget {
  const LiveScannerView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: LiveScannerViewModel(),
    viewBuilder: (context, viewModel) => PlatformScaffold(
      appBarData: const PlatformAppBar(title: Text('Live scanner')),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: viewModel.sessionStatusListenable,
          builder: (context, status, _) => switch (status) {
            // Readiness arrives as a sealed TextSightReadinessState — switch over it. The download
            // path is the interesting one (Android, unbundled model); ensureReady() in the view
            // model drives the actual gate and flips to .ready / .failed once it resolves.
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
              actionLabel: 'Open settings',
              onAction: openAppSettings,
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
            .ready => _ScannerView(viewModel: viewModel),
          },
        ),
      ),
    ),
  );
}

/// The ready state: preview + overlay + torch + recognized-text panel.
class _ScannerView extends StatelessWidget {
  final LiveScannerViewModel viewModel;

  const _ScannerView({required this.viewModel});

  @override
  Widget build(BuildContext context) => Stack(
    fit: .expand,
    children: [
      TextSightView(
        controller: viewModel.controller,
        overlayBuilder: (context, capture, constraints) => CustomPaint(
          size: constraints.biggest,
          painter: _ConfidenceBoxPainter(
            capture.lines,
            (confidence) => ConstTheme.confidence(context, confidence),
          ),
        ),
        placeholderBuilder: (_) => const Center(child: PlatformProgressIndicator()),
      ),
      Positioned(
        top: 16,
        right: 16,
        child: ValueListenableBuilder(
          valueListenable: viewModel.shouldEnableTorchListenable,
          builder: (context, isTorchOn, _) => PlatformButton.icon(
            onPressed: viewModel.onTorchToggled,
            icon: Icon(
              context.platformIcon(
                material: isTorchOn ? Icons.flash_on : Icons.flash_off,
                cupertino: isTorchOn ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt_slash_fill,
              ),
            ),
            label: Text(isTorchOn ? 'On' : 'Off'),
          ),
        ),
      ),
      Positioned(
        left: 8,
        right: 8,
        bottom: 8,
        child: StreamBuilder(
          stream: viewModel.controller.captures,
          builder: (context, snapshot) => _RecognizedTextPanel(capture: snapshot.data),
        ),
      ),
    ],
  );
}

/// A bottom panel listing the most recent recognized lines, each with a confidence chip.
class _RecognizedTextPanel extends StatelessWidget {
  final TextSightCapture? capture;

  const _RecognizedTextPanel({required this.capture});

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
                children: [for (final line in lines) RecognizedLineRow(line: line)],
              ),
      ),
    );
  }
}

/// Strokes each recognized line's normalized box, tinted by its confidence tier.
class _ConfidenceBoxPainter extends CustomPainter {
  final List<RecognizedLine> lines;
  final Color Function(double? confidence) colorFor;

  _ConfidenceBoxPainter(this.lines, this.colorFor);

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
  bool shouldRepaint(_ConfidenceBoxPainter oldDelegate) => oldDelegate.lines != lines;
}

/// The model-preparation view: a progress indicator over a short message. The indicator runs
/// determinate while a download reports [progress] (`MaterialProgressIndicatorData.value`), and as
/// a plain spinner otherwise (indeterminate, or on iOS where there is nothing to download).
class _PreparingModel extends StatelessWidget {
  final double? progress;
  final String message;

  const _PreparingModel({required this.message, this.progress});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .all(24),
    child: Column(
      mainAxisSize: .min,
      spacing: 16,
      children: [
        PlatformProgressIndicator(
          materialProgressIndicatorData: MaterialProgressIndicatorData(value: progress),
        ),
        Text(message, textAlign: .center),
      ],
    ),
  );
}

/// A centered icon + message + action button for the permission/error states.
class _MessageView extends StatelessWidget {
  final Widget icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageView({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const .all(24),
      child: Column(
        mainAxisSize: .min,
        spacing: 16,
        children: [
          icon,
          Text(message, textAlign: .center),
          PlatformButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}
