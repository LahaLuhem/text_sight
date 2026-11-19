/// Live, on-device text recognition: Apple Vision on iOS, ML Kit on Android.
///
/// Import only this file. Live: `TextSightView` with a `TextSightController`. One-shot:
/// `TextSight`. Both yield `TextSightCapture`s of `RecognizedLine`s, and `TextSightModel` reports
/// when the on-device model is ready.
library;

export 'src/camera/text_sight_controller.dart';
export 'src/camera/text_sight_view.dart';
export 'src/options/capture_resolution.dart';
export 'src/options/darwin_options.dart';
export 'src/options/recognition_level.dart';
export 'src/options/text_sight_options.dart';
export 'src/recognition/text_sight.dart';
export 'src/recognition/text_sight_engine.dart';
export 'src/recognition/text_sight_model.dart';
export 'src/results/confidence_scale.dart';
export 'src/results/recognized_element.dart';
export 'src/results/recognized_line.dart';
export 'src/results/text_sight_capture.dart';
export 'src/states/camera_permission_status.dart';
export 'src/states/text_sight_readiness_state.dart';
export 'src/states/text_sight_session_state.dart';
