#
# Podspec for meta_wearables_dat_flutter.
#
# This plugin is *Swift Package Manager only*. Meta's official iOS DAT SDK
# (MWDATCore, MWDATCamera, MWDATDisplay, MWDATMockDevice, MWDATInputs,
# MWDATMotion, MWDATSpeech) is distributed as binary xcframeworks through
# Swift Package Manager and is consumed in
# `meta_wearables_dat_flutter/Package.swift`; it is not vendored here.
#
# Requirements: Flutter >= 3.44 (Swift Package Manager on by default),
# Xcode 26.4+, iOS 17.2+. CocoaPods-only builds are not supported: the Swift
# sources emit a clear `#error` when the SDK modules are missing.
#
Pod::Spec.new do |s|
  s.name             = 'meta_wearables_dat_flutter'
  s.version          = '1.0.0-rc.1'
  s.summary          = 'Unofficial Flutter plugin for Meta\'s Wearables Device Access Toolkit.'
  s.description      = <<-DESC
Unofficial Flutter plugin bridging Meta's iOS and Android Wearables Device
Access Toolkit (DAT) SDKs. iOS dependencies are linked via Swift Package
Manager; this podspec only declares the Flutter dependency and Apple system
frameworks.
                       DESC
  s.homepage         = 'https://github.com/iSee-Labs/meta-wearables-dat-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'iSee Labs' => 'https://github.com/iSee-Labs' }
  s.source           = { :path => '.' }
  s.source_files     = 'meta_wearables_dat_flutter/Sources/meta_wearables_dat_flutter/**/*.swift'

  s.dependency 'Flutter'

  s.platform         = :ios, '17.2'
  s.swift_version    = '6.0'

  s.frameworks = 'CoreBluetooth', 'Network', 'AVFoundation', 'ExternalAccessory', 'VideoToolbox'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
end
