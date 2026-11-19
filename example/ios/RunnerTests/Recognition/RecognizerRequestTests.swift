import CoreGraphics
import Testing
import Vision

@testable import text_sight

/// The modern half needs iOS 18, so older runtimes skip it.
@Suite("Vision request mapping")
struct RecognizerRequestTests {
  static let levels: [RecognitionLevelMessage] = [.fast, .accurate]

  /// The scan box every region-of-interest case uses, and the region Vision should read: the box
  /// plus half its height above and below, lower-left normalized.
  static let roi = RegionOfInterestMessage(left: 0.1, top: 0.2, width: 0.3, height: 0.4)
  static let flippedRead = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.8)

  static let languages = ["en-US", "fr"]

  static let wholeFrame = CGRect(x: 0, y: 0, width: 1, height: 1)

  /// A floor Vision would act on, so a pass proves the config got through rather than matching
  /// a default.
  static let textHeightFloor: Float = 0.05

  @available(iOS 18, *)
  @Test("Modern: the level maps straight through", arguments: RecognizerRequestTests.levels)
  func modernLevel(level: RecognitionLevelMessage) {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: level, usesLanguageCorrection: true,
                                languages: [], minimumTextHeight: 0, roi: nil)
    )

    #expect(request.recognitionLevel == (level == .fast ? .fast : .accurate))
  }

  // Pinned at `.fast` on purpose: correction used to ride the level, and this is what proves it no
  // longer does.
  @available(iOS 18, *)
  @Test("Modern: language correction is its own knob", arguments: [true, false])
  func modernCorrection(correction: Bool) {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, usesLanguageCorrection: correction,
                                languages: [], minimumTextHeight: 0, roi: nil)
    )

    #expect(request.usesLanguageCorrection == correction)
  }

  @available(iOS 18, *)
  @Test("Modern: languages map in preference order")
  func modernLanguages() {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, usesLanguageCorrection: true,
                                languages: Self.languages, minimumTextHeight: 0, roi: nil)
    )

    #expect(request.recognitionLanguages == Self.languages.map(Locale.Language.init(identifier:)))
  }

  @available(iOS 18, *)
  @Test("Modern: the read region flips into Vision's lower-left space")
  func modernRegion() {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, usesLanguageCorrection: true,
                                languages: [], minimumTextHeight: 0, roi: Self.roi)
    )

    let region = request.regionOfInterest

    #expect(isClose(originX: region.origin.x, originY: region.origin.y,
                    width: region.width, height: region.height, to: Self.flippedRead))
  }

  @Test("Legacy: the level maps straight through", arguments: RecognizerRequestTests.levels)
  func legacyLevel(level: RecognitionLevelMessage) {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: level, usesLanguageCorrection: true,
                                languages: [], minimumTextHeight: 0, roi: nil)
    )

    #expect(request.recognitionLevel == (level == .fast ? .fast : .accurate))
  }

  @Test("Legacy: language correction is its own knob", arguments: [true, false])
  func legacyCorrection(correction: Bool) {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, usesLanguageCorrection: correction,
                                languages: [], minimumTextHeight: 0, roi: nil)
    )

    #expect(request.usesLanguageCorrection == correction)
  }

  @Test("Legacy: languages pass through in order")
  func legacyLanguages() {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, usesLanguageCorrection: true,
                                languages: Self.languages, minimumTextHeight: 0, roi: nil)
    )

    #expect(request.recognitionLanguages == Self.languages)
  }

  @Test("Legacy: the read region flips into Vision's lower-left space")
  func legacyRegion() {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, usesLanguageCorrection: true,
                                languages: [], minimumTextHeight: 0, roi: Self.roi)
    )

    let region = request.regionOfInterest

    #expect(isClose(originX: region.origin.x, originY: region.origin.y,
                    width: region.width, height: region.height, to: Self.flippedRead))
  }

  @available(iOS 18, *)
  @Test("Modern: the text-height floor reaches the request")
  func modernTextHeightFloor() {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, usesLanguageCorrection: true,
                                languages: [], minimumTextHeight: Self.textHeightFloor, roi: nil)
    )

    #expect(request.minimumTextHeightFraction == Self.textHeightFloor)
  }

  @Test("Legacy: the text-height floor reaches the request")
  func legacyTextHeightFloor() {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, usesLanguageCorrection: true,
                                languages: [], minimumTextHeight: Self.textHeightFloor, roi: nil)
    )

    #expect(request.minimumTextHeight == Self.textHeightFloor)
  }

  // The floor is frame-relative in public, but Vision measures it against the region it reads, so a
  // 0.8-tall read has to be asked for 1.25x the number or the same text stops being readable.
  @available(iOS 18, *)
  @Test("Modern: the text-height floor is scaled to the read region")
  func modernFloorScalesToRoi() {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, usesLanguageCorrection: true,
                                languages: [], minimumTextHeight: Self.textHeightFloor,
                                roi: Self.roi)
    )

    #expect(request.minimumTextHeightFraction == Self.textHeightFloor / Float(Self.flippedRead.height))
  }

  @Test("Legacy: the text-height floor is scaled to the read region")
  func legacyFloorScalesToRoi() {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, usesLanguageCorrection: true,
                                languages: [], minimumTextHeight: Self.textHeightFloor,
                                roi: Self.roi)
    )

    #expect(request.minimumTextHeight == Self.textHeightFloor / Float(Self.flippedRead.height))
  }

  @available(iOS 18, *)
  @Test("Modern: a bare config still leaves nothing to Vision")
  func modernFillsEveryKnob() {
    let request = ModernTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, usesLanguageCorrection: true,
                                languages: [], minimumTextHeight: 0, roi: nil)
    )
    let region = request.regionOfInterest

    #expect(request.minimumTextHeightFraction == 0)
    #expect(request.recognitionLanguages.isEmpty)
    #expect(isClose(originX: region.origin.x, originY: region.origin.y,
                    width: region.width, height: region.height, to: Self.wholeFrame))
  }

  @Test("Legacy: a bare config still leaves nothing to Vision")
  func legacyFillsEveryKnob() {
    let request = LegacyTextRecognizer.makeRequest(
      config: RecognitionConfig(level: .fast, usesLanguageCorrection: true,
                                languages: [], minimumTextHeight: 0, roi: nil)
    )
    let region = request.regionOfInterest

    #expect(request.minimumTextHeight == 0)
    #expect(request.recognitionLanguages.isEmpty)
    #expect(isClose(originX: region.origin.x, originY: region.origin.y,
                    width: region.width, height: region.height, to: Self.wholeFrame))
  }
}

/// Corner-by-corner match with a float tolerance, since the lower-left flip carries sub-epsilon
/// error. Takes the components rather than a rect: the modern backend hands back Vision's
/// `NormalizedRect` and the legacy one a `CGRect`.
private func isClose(originX: Double, originY: Double, width: Double, height: Double,
                     to expected: CGRect, tolerance: Double = 1e-9) -> Bool {
  abs(originX - expected.origin.x) < tolerance && abs(originY - expected.origin.y) < tolerance
    && abs(width - expected.width) < tolerance && abs(height - expected.height) < tolerance
}
