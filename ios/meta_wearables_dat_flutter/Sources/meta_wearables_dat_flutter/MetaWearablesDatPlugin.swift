// Slice 2 stub: registers the plugin's MethodChannel and force-links Meta's
// iOS DAT SDK (`MWDATCore`, `MWDATCamera`) so that the SPM dependency wiring
// is exercised by the build. Real method handlers arrive starting in slice 4.

import Flutter
import UIKit

#if !canImport(MWDATCore)
#error("Missing MWDATCore. Enable Flutter's Swift Package Manager support: `flutter config --enable-swift-package-manager` and use Xcode 15.4+.")
#endif

#if !canImport(MWDATCamera)
#error("Missing MWDATCamera. Enable Flutter's Swift Package Manager support: `flutter config --enable-swift-package-manager` and use Xcode 15.4+.")
#endif

import MWDATCore
import MWDATCamera

public class MetaWearablesDatPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "meta_wearables_dat_flutter",
      binaryMessenger: registrar.messenger()
    )
    let instance = MetaWearablesDatPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS \(UIDevice.current.systemVersion)")
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
