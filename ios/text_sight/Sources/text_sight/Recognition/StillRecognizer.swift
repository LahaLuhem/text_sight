import CoreGraphics
import Flutter
import Foundation
import ImageIO

/// The one-shot driver: reads a still, with no session, texture or permission.
struct StillRecognizer {
  /// Shared with the live driver.
  let recognizer: any TextRecognizer

  func recognizeImage(bytes: FlutterStandardTypedData,
                      options: TextSightOptionsMessage) async throws -> [String: Any?] {
    // Never fails in practice, since it takes any Data. A bad image throws later, in
    // recognizeStill.
    guard let source = CGImageSourceCreateWithData(bytes.data as CFData, nil) else {
      throw PigeonError(code: "decode-failed",
                        message: "The image bytes could not be decoded.", details: nil)
    }

    return try await recognizeStill(source, options: options)
  }

  func recognizePath(path: String,
                     options: TextSightOptionsMessage) async throws -> [String: Any?] {
    guard FileManager.default.fileExists(atPath: path) else {
      throw PigeonError(code: "file-not-found", message: "No file exists at \(path).", details: nil)
    }
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
      throw PigeonError(code: "decode-failed",
                        message: "The image at \(path) could not be decoded.", details: nil)
    }

    return try await recognizeStill(source, options: options)
  }

  /// The same map a live frame sends, with `quarterTurns` 0 since a still is upright.
  private func recognizeStill(_ source: CGImageSource,
                              options: TextSightOptionsMessage) async throws -> [String: Any?] {
    let config = RecognitionConfig(level: options.level,
                                   usesLanguageCorrection: options.usesLanguageCorrection,
                                   languages: options.languages,
                                   minimumTextHeight: Float(options.minimumTextHeight),
                                   roi: options.roi)

    guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw PigeonError(code: "decode-failed", message: "The image could not be decoded.",
                        details: nil)
    }

    let orientation = Self.orientation(of: source)
    // Report the size the boxes are in, so width and height swap when EXIF turns the image.
    let isQuarterTurned = switch orientation {
    case .left, .leftMirrored, .right, .rightMirrored: true
    default: false
    }
    let pixelWidth = Double(cgImage.width)
    let pixelHeight = Double(cgImage.height)

    do {
      let lines = try await recognizer.recognize(cgImage: cgImage, orientation: orientation,
                                                 config: config)

      return FrameEncoding.encodeFrame(config.region.keep(lines),
                                       imageWidth: isQuarterTurned ? pixelHeight : pixelWidth,
                                       imageHeight: isQuarterTurned ? pixelWidth : pixelHeight,
                                       quarterTurns: 0)
    } catch {
      throw PigeonError(code: "decode-failed", message: error.localizedDescription, details: nil)
    }
  }

  /// The EXIF orientation stored in `source`, or `.up` when absent.
  private static func orientation(of source: CGImageSource) -> CGImagePropertyOrientation {
    guard
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let raw = properties[kCGImagePropertyOrientation] as? UInt32,
      let orientation = CGImagePropertyOrientation(rawValue: raw)
    else { return .up }

    return orientation
  }
}
