// Shared ergonomics
// ignore_for_file: prefer-match-file-name, prefer-first

// The comparison set is the unit here, not one class per file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:standard_message_codec/standard_message_codec.dart';

import 'bench_capture.dart';

/// One transport candidate: a reversible wire encoding for a [BenchCapture].
abstract interface class CaptureCodec {
  /// Recorded as the result `candidate` field.
  String get name;

  Uint8List encode(BenchCapture capture);

  BenchCapture decode(Uint8List bytes);
}

/// Every candidate under test, baseline (`map_std`, today's wire) first.
const allCodecs = <CaptureCodec>[
  MapStdCodec(),
  ListStdCodec(),
  PigeonReplicaCodec(),
  PackedCodec(name: 'packed_f32', floatBytes: 4),
  PackedCodec(name: 'packed_f64', floatBytes: 8),
];

/// Baseline, today's wire: a `Map` with a key per field through `StandardMessageCodec`. Decode
/// mirrors `_decodeCapture` / `_decodeLine` exactly, casting each value via `num`.
final class MapStdCodec implements CaptureCodec {
  const new();

  static const _codec = StandardMessageCodec();

  @override
  String get name => 'map_std';

  @override
  Uint8List encode(BenchCapture capture) {
    final message = {
      'imageWidth': capture.imageWidth,
      'imageHeight': capture.imageHeight,
      'quarterTurns': capture.quarterTurns,
      'lines': [
        for (final line in capture.lines)
          {
            'text': line.text,
            'confidence': line.confidence,
            'left': line.left,
            'top': line.top,
            'width': line.width,
            'height': line.height,
          },
      ],
    };

    return _toBytes(_codec.encodeMessage(message));
  }

  @override
  BenchCapture decode(Uint8List bytes) {
    final Object? decoded = _codec.decodeMessage(ByteData.sublistView(bytes));
    final frameMap = decoded! as Map<Object?, Object?>;
    final rawLines = frameMap['lines']! as List<Object?>;

    return BenchCapture(
      imageWidth: (frameMap['imageWidth']! as num).toDouble(),
      imageHeight: (frameMap['imageHeight']! as num).toDouble(),
      quarterTurns: (frameMap['quarterTurns']! as num).toInt(),
      lines: rawLines
          .map((raw) => _decodeLine(raw! as Map<Object?, Object?>))
          .toList(growable: false),
    );
  }

  BenchLine _decodeLine(Map<Object?, Object?> map) => BenchLine(
    text: map['text']! as String,
    confidence: (map['confidence'] as num?)?.toDouble(),
    left: (map['left']! as num).toDouble(),
    top: (map['top']! as num).toDouble(),
    width: (map['width']! as num).toDouble(),
    height: (map['height']! as num).toDouble(),
  );
}

/// Positional `List` (no per-field keys) through `StandardMessageCodec`.
final class ListStdCodec implements CaptureCodec {
  const new();

  static const _codec = StandardMessageCodec();

  @override
  String get name => 'list_std';

  @override
  Uint8List encode(BenchCapture capture) {
    final message = [
      capture.imageWidth,
      capture.imageHeight,
      capture.quarterTurns,
      [
        for (final line in capture.lines)
          [line.text, line.confidence, line.left, line.top, line.width, line.height],
      ],
    ];

    return _toBytes(_codec.encodeMessage(message));
  }

  @override
  BenchCapture decode(Uint8List bytes) {
    final Object? decoded = _codec.decodeMessage(ByteData.sublistView(bytes));
    final frame = decoded! as List<Object?>;
    final rawLines = frame[3]! as List<Object?>;

    return BenchCapture(
      imageWidth: (frame[0]! as num).toDouble(),
      imageHeight: (frame[1]! as num).toDouble(),
      quarterTurns: (frame[2]! as num).toInt(),
      lines: rawLines.map((raw) => _decodeLine(raw! as List<Object?>)).toList(growable: false),
    );
  }

  BenchLine _decodeLine(List<Object?> fields) => BenchLine(
    text: fields[0]! as String,
    confidence: (fields[1] as num?)?.toDouble(),
    left: (fields[2]! as num).toDouble(),
    top: (fields[3]! as num).toDouble(),
    width: (fields[4]! as num).toDouble(),
    height: (fields[5]! as num).toDouble(),
  );
}

/// Replica of Pigeon's generated codec: a one-byte type tag per data class, then its fields as a
/// positional list. Tag values are arbitrary, only the shape mirrors Pigeon.
final class PigeonReplicaCodec implements CaptureCodec {
  const new();

  static const _codec = _PigeonCodec();

  @override
  String get name => 'pigeon';

  @override
  Uint8List encode(BenchCapture capture) => _toBytes(_codec.encodeMessage(capture));

  @override
  BenchCapture decode(Uint8List bytes) {
    final Object? decoded = _codec.decodeMessage(ByteData.sublistView(bytes));

    return decoded! as BenchCapture;
  }
}

final class _PigeonCodec extends StandardMessageCodec {
  const new();

  static const _lineType = 129;
  static const _captureType = 130;

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    switch (value) {
      case final BenchLine line:
        buffer.putUint8(_lineType);
        super.writeValue(buffer, [
          line.text,
          line.confidence,
          line.left,
          line.top,
          line.width,
          line.height,
        ]);
      case final BenchCapture capture:
        buffer.putUint8(_captureType);
        super.writeValue(buffer, [
          capture.imageWidth,
          capture.imageHeight,
          capture.quarterTurns,
          capture.lines,
        ]);
      default:
        super.writeValue(buffer, value);
    }
  }

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    switch (type) {
      case _lineType:
        {
          final fields = super.readValue(buffer)! as List<Object?>;

          return BenchLine(
            text: fields[0]! as String,
            confidence: (fields[1] as num?)?.toDouble(),
            left: (fields[2]! as num).toDouble(),
            top: (fields[3]! as num).toDouble(),
            width: (fields[4]! as num).toDouble(),
            height: (fields[5]! as num).toDouble(),
          );
        }
      case _captureType:
        {
          final fields = super.readValue(buffer)! as List<Object?>;

          return BenchCapture(
            imageWidth: (fields[0]! as num).toDouble(),
            imageHeight: (fields[1]! as num).toDouble(),
            quarterTurns: (fields[2]! as num).toInt(),
            lines: (fields[3]! as List<Object?>)
                .map((raw) => raw! as BenchLine)
                .toList(growable: false),
          );
        }
      default:
        return super.readValueOfType(type, buffer);
    }
  }
}

/// Hand-packed binary: no keys or tags, fixed-width floats, length-prefixed UTF-8, little-endian.
/// Nullable confidence rides a NaN sentinel, which is the complexity the keyed forms avoid.
final class PackedCodec implements CaptureCodec {
  const new({required this.name, required this.floatBytes})
    : assert(floatBytes == 4 || floatBytes == 8, 'floatBytes must be 4 or 8');

  @override
  final String name;

  /// 4 for float32, 8 for float64.
  final int floatBytes;

  @override
  Uint8List encode(BenchCapture capture) {
    final out = BytesBuilder(copy: false);
    _putFloat(out, capture.imageWidth);
    _putFloat(out, capture.imageHeight);
    out.addByte(capture.quarterTurns);
    _putUint32(out, capture.lines.length);
    for (final line in capture.lines) {
      _putFloat(out, line.left);
      _putFloat(out, line.top);
      _putFloat(out, line.width);
      _putFloat(out, line.height);
      _putFloat(out, line.confidence ?? double.nan);
      final textBytes = utf8.encode(line.text);
      _putUint32(out, textBytes.length);
      out.add(textBytes);
    }

    return out.toBytes();
  }

  @override
  BenchCapture decode(Uint8List bytes) {
    final reader = _PackedReader(ByteData.sublistView(bytes), floatBytes);
    final imageWidth = reader.readFloat();
    final imageHeight = reader.readFloat();
    final quarterTurns = reader.readUint8();
    final lineCount = reader.readUint32();
    final lines = List.generate(lineCount, (_) => _readLine(reader), growable: false);

    return BenchCapture(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      quarterTurns: quarterTurns,
      lines: lines,
    );
  }

  BenchLine _readLine(_PackedReader reader) {
    final left = reader.readFloat();
    final top = reader.readFloat();
    final width = reader.readFloat();
    final height = reader.readFloat();
    final confidence = reader.readFloat();
    final textLength = reader.readUint32();
    final text = reader.readUtf8(textLength);

    return BenchLine(
      text: text,
      confidence: confidence.isNaN ? null : confidence,
      left: left,
      top: top,
      width: width,
      height: height,
    );
  }

  void _putFloat(BytesBuilder out, double value) {
    final scratch = ByteData(floatBytes);
    if (floatBytes == 4) {
      scratch.setFloat32(0, value, Endian.little);
    } else {
      scratch.setFloat64(0, value, Endian.little);
    }
    out.add(scratch.buffer.asUint8List());
  }

  void _putUint32(BytesBuilder out, int value) {
    final scratch = ByteData(4)..setUint32(0, value, Endian.little);
    out.add(scratch.buffer.asUint8List());
  }
}

/// Sequential little-endian reader backing [PackedCodec.decode].
final class _PackedReader {
  new(this._data, this._floatBytes);

  final ByteData _data;
  final int _floatBytes;
  var _offset = 0;

  double readFloat() {
    final value = _floatBytes == 4
        ? _data.getFloat32(_offset, Endian.little)
        : _data.getFloat64(_offset, Endian.little);
    _offset += _floatBytes;

    return value;
  }

  int readUint8() => _data.getUint8(_offset++);

  int readUint32() {
    final value = _data.getUint32(_offset, Endian.little);
    _offset += 4;

    return value;
  }

  String readUtf8(int length) {
    final value = utf8.decode(Uint8List.sublistView(_data, _offset, _offset + length));
    _offset += length;

    return value;
  }
}

/// Narrows `ByteData?` to the exact `Uint8List` view.
Uint8List _toBytes(ByteData? data) {
  final bytes = data!;

  return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
}
