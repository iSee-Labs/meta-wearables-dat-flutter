// swift-tools-version: 6.0
//
// Swift Package for the meta_wearables_dat_flutter plugin.
//
// Flutter (>= 3.44, where Swift Package Manager is the default) resolves this
// package together with Meta's official Wearables Device Access Toolkit
// (`facebook/meta-wearables-dat-ios`). Meta ships the SDK as binary
// xcframeworks built with Swift 6.3 for iOS 17.2, so consumers need
// Xcode 26.4 or newer.

import PackageDescription

let package = Package(
  name: "meta_wearables_dat_flutter",
  platforms: [
    .iOS("17.2"),
  ],
  products: [
    .library(
      name: "meta-wearables-dat-flutter",
      targets: ["meta_wearables_dat_flutter"]
    ),
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
    // Pinned exactly: the bridge maps every SDK enum case explicitly, so a
    // new DAT release is adopted deliberately in a matching plugin release.
    .package(
      url: "https://github.com/facebook/meta-wearables-dat-ios",
      exact: "1.0.0"
    ),
  ],
  targets: [
    .target(
      name: "meta_wearables_dat_flutter",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
        .product(name: "MWDATCore", package: "meta-wearables-dat-ios"),
        .product(name: "MWDATCamera", package: "meta-wearables-dat-ios"),
        .product(name: "MWDATDisplay", package: "meta-wearables-dat-ios"),
        .product(name: "MWDATMockDevice", package: "meta-wearables-dat-ios"),
        // Experimental DAT 1.0 capabilities. Meta does not allow apps that
        // use them in production release channels; the plugin only calls
        // into them when the host app invokes an experimental API.
        .product(name: "MWDATInputs", package: "meta-wearables-dat-ios"),
        .product(name: "MWDATMotion", package: "meta-wearables-dat-ios"),
        .product(name: "MWDATSpeech", package: "meta-wearables-dat-ios"),
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy"),
      ]
    ),
  ],
  swiftLanguageModes: [.v5]
)
