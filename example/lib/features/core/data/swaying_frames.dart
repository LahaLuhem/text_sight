import 'dart:math' show cos, sin;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

/// Turns a still image into a gently drifting camera feed.
///
/// A fixed scene proves nothing about live tracking: the boxes would sit still whether or not the
/// overlay ever updated. Drifting the frame means every tick is a genuinely different image, so the
/// recognizer runs again and the boxes have to follow, the way the Android emulator's virtual scene
/// sways enough to show the same thing.
final class SwayingFrames {
  /// Drift in source pixels and tilt in radians, tuned to read as a held camera rather than a pan.
  /// The three periods are deliberately unequal, so the motion never retraces a straight line.
  static const _driftX = 12.0;
  static const _driftY = 9.0;
  static const _tilt = 0.021;

  /// Has to cover the drift and the tilt together, or a frame would show past the image's edge.
  /// A tilt of [_tilt] alone needs about 1.6% on a 4:3 frame, the drift another 4%.
  static const _overscale = 1.12;

  final ui.Image _source;

  new(this._source);

  /// Decodes an encoded image. Takes bytes rather than an asset key so a test needs no bundle.
  static Future<SwayingFrames> fromBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    return SwayingFrames(frame.image);
  }

  ui.Size get size => ui.Size(_source.width.toDouble(), _source.height.toDouble());

  /// The source drifted and tilted for [elapsed], encoded as a PNG.
  ///
  /// PNG because the recognizer takes encoded bytes and `toByteData` offers nothing cheaper.
  Future<Uint8List> frameAt(Duration elapsed) async {
    final seconds = elapsed.inMilliseconds / Duration.millisecondsPerSecond;
    final (width, height) = (size.width, size.height);

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..translate(
        width / 2 + sin(seconds * 0.9) * _driftX,
        height / 2 + cos(seconds * 0.6) * _driftY,
      )
      ..rotate(sin(seconds * 0.45) * _tilt)
      ..scale(_overscale)
      ..translate(-width / 2, -height / 2)
      ..drawImage(_source, ui.Offset.zero, ui.Paint());

    final picture = recorder.endRecording();
    final image = await picture.toImage(_source.width, _source.height);
    picture.dispose();
    try {
      final encoded = await image.toByteData(format: .png);
      if (encoded == null) throw StateError('The drifted frame could not be encoded.');

      return encoded.buffer.asUint8List();
    } finally {
      // Every frame allocates native memory, so it has to go back before the next tick.
      image.dispose();
    }
  }

  void dispose() => _source.dispose();
}
