import 'package:text_sight/text_sight.dart';

/// One run's outcome: a `capture` on success, or an `error` message on failure.
typedef RecognitionResult = ({TextSightCapture? capture, String? error});
