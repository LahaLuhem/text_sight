import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pmvvm/pmvvm.dart';
import 'package:text_sight/text_sight.dart';

import '/features/core/data/constants/core_constants.dart';
import '/features/core/data/recognition_result.dart';

/// The region-of-interest knobs: whether recognition is restricted, and the normalized,
/// top-left box it is restricted to (dragged directly on the preview).
typedef RoiConfig = ({bool restrict, Rect rect});

/// Runs the same bundled still through the recognizer with whatever level and
/// region-of-interest the knobs currently hold, so their effect can be compared.
final class PlaygroundViewModel extends ViewModel {
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

  void _updateRoi({bool? restrict, Rect? rect}) {
    final config = _roiConfigNotifier.value;
    _roiConfigNotifier.value = (restrict: restrict ?? config.restrict, rect: rect ?? config.rect);
  }

  /// Clamps [rect] to the unit square with a [_minRoiSize] floor, preserving its dimensions where
  /// it can — so dragging the box into an edge slides it back in rather than shrinking it.
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
