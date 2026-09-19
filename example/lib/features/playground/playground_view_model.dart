import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pmvvm/pmvvm.dart';
import 'package:text_sight/text_sight.dart';

import '/features/core/data/constants/core_constants.dart';
import '/features/core/data/recognition_result.dart';

/// Whether recognition is restricted, and the normalized box it's restricted to.
typedef RoiConfig = ({bool restrict, Rect rect});

/// Runs the same bundled still through the recognizer at whatever the knobs currently say, so you
/// can see what each one does.
final class PlaygroundViewModel() extends ViewModel {
  static const _minRoiSize = 0.15;

  final _levelNotifier = ValueNotifier(RecognitionLevel.accurate);
  final _roiConfigNotifier = ValueNotifier<RoiConfig>((
    restrict: false,
    rect: const Rect.fromLTWH(0.1, 0.3, 0.8, 0.4),
  ));
  final _resultNotifier = ValueNotifier<RecognitionResult?>(null);

  /// The active ROI rect for [config], or null when unrestricted (whole frame).
  static Rect? roiOf(RoiConfig config) => config.restrict ? config.rect : null;

  ValueListenable<RecognitionLevel> get levelListenable => _levelNotifier;

  ValueListenable<RoiConfig> get roiConfigListenable => _roiConfigNotifier;

  ValueListenable<RecognitionResult?> get resultListenable => _resultNotifier;

  void onLevelSelected(RecognitionLevel? level) {
    if (level != null) _levelNotifier.value = level;
  }

  void onRestrictToggled({required bool value}) => _updateRoi(restrict: value);

  void onRoiRectChanged(Rect rect) => _updateRoi(rect: _clampRoi(rect));

  Future<void> onRecognizePressed() async {
    try {
      final bytes = (await rootBundle.load(ConstMedia.sampleText.keyName)).buffer.asUint8List();
      final options = TextSightOptions(
        roi: roiOf(_roiConfigNotifier.value),
        darwin: DarwinOptions(recognitionLevel: _levelNotifier.value),
      );
      _resultNotifier.value = (
        capture: await TextSight.recognizeImage(bytes, options: options),
        error: null,
      );
    } on Object catch (error) {
      _resultNotifier.value = (capture: null, error: error.toString());
    }
  }

  void _updateRoi({bool? restrict, Rect? rect}) {
    final config = _roiConfigNotifier.value;
    _roiConfigNotifier.value = (restrict: restrict ?? config.restrict, rect: rect ?? config.rect);
  }

  /// Keeps [rect]'s size where it can, so dragging the box into an edge slides it back in rather
  /// than shrinking it.
  static Rect _clampRoi(Rect rect) {
    final width = rect.width.clamp(_minRoiSize, 1.0);
    final height = rect.height.clamp(_minRoiSize, 1.0);

    return Rect.fromLTWH(
      rect.left.clamp(0.0, 1.0 - width),
      rect.top.clamp(0.0, 1.0 - height),
      width,
      height,
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
