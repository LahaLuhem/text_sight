#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint text_sight.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'text_sight'
  s.version          = '0.0.1'
  s.summary          = 'Live, on-device text recognition — Apple Vision on iOS, ML Kit on Android.'
  s.description      = <<-DESC
Live, on-device text recognition — Apple Vision on iOS, ML Kit on Android. The text-scanning sibling to mobile_scanner.
                       DESC
  s.homepage         = 'https://github.com/LahaLuhem/text_sight'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'LahaLuhem' => 'github.reply.wb869@aleeas.com' }
  s.source           = { :path => '.' }
  s.source_files = 'text_sight/Sources/text_sight/**/*'
  s.dependency 'Flutter'
  # iOS 13.0 — the hybrid recognizer availability-gates Vision's Swift `RecognizeTextRequest`
  # (iOS 18+) against the legacy `VNRecognizeTextRequest` (iOS 13–17).
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'text_sight_privacy' => ['text_sight/Sources/text_sight/PrivacyInfo.xcprivacy']}
end
