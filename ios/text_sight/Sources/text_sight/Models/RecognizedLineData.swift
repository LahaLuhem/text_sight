import Foundation

/// One recognized line, platform-neutral: the text, a confidence in `[0, 1]`, and a
/// top-left-normalized box. Each Vision backend maps its own observation onto this, so the wire
/// encoder never touches a Vision type.
struct RecognizedLineData {
  let text: String
  /// `[0, 1]`. Vision always supplies a per-candidate confidence, so this is never synthesized.
  let confidence: Double
  /// Top-left-normalized `[0, 1]`, so `minX` / `minY` are the box's left / top.
  let box: CGRect
}
