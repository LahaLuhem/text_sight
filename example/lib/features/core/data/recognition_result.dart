import 'package:text_sight/text_sight.dart';

/// The outcome of one recognition: a `capture` on success or an `error` message on
/// failure (mutually exclusive; both null before the first run). Shared by the one-shot
/// and playground demos.
typedef RecognitionResult = ({TextSightCapture? capture, String? error});
