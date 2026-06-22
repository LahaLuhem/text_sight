/// Live, on-device text recognition — Apple Vision on iOS, ML Kit on Android.
///
/// Import only this file. The live entry points are `TextSightView` with a
/// `TextSightController`; the static one-shot is `TextSight`. Either way
/// recognition yields `TextSightCapture`s of `RecognizedLine`s. `TextSightModel`
/// reports and controls when the on-device model is ready.
library;

export 'src/capture/text_sight.dart';
export 'src/capture/text_sight_controller.dart';
export 'src/capture/text_sight_model.dart';
export 'src/recognition/recognition_level.dart';
export 'src/recognition/recognized_element.dart';
export 'src/recognition/recognized_line.dart';
export 'src/recognition/text_sight_capture.dart';
export 'src/recognition/text_sight_options.dart';
export 'src/recognition/text_sight_readiness_state.dart';
export 'src/view/text_sight_view.dart';
