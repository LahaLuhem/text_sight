import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Theme;
import 'package:text_sight/text_sight.dart';

import '../data/recognition_result.dart';
import 'confidence_scale_note.dart';
import 'platform/platform_card.dart';
import 'recognized_line_row.dart';

/// Shows a [RecognitionResult], or [idleHint] before the first run.
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
    if (capture == null) return _MessageCard('Failed: $error');

    return _CaptureCard(capture: capture, emptyHint: emptyHint);
  }
}

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
            '${capture.imageSize.width.toInt()}×${capture.imageSize.height.toInt()} px',
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

class const _MessageCard(final String message) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PlatformCard(
    child: Padding(padding: const .all(16), child: Text(message)),
  );
}
