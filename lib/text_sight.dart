/// Live, on-device text recognition: Apple Vision on iOS, ML Kit on Android.
///
/// Import only this file. Live preview is a `TextSightView` plus a `TextSightController`, one-shot
/// stills go through `TextSight`, and both hand back `TextSightCapture`s.
library;

export 'src/capture/camera_permission_status.dart';
export 'src/capture/capture_resolution.dart';
export 'src/capture/text_sight.dart';
export 'src/capture/text_sight_controller.dart';
export 'src/capture/text_sight_engine.dart';
export 'src/capture/text_sight_model.dart';
export 'src/capture/text_sight_session_state.dart';
export 'src/recognition/confidence_scale.dart';
export 'src/recognition/darwin_options.dart';
export 'src/recognition/recognition_level.dart';
export 'src/recognition/recognized_element.dart';
export 'src/recognition/recognized_line.dart';
export 'src/recognition/text_sight_capture.dart';
export 'src/recognition/text_sight_options.dart';
export 'src/recognition/text_sight_readiness_state.dart';
export 'src/view/text_sight_view.dart';
