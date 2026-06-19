import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart' show Theme;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';
import 'package:text_sight/text_sight.dart';

import '/features/core/data/constants/core_constants.dart';
import '/features/core/widgets/core_widgets.dart';
import 'playground_view_model.dart';

/// Recognizer-config playground: tune level + region-of-interest on a still and compare.
class PlaygroundView extends StatelessWidget {
  const PlaygroundView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: PlaygroundViewModel(),
    viewBuilder: (context, viewModel) => PlatformScaffold(
      appBarData: const PlatformAppBar(title: Text('Playground')),
      body: SafeArea(
        child: ListView(
          padding: const .all(16),
          children: [
            const DemoIntro(
              title: 'Recognizer playground',
              description:
                  'Tune the recognition level and region-of-interest, then recognize the same '
                  'still and compare. The ML Kit Latin recognizer ignores level on Android — see '
                  'Under the hood.',
            ),
            const Gap(16),
            _SamplePreview(viewModel: viewModel),
            const Gap(16),
            _LevelControl(viewModel: viewModel),
            const Gap(16),
            _RoiControls(viewModel: viewModel),
            const Gap(16),
            AsyncIconActionButton(
              onPressed: viewModel.onRecognizePressed,
              idleIcon: PlatformIcons.wand,
              idleLabel: 'Recognize',
              busyLabel: 'Recognizing…',
            ),
            const Gap(16),
            ValueListenableBuilder(
              valueListenable: viewModel.resultListenable,
              builder: (context, result, _) => RecognitionResultView(
                result: result,
                idleHint: 'Recognize to see what the current settings find.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The sample image with the live region-of-interest box drawn over it.
class _SamplePreview extends StatelessWidget {
  final PlaygroundViewModel viewModel;

  const _SamplePreview({required this.viewModel});

  @override
  Widget build(BuildContext context) => PlatformCard(
    child: Padding(
      padding: const .all(8),
      child: AspectRatio(
        aspectRatio: ConstMedia.sampleText.size!.aspectRatio,
        child: ValueListenableBuilder(
          valueListenable: viewModel.roiConfigListenable,
          builder: (context, config, _) => Stack(
            fit: .expand,
            children: [
              ConstMedia.sampleText.image(fit: .cover),
              CustomPaint(
                painter: _RoiPainter(PlaygroundViewModel.roiOf(config), ConstTheme.green(context)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The recognition-level segmented control.
class _LevelControl extends StatelessWidget {
  final PlaygroundViewModel viewModel;

  const _LevelControl({required this.viewModel});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    spacing: 8,
    children: [
      Text('Recognition level', style: Theme.of(context).textTheme.labelLarge),
      ValueListenableBuilder(
        valueListenable: viewModel.levelListenable,
        builder: (context, level, _) => PlatformSegmentButton<RecognitionLevel>(
          choices: RecognitionLevel.values,
          segmentBuilder: (choice) => Text(choice.name),
          selectedChoice: level,
          onSelectionChanged: viewModel.onLevelSelected,
        ),
      ),
    ],
  );
}

/// The region-of-interest toggle and the centered box's width/height sliders.
class _RoiControls extends StatelessWidget {
  final PlaygroundViewModel viewModel;

  const _RoiControls({required this.viewModel});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: viewModel.roiConfigListenable,
    builder: (context, config, _) => Column(
      crossAxisAlignment: .start,
      spacing: 8,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Restrict to region', style: Theme.of(context).textTheme.labelLarge),
            ),
            PlatformSwitch(
              value: config.restrict,
              onChanged: (value) => viewModel.onRestrictToggled(value: value),
            ),
          ],
        ),
        _SliderRow(
          label: 'Width',
          value: config.width,
          isEnabled: config.restrict,
          onChanged: viewModel.onRoiWidthChanged,
        ),
        _SliderRow(
          label: 'Height',
          value: config.height,
          isEnabled: config.restrict,
          onChanged: viewModel.onRoiHeightChanged,
        ),
      ],
    ),
  );
}

/// A labelled slider row with its current value.
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isEnabled;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      SizedBox(width: 56, child: Text(label)),
      Expanded(
        child: PlatformSlider(value: value, min: 0.2, isEnabled: isEnabled, onChanged: onChanged),
      ),
      SizedBox(width: 40, child: Text(value.toStringAsFixed(2), textAlign: .end)),
    ],
  );
}

/// Strokes the active region-of-interest over the sample image.
class _RoiPainter extends CustomPainter {
  final Rect? roi;
  final Color color;

  _RoiPainter(this.roi, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final roi = this.roi;
    if (roi == null) return;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color;
    canvas.drawRect(
      Rect.fromLTWH(
        roi.left * size.width,
        roi.top * size.height,
        roi.width * size.width,
        roi.height * size.height,
      ),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_RoiPainter oldDelegate) =>
      oldDelegate.roi != roi || oldDelegate.color != color;
}
