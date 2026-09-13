import 'package:flutter/widgets.dart';
import 'package:text_sight/text_sight.dart';

import 'confidence_chip.dart';

/// One recognized line, its text filling the row, with a trailing [ConfidenceChip].
/// Shared by the live scanner's panel, the one-shot result, and the playground.
class const RecognizedLineRow({required final RecognizedLine line, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .symmetric(horizontal: 8, vertical: 4),
    child: Row(
      spacing: 8,
      children: [
        Expanded(child: Text(line.text)),
        ConfidenceChip(confidence: line.confidence),
      ],
    ),
  );
}
