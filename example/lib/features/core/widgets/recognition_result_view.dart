import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Theme;
import 'package:text_sight/text_sight.dart';

import '../data/recognition_result.dart';
import 'confidence_scale_note.dart';
import 'platform/platform_card.dart';
import 'recognized_line_row.dart';

/// Renders a [RecognitionResult]: [idleHint] before the first run, the lines on success,
/// [emptyHint] when there were none, the error message on failure.
class const RecognitionResultView({
  required final RecognitionResult? result,
  required final String idleHint,
  final String emptyHint = 'No text recognized.',
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null) return _MessageCard(idleHint);

    final (:capture, :error) = result;
    if (error != null) return _MessageCard('Failed: $error');
    if (capture != null) return _CaptureCard(capture: capture, emptyHint: emptyHint);

    return const _MessageCard('No text found.');
  }
}

/// The lines plus a summary, or [emptyHint] when recognition worked but matched nothing.
class const _CaptureCard({required final TextSightCapture capture, required final String emptyHint})
    extends StatelessWidget {
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
          if (capture.lines.isEmpty)
            Text(emptyHint)
          else ...[
            for (final line in capture.lines) RecognizedLineRow(line: line),
            const ConfidenceScaleNote(),
          ],
        ],
      ),
    ),
  );
}

/// A simple padded card for the idle hint and the failure message.
class const _MessageCard(final String message) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PlatformCard(
    child: Padding(padding: const .all(16), child: Text(message)),
  );
}
