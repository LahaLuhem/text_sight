import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pmvvm/pmvvm.dart';
import 'package:text_sight/text_sight.dart';

import '/features/core/data/constants/core_constants.dart';
import '/features/core/data/recognition_result.dart';

/// The region-of-interest knobs: whether recognition is restricted, and the centered
/// box's normalized width and height.
typedef RoiConfig = ({bool restrict, double width, double height});

/// Runs the same bundled still through the recognizer with whatever level and
/// region-of-interest the knobs currently hold, so their effect can be compared.
final class PlaygroundViewModel extends ViewModel {
  final _levelNotifier = ValueNotifier(RecognitionLevel.accurate);
  final _roiConfigNotifier = ValueNotifier<RoiConfig>((restrict: false, width: 0.8, height: 0.4));
  final _resultNotifier = ValueNotifier<RecognitionResult?>(null);

  /// The centered ROI rect for [config], or null when unrestricted (whole frame).
  static Rect? roiOf(RoiConfig config) => config.restrict
      ? Rect.fromLTWH((1 - config.width) / 2, (1 - config.height) / 2, config.width, config.height)
      : null;

  ValueListenable<RecognitionLevel> get levelListenable => _levelNotifier;

  ValueListenable<RoiConfig> get roiConfigListenable => _roiConfigNotifier;

  ValueListenable<RecognitionResult?> get resultListenable => _resultNotifier;

  void onLevelSelected(RecognitionLevel? level) {
    if (level != null) _levelNotifier.value = level;
  }

  void onRestrictToggled({required bool value}) => _updateRoi(restrict: value);

  void onRoiWidthChanged(double value) => _updateRoi(width: value);

  void onRoiHeightChanged(double value) => _updateRoi(height: value);

  Future<void> onRecognizePressed() async {
    try {
      final bytes = (await rootBundle.load(ConstMedia.sampleText.keyName)).buffer.asUint8List();
      final options = TextSightOptions(
        level: _levelNotifier.value,
        roi: roiOf(_roiConfigNotifier.value),
      );
      _resultNotifier.value = (
        capture: await TextSight.recognizeImage(bytes, options: options),
        error: null,
      );
    } on Object catch (error) {
      _resultNotifier.value = (capture: null, error: error.toString());
    }
  }

  void _updateRoi({bool? restrict, double? width, double? height}) {
    final config = _roiConfigNotifier.value;
    _roiConfigNotifier.value = (
      restrict: restrict ?? config.restrict,
      width: width ?? config.width,
      height: height ?? config.height,
    );
  }

  @override
  void dispose() {
    _levelNotifier.dispose();
    _roiConfigNotifier.dispose();
    _resultNotifier.dispose();

    super.dispose();
  }
}
