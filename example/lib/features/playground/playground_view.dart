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
                emptyHint:
                    'No lines matched the region. Widen the box or center it on a line — on '
                    'Android, a line counts only when its center is inside the box.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The sample image with the draggable region-of-interest box drawn over it.
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
          builder: (context, config, _) => _RoiEditor(
            config: config,
            color: ConstTheme.green(context),
            onRectChanged: viewModel.onRoiRectChanged,
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

/// The region-of-interest toggle, with a hint pointing at the draggable box while it is active.
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
        if (config.restrict)
          Text(
            'Drag the box to move it, or a corner to resize.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    ),
  );
}

/// The sample image with a directly-manipulated region-of-interest box: drag the interior to move
/// it, drag a corner handle to resize. Inert (just the image) while recognition is unrestricted.
/// The box itself is view-model-owned state; only the in-progress drag is view-local.
class _RoiEditor extends StatefulWidget {
  final RoiConfig config;
  final Color color;
  final ValueChanged<Rect> onRectChanged;

  const _RoiEditor({required this.config, required this.color, required this.onRectChanged});

  @override
  State<_RoiEditor> createState() => _RoiEditorState();
}

class _RoiEditorState extends State<_RoiEditor> {
  /// The drag in progress: the grabbed corner (null ⇒ moving the whole box), with the box and
  /// pointer captured at touch-down. Pure presentation state — observed by nothing but the
  /// gesture handlers (the box is painted from the view model), so it never triggers a rebuild.
  ({_Corner? corner, Rect startRect, Offset startPointer})? _drag;

  /// Slop around a corner, in logical pixels, that still grabs its resize handle.
  static const _handleHitRadius = 24.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;

      return GestureDetector(
        onPanDown: (details) => _onPanDown(details.localPosition, size),
        onPanUpdate: (details) => _onPanUpdate(details.localPosition, size),
        onPanEnd: (_) => _drag = null,
        onPanCancel: () => _drag = null,
        child: Stack(
          fit: .expand,
          children: [
            ConstMedia.sampleText.image(fit: .cover),
            CustomPaint(
              painter: _RoiPainter(PlaygroundViewModel.roiOf(widget.config), widget.color),
            ),
          ],
        ),
      );
    },
  );

  /// Hit-tests the touch-down point — done here, not in `onPanStart`, because by the time a pan is
  /// recognized the finger has drifted off a small corner handle, so the resize grab would miss.
  void _onPanDown(Offset localPosition, Size size) {
    final rect = PlaygroundViewModel.roiOf(widget.config);
    if (rect == null) return; // Unrestricted: the box is hidden and inert.

    final boxPx = _toPx(rect, size);
    final corner = _grabbedCorner(localPosition, boxPx);
    if (corner != null || boxPx.contains(localPosition)) {
      _drag = (corner: corner, startRect: rect, startPointer: _toNorm(localPosition, size));
    }
  }

  void _onPanUpdate(Offset localPosition, Size size) {
    final drag = _drag;
    if (drag == null) return;

    final pointer = _toNorm(localPosition, size);
    final corner = drag.corner;
    final next = corner == null
        ? drag.startRect.shift(pointer - drag.startPointer)
        : Rect.fromPoints(_anchorOf(drag.startRect, corner), _clampToUnit(pointer));
    widget.onRectChanged(next);
  }

  /// The corner whose handle sits within [_handleHitRadius] of [localPosition], else null.
  _Corner? _grabbedCorner(Offset localPosition, Rect boxPx) {
    for (final (corner, at) in [
      (_Corner.topLeft, boxPx.topLeft),
      (_Corner.topRight, boxPx.topRight),
      (_Corner.bottomLeft, boxPx.bottomLeft),
      (_Corner.bottomRight, boxPx.bottomRight),
    ]) {
      if ((localPosition - at).distance <= _handleHitRadius) return corner;
    }

    return null;
  }

  /// The normalized corner diagonally opposite [corner] — the fixed anchor while resizing.
  static Offset _anchorOf(Rect rect, _Corner corner) => switch (corner) {
    _Corner.topLeft => rect.bottomRight,
    _Corner.topRight => rect.bottomLeft,
    _Corner.bottomLeft => rect.topRight,
    _Corner.bottomRight => rect.topLeft,
  };

  static Offset _toNorm(Offset px, Size size) => Offset(px.dx / size.width, px.dy / size.height);

  static Rect _toPx(Rect rect, Size size) => Rect.fromLTWH(
    rect.left * size.width,
    rect.top * size.height,
    rect.width * size.width,
    rect.height * size.height,
  );

  static Offset _clampToUnit(Offset point) =>
      Offset(point.dx.clamp(0.0, 1.0), point.dy.clamp(0.0, 1.0));
}

/// A corner of the region-of-interest box, identifying which resize handle a drag grabbed.
enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

/// Strokes the active region-of-interest over the sample image, with a dot at each draggable
/// corner. Draws nothing when [roi] is null (recognition unrestricted).
class _RoiPainter extends CustomPainter {
  final Rect? roi;
  final Color color;

  _RoiPainter(this.roi, this.color);

  static const _handleRadius = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final roi = this.roi;
    if (roi == null) return;

    final boxPx = Rect.fromLTWH(
      roi.left * size.width,
      roi.top * size.height,
      roi.width * size.width,
      roi.height * size.height,
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color;
    canvas.drawRect(boxPx, stroke);

    final handle = Paint()..color = color;
    for (final corner in [boxPx.topLeft, boxPx.topRight, boxPx.bottomLeft, boxPx.bottomRight]) {
      canvas.drawCircle(corner, _handleRadius, handle);
    }
  }

  @override
  bool shouldRepaint(_RoiPainter oldDelegate) =>
      oldDelegate.roi != roi || oldDelegate.color != color;
}
