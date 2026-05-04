// `meta_wearables_dat_flutter` iOS plugin.
//
// Slice 2: register the MethodChannel and force-link MWDAT.
// Slice 4: implement `requestAndroidPermissions` as a no-op returning true.
// Slice 5: registration flow - `startRegistration`, `startUnregistration`,
//          `handleUrl`, `getRegistrationState`, plus the
//          `registration_state` and `active_device` EventChannels driven by
//          `Wearables.shared.registrationStateStream()` and
//          `AutoDeviceSelector`.

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

// MARK: - Plugin registration

public class MetaWearablesDatPlugin: NSObject, FlutterPlugin {
  // `Wearables.configure()` is global; ensure exactly-once across hot
  // restarts by tracking it in a static.
  private static var didConfigure = false

  // Stream handlers retained on the plugin instance so their cancellation
  // tokens survive past `register(with:)`.
  private let registrationStateHandler = RegistrationStateStreamHandler()
  private let activeDeviceHandler = ActiveDeviceStreamHandler()

  public static func register(with registrar: FlutterPluginRegistrar) {
    if !didConfigure {
      do {
        try Wearables.configure()
        didConfigure = true
      } catch {
        // Configuration may legitimately fail in unit-test bundles or when
        // the host app's Info.plist `MWDAT` dict is missing. We log instead
        // of crashing so the host app can still call non-DAT APIs.
        NSLog("[meta_wearables_dat_flutter] Wearables.configure() failed: \(error)")
      }
    }

    let methodChannel = FlutterMethodChannel(
      name: "meta_wearables_dat_flutter",
      binaryMessenger: registrar.messenger()
    )

    let registrationStateChannel = FlutterEventChannel(
      name: "meta_wearables_dat_flutter/registration_state",
      binaryMessenger: registrar.messenger()
    )

    let activeDeviceChannel = FlutterEventChannel(
      name: "meta_wearables_dat_flutter/active_device",
      binaryMessenger: registrar.messenger()
    )

    let instance = MetaWearablesDatPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    registrationStateChannel.setStreamHandler(instance.registrationStateHandler)
    activeDeviceChannel.setStreamHandler(instance.activeDeviceHandler)
  }

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS \(UIDevice.current.systemVersion)")

    case "requestAndroidPermissions":
      // Documented no-op on iOS: iOS uses Info.plist usage strings, not
      // runtime permission grants. Lets host apps call the API
      // unconditionally.
      result(true)

    case "startRegistration":
      Task { @MainActor in
        do {
          try await Wearables.shared.startRegistration()
          result(nil)
        } catch let error as RegistrationError {
          result(FlutterError(
            code: "REGISTRATION_ERROR",
            message: String(describing: error),
            details: nil
          ))
        } catch {
          result(FlutterError(
            code: "REGISTRATION_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }

    case "startUnregistration":
      Task { @MainActor in
        do {
          try await Wearables.shared.startUnregistration()
          result(nil)
        } catch let error as UnregistrationError {
          result(FlutterError(
            code: "REGISTRATION_ERROR",
            message: String(describing: error),
            details: nil
          ))
        } catch {
          result(FlutterError(
            code: "REGISTRATION_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }

    case "handleUrl":
      guard
        let args = call.arguments as? [String: Any?],
        let urlString = args["url"] as? String,
        let url = URL(string: urlString)
      else {
        result(FlutterError(
          code: "INVALID_ARGUMENT",
          message: "handleUrl requires { url: String }",
          details: nil
        ))
        return
      }
      Task { @MainActor in
        do {
          let consumed = try await Wearables.shared.handleUrl(url)
          result(consumed)
        } catch let error as RegistrationError {
          result(FlutterError(
            code: "REGISTRATION_ERROR",
            message: String(describing: error),
            details: nil
          ))
        } catch {
          result(FlutterError(
            code: "REGISTRATION_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }

    case "getRegistrationState":
      result(Wearables.shared.registrationState.rawValue)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - Stream handlers

/// Forwards `Wearables.shared.registrationStateStream()` events to a Flutter
/// EventSink as `Int` values matching `RegistrationState.fromInt` on the
/// Dart side. Seeds the initial value so a brand-new listener does not need
/// to wait for the next state change.
private final class RegistrationStateStreamHandler: NSObject, FlutterStreamHandler {
  private var task: Task<Void, Never>?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    task?.cancel()
    task = Task { @MainActor in
      // Seed the current value first so UI built on `StreamBuilder` shows
      // the correct state on initial subscribe.
      events(Wearables.shared.registrationState.rawValue)
      for await state in Wearables.shared.registrationStateStream() {
        if Task.isCancelled { break }
        events(state.rawValue)
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    task?.cancel()
    task = nil
    return nil
  }
}

/// Forwards `AutoDeviceSelector` events to a Flutter EventSink as either
/// a serialised `DeviceInfo` map or `nil` when no device is active.
/// Long-lived: created once and held by the plugin instance.
private final class ActiveDeviceStreamHandler: NSObject, FlutterStreamHandler {
  private var task: Task<Void, Never>?
  private var selector: AutoDeviceSelector?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    task?.cancel()
    let auto = AutoDeviceSelector(wearables: Wearables.shared)
    selector = auto

    task = Task { @MainActor in
      // Seed the current value to avoid the "stuck waiting for first event"
      // case when a device is already attached at subscribe time.
      events(Self.encode(auto.activeDevice))
      for await deviceId in auto.activeDeviceStream() {
        if Task.isCancelled { break }
        events(Self.encode(deviceId))
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    task?.cancel()
    task = nil
    selector = nil
    return nil
  }

  /// Serialises a `DeviceIdentifier` (typealias for `String`) to the map
  /// shape that `DeviceInfo.fromMap` expects on the Dart side. Returns
  /// `NSNull` so the Flutter codec emits a Dart `null` when no device is
  /// active.
  @MainActor
  private static func encode(_ id: DeviceIdentifier?) -> Any {
    guard let id else { return NSNull() }
    let device = Wearables.shared.deviceForIdentifier(id)
    let name = device?.nameOrId() ?? id
    let kind: String
    switch device?.deviceType() {
    case .rayBanMeta?, .rayBanMetaOptics?:
      kind = "rayBanMeta"
    case .metaRayBanDisplay?:
      kind = "rayBanDisplay"
    case .oakleyMetaHSTN?, .oakleyMetaVanguard?:
      kind = "oakleyMeta"
    case .unknown?, .none:
      kind = "unknown"
    @unknown default:
      kind = "unknown"
    }
    return [
      "uuid": id,
      "name": name,
      "kind": kind,
    ] as [String: Any]
  }
}
