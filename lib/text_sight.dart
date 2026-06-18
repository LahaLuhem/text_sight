/// Live, on-device text recognition — Apple Vision on iOS, ML Kit on Android.
///
/// Import only this file. The live entry points are `TextSightView` with a
/// `TextSightController`; recognition yields `TextSightCapture`s of
/// `RecognizedLine`s. A static one-shot is a near-term addition over the same
/// recognizer and models.
library;

export 'src/capture/text_sight.dart';
export 'src/capture/text_sight_controller.dart';
export 'src/recognition/recognition_level.dart';
export 'src/recognition/recognized_element.dart';
export 'src/recognition/recognized_line.dart';
export 'src/recognition/text_sight_capture.dart';
export 'src/recognition/text_sight_options.dart';
export 'src/view/text_sight_view.dart';
