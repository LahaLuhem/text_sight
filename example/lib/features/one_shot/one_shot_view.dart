import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart' show Theme;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';
import 'package:text_sight/text_sight.dart';

import '/features/core/data/constants/core_constants.dart';
import '/features/core/widgets/core_widgets.dart';
import 'one_shot_view_model.dart';

/// Still-image recognition: recognize a bundled sample from bytes and from a file path,
/// with no camera, session, or permission.
class OneShotView extends StatelessWidget {
  const OneShotView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: OneShotViewModel(),
    viewBuilder: (context, viewModel) => PlatformScaffold(
      appBarData: const PlatformAppBar(title: Text('One-shot')),
      body: SafeArea(
        child: ListView(
          padding: const .all(16),
          children: [
            const DemoIntro(
              title: 'Still-image recognition',
              description:
                  'Recognize a bundled sample two ways — from in-memory bytes and from a file '
                  'path. No camera, session, or permission.',
            ),
            const Gap(16),
            PlatformCard(
              child: Padding(
                padding: const .all(8),
                child: ConstMedia.sampleText.image(height: 160, fit: .contain),
              ),
            ),
            const Gap(16),
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: AsyncIconActionButton(
                    onPressed: viewModel.onRecognizeBytesPressed,
                    idleIcon: PlatformIcons.photo,
                    idleLabel: 'From bytes',
                    busyLabel: 'Reading…',
                  ),
                ),
                Expanded(
                  child: AsyncIconActionButton(
                    onPressed: viewModel.onRecognizePathPressed,
                    idleIcon: PlatformIcons.folderOpen,
                    idleLabel: 'From file',
                    busyLabel: 'Reading…',
                  ),
                ),
              ],
            ),
            const Gap(16),
            ValueListenableBuilder(
              valueListenable: viewModel.resultListenable,
              builder: (context, result, _) => _ResultPanel(result: result),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Renders the latest recognition result: a hint before the first run, the recognized
/// lines on success, or the error message on failure.
class _ResultPanel extends StatelessWidget {
  final OneShotResult? result;

  const _ResultPanel({required this.result});

  @override
  Widget build(BuildContext context) => switch (result) {
    null => const _MessageCard('Recognize the sample to see the lines it finds.'),
    (:final error?, capture: _) => _MessageCard('Failed: $error'),
    (:final capture?, error: _) => _CaptureCard(capture: capture),
    _ => const _MessageCard('No text found.'),
  };
}

/// The recognized lines plus a one-line summary (count, image size, quarter-turns).
class _CaptureCard extends StatelessWidget {
  final TextSightCapture capture;

  const _CaptureCard({required this.capture});

  @override
  Widget build(BuildContext context) => PlatformCard(
    child: Padding(
      padding: const .all(16),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          Text(
            '${capture.lines.length} lines · '
            '${capture.imageSize.width.toInt()}×${capture.imageSize.height.toInt()} px · '
            'quarterTurns ${capture.quarterTurns}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          for (final line in capture.lines) RecognizedLineRow(line: line),
        ],
      ),
    ),
  );
}

/// A simple padded card for the idle hint and the failure message.
class _MessageCard extends StatelessWidget {
  final String message;

  const _MessageCard(this.message);

  @override
  Widget build(BuildContext context) => PlatformCard(
    child: Padding(padding: const .all(16), child: Text(message)),
  );
}
