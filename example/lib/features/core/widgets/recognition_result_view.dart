import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Theme;
import 'package:text_sight/text_sight.dart';

import '../data/recognition_result.dart';
import 'platform/platform_card.dart';
import 'recognized_line_row.dart';

/// Renders a [RecognitionResult]: an [idleHint] before the first run, the recognized
/// lines (with a one-line summary) on success, or the error message on failure. Shared
/// by the one-shot and playground demos.
class RecognitionResultView extends StatelessWidget {
  final RecognitionResult? result;
  final String idleHint;

  const RecognitionResultView({required this.result, required this.idleHint, super.key});

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null) return _MessageCard(idleHint);

    final (:capture, :error) = result;
    if (error != null) return _MessageCard('Failed: $error');
    if (capture != null) return _CaptureCard(capture: capture);

    return const _MessageCard('No text found.');
  }
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
