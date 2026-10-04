// Native unit tests for the plugin's pure Swift logic.
//
// Run: xcodebuild test -workspace example/ios/Runner.xcworkspace -scheme Runner \
//   -only-testing:RunnerTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

import Flutter
import MWDATCamera
import MWDATCore
import MWDATDisplay
import XCTest

@testable import meta_wearables_dat_flutter

// MARK: - StreamSessionArgs

final class StreamSessionArgsTests: XCTestCase {
  func testDefaults() throws {
    let args = try StreamSessionArgs(nil)
    XCTAssertNil(args.deviceUuid)
    XCTAssertEqual(args.frameRate, 24)
    XCTAssertEqual(args.resolution, .medium)
    XCTAssertEqual(args.videoCodec, .raw)
    XCTAssertNil(args.deviceKinds)
    XCTAssertNil(args.audioSampleRate)
  }

  func testParsesEveryField() throws {
    let args = try StreamSessionArgs([
      "deviceUuid": "abc",
      "fps": 30,
      "quality": "high",
      "videoCodec": "hvc1",
      "deviceKinds": ["glasses"],
      "audio": ["sampleRate": 48000, "channels": 1],
    ])
    XCTAssertEqual(args.deviceUuid, "abc")
    XCTAssertEqual(args.frameRate, 30)
    XCTAssertEqual(args.resolution, .high)
    XCTAssertEqual(args.videoCodec, .hvc1)
    XCTAssertEqual(args.deviceKinds, ["glasses"])
    XCTAssertEqual(args.audioSampleRate, .rate48000)
  }

  func testRejectsInvalidValues() {
    for bad: [String: Any] in [
      ["fps": 60], ["quality": "ultra"], ["videoCodec": "h264"],
      ["audio": ["sampleRate": 8000]],
    ] {
      XCTAssertThrowsError(try StreamSessionArgs(bad)) { error in
        XCTAssertEqual((error as? WireError)?.category, WireCategory.invalidArgument, "\(bad)")
      }
    }
  }
}

// MARK: - InfoPlistValidator

final class InfoPlistValidatorTests: XCTestCase {
  private func validPlist() -> [String: Any] {
    [
      "MWDAT": [
        "AppLinkURLScheme": "myapp://",
        "MetaAppID": "123",
        "ClientToken": "AR|123|abc",
        "TeamID": "TEAM123",
      ],
      "CFBundleURLTypes": [["CFBundleURLSchemes": ["myapp"]]],
      "LSApplicationQueriesSchemes": ["fb-viewapp"],
      "UISupportedExternalAccessoryProtocols": ["com.meta.ar.wearable"],
      "UIBackgroundModes": [
        "bluetooth-central", "bluetooth-peripheral", "external-accessory", "processing",
      ],
      "NSBluetoothAlwaysUsageDescription": "Connect to glasses",
      "NSLocalNetworkUsageDescription": "Talk to glasses",
      "NSMicrophoneUsageDescription": "Hear you",
      "NSBonjourServices": ["_mwdat._tcp"],
    ]
  }

  private func errors(_ info: [String: Any]) -> [String] {
    InfoPlistValidator.validate(info).filter { $0.severity == .error }.map(\.id)
  }

  func testValidPlistHasNoErrors() {
    XCTAssertEqual(errors(validPlist()), [])
  }

  func testMissingMwdatIsAnError() {
    var info = validPlist()
    info.removeValue(forKey: "MWDAT")
    XCTAssertTrue(errors(info).contains("mwdatMissing"))
  }

  func testSchemeMustEndWithColonSlashSlash() {
    var info = validPlist()
    var mwdat = info["MWDAT"] as! [String: Any]
    mwdat["AppLinkURLScheme"] = "myapp"
    info["MWDAT"] = mwdat
    XCTAssertTrue(errors(info).contains("appLinkUrlSchemeSuffix"))
  }

  func testSchemeMustBeRegistered() {
    var info = validPlist()
    info["CFBundleURLTypes"] = [["CFBundleURLSchemes": ["other"]]]
    XCTAssertTrue(errors(info).contains("appLinkUrlSchemeNotRegistered"))
  }

  func testRequiredBackgroundModesAndAccessoryProtocol() {
    var info = validPlist()
    info["UIBackgroundModes"] = ["bluetooth-central"]
    info["UISupportedExternalAccessoryProtocols"] = []
    let ids = errors(info)
    XCTAssertTrue(ids.contains("backgroundMode.external-accessory"))
    XCTAssertTrue(ids.contains("externalAccessoryProtocol"))
  }

  func testUsageDescriptionsRequired() {
    var info = validPlist()
    info.removeValue(forKey: "NSBluetoothAlwaysUsageDescription")
    info["NSLocalNetworkUsageDescription"] = ""
    let ids = InfoPlistValidator.validate(info).map(\.id)
    XCTAssertTrue(ids.contains("bluetoothUsageMissing"))
    XCTAssertTrue(ids.contains("localNetworkUsageMissing"))
  }

  func testSchemeSyntax() {
    XCTAssertTrue(InfoPlistValidator.isValidScheme("my-app.v2"))
    XCTAssertFalse(InfoPlistValidator.isValidScheme("2app"))
    XCTAssertFalse(InfoPlistValidator.isValidScheme(""))
  }
}

// MARK: - WireCodec / WireError

final class WireCodecTests: XCTestCase {
  func testErrorShapes() {
    let error = WireError(
      category: WireCategory.stream, caseName: "hingesClosed", message: "Closed",
      platformCase: "hingesClosed", extras: ["fatal": true])
    let flutter = error.flutterError
    XCTAssertEqual(flutter.code, "STREAM_ERROR")
    let details = flutter.details as? [String: Any]
    XCTAssertEqual(details?["case"] as? String, "hingesClosed")
    XCTAssertEqual(details?["platform"] as? String, "ios")
    XCTAssertEqual(details?["fatal"] as? Bool, true)
    let event = error.eventPayload
    XCTAssertEqual(event["code"] as? String, "hingesClosed")
    XCTAssertEqual(event["category"] as? String, "STREAM_ERROR")
  }

  func testStateEncoders() {
    XCTAssertEqual(WireCodec.streamState(.streaming), "streaming")
    XCTAssertEqual(WireCodec.streamState(.stopped), "stopped")
    XCTAssertEqual(WireCodec.displayState(.started), "started")
    XCTAssertEqual(WireCodec.thermalLevel(.severe), "severe")
  }

  func testParsersRoundTrip() {
    for raw in ["none", "light", "moderate", "severe", "critical", "emergency", "shutdown"] {
      let level = WireCodec.parseThermalLevel(raw)
      XCTAssertNotNil(level, raw)
      if let level { XCTAssertEqual(WireCodec.thermalLevel(level), raw) }
    }
    XCTAssertNil(WireCodec.parseThermalLevel("toasty"))
    XCTAssertEqual(WireCodec.permission("camera"), .camera)
    XCTAssertNil(WireCodec.permission("location"))
  }

  func testStreamErrorsUseCanonicalCases() {
    XCTAssertEqual(WireCodec.error(StreamError.hingesClosed).caseName, "hingesClosed")
    XCTAssertEqual(WireCodec.error(StreamError.hingesClosed).category, WireCategory.stream)
  }
}

// MARK: - Display

@MainActor
final class DisplayNodeTests: XCTestCase {
  /// Every icon the Dart DSL can send (generated from tool/display_icons.json).
  static let dartIcons: [String] = [
    "airplane",
    "arrowDownShallowU",
    "arrowLeft",
    "arrowRight",
    "arrowULeft",
    "arrowUpShallowU",
    "avatar",
    "avatarOff",
    "bedSide",
    "bell",
    "bellDiagonalRightDot",
    "bellOff",
    "bikeShare",
    "bug",
    "bullhorn",
    "bus",
    "calendar",
    "campfire",
    "caretDown",
    "caretLeft",
    "caretRight",
    "caretUp",
    "carFrontView",
    "cart",
    "checkmark",
    "checkmarkCircle",
    "circle8RaysLarge",
    "circleHandle",
    "clock",
    "cloud",
    "cloudCrescentMoon",
    "cloudDotFourRays",
    "cloudFiveDashes",
    "cloudHookSwirl",
    "cloudLightning",
    "cocktailGlass",
    "code",
    "coffeeCup",
    "compassNorthUpRed",
    "containerWithLid",
    "crossBriefcase",
    "dropper",
    "envelopeOpen",
    "exclamationCircle",
    "exclamationTriangle",
    "eye",
    "forkKnife",
    "fourArcsUpFilled",
    "fourArcsUpGrayscale",
    "fourCornerFrame",
    "gear",
    "globeWesternHemisphere",
    "graduationCap",
    "hashtag",
    "headphones",
    "heart",
    "house",
    "iCircle",
    "lightBulb",
    "magicWand",
    "metaAi",
    "mountainSquare",
    "mountainSquareStacked",
    "museumBuilding",
    "musicNote",
    "nineSquaresGrid",
    "padlockClosed",
    "padlockOpen",
    "palette",
    "paperAirplane",
    "pencil",
    "pencilSquare",
    "person",
    "personCircle",
    "phone",
    "phoneHandsetArrowDownLeft",
    "phoneHandsetArrowUpRight",
    "phoneSlash",
    "pizzaSlice",
    "plus",
    "plusCircle",
    "shoppingBag",
    "slidersHorizontal",
    "smartGlasses",
    "smileyCircle",
    "speakerOff",
    "speakerWithOneArc",
    "speakerWithThreeArcs",
    "speakerWithTwoArcs",
    "speechBubble",
    "speechBubbleOff",
    "stadium",
    "star",
    "starCircleTriangleAi",
    "taxi",
    "threeDotsHorizontal",
    "threeDotSpeechBubble",
    "threeHorizontalLines",
    "threeHorizontalLinesStackedDescending",
    "threePeopleOverlapping",
    "train",
    "tree",
    "triangleLeftVerticalLine",
    "triangleRight",
    "triangleRightCircle",
    "triangleRightVerticalLine",
    "twoArrowsClockwise",
    "twoLinesParallel",
    "twoSquaresStackedRightDown",
    "twoTrianglesLeft",
    "twoTrianglesRight",
    "videoCamera",
    "videoCameraOff",
    "wristband",
    "wristbandSlash",
    "x"
  ]

  func testEveryDartIconResolves() {
    XCTAssertEqual(Self.dartIcons.count, 116)
    for name in Self.dartIcons {
      XCTAssertNotNil(
        IconName(rawValue: DisplayNodeBuilder.iconRawValue(name)),
        "\(name) -> \(DisplayNodeBuilder.iconRawValue(name))")
    }
  }

  func testIconRawValueConversion() {
    XCTAssertEqual(DisplayNodeBuilder.iconRawValue("checkmarkCircle"), "checkmark_circle")
    XCTAssertEqual(DisplayNodeBuilder.iconRawValue("circle8RaysLarge"), "circle_8_rays_large")
    XCTAssertEqual(DisplayNodeBuilder.iconRawValue("arrowULeft"), "arrow_u_left")
  }

  func testUnknownIconWarnsInsteadOfFailing() {
    var builder = DisplayNodeBuilder { _, _ in }
    _ = builder.buildRoot([
      "type": "flexBox",
      "children": [
        ["type": "text", "text": "Hello"],
        ["type": "icon", "iconName": "notAnIcon"],
      ],
    ])
    XCTAssertEqual(builder.warnings.count, 1)
  }
}

// MARK: - ResourceLedger

@MainActor
final class ResourceLedgerTests: XCTestCase {
  func testAcquireReleaseNeverNegative() {
    let ledger = ResourceLedger.shared
    let before = ledger.snapshot()["textures"] ?? 0
    ledger.acquire(.textures)
    XCTAssertEqual(ledger.snapshot()["textures"], before + 1)
    ledger.release(.textures)
    ledger.release(.textures, before + 5)
    XCTAssertEqual(ledger.snapshot()["textures"], 0)
    ledger.set(.textures, before)
  }
}
