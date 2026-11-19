import Foundation

/// One read line. Each backend maps its own Vision type onto this, so the encoder never sees one.
struct RecognizedLineData {
  let text: String
  /// `[0, 1]`, always Vision's own.
  let confidence: Double
  /// `[0, 1]` from the top left, so `minX` and `minY` are its left and top.
  let box: CGRect
}
