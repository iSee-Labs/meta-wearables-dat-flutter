// iOS entry point of the meta_wearables_dat_flutter plugin.
//
// Bridges Meta's Wearables Device Access Toolkit 1.0 to Dart:
//   * one MethodChannel `meta_wearables_dat_flutter`
//   * EventChannels `meta_wearables_dat_flutter/<name>` (see `channels`)
// Components own their event sinks; this class only wires channels and
// routes method calls. Every failure crosses the channel in the shared
// error shape produced by `WireCodec` / `WireError`.

import Flutter
import UIKit

#if !canImport(MWDATCore)
#error("MWDATCore is missing. meta_wearables_dat_flutter needs Flutter >= 3.44 with Swift Package Manager enabled (the default) and Xcode 26.4+.")
#endif

import MWDATCamera
import MWDATCore
import MWDATDisplay
import MWDATMockDevice

public final class MetaWearablesDatPlugin: NSObject, FlutterPlugin {
  static let pluginVersion = "1.0.0"
  static let sdkVersion = "1.0.0"

  private static var configured = false
  private static var configureError: String?

  private weak var registrar: FlutterPluginRegistrar?

  @MainActor private lazy var hub = DeviceSessionHub()
  @MainActor private lazy var registration = RegistrationBridge()
  @MainActor private lazy var deviceState = DeviceStateObserver()
  @MainActor private lazy var camera = MetaSessionManager(registry: registrar!.textures(), hub: hub)
  @MainActor private lazy var display = MetaDisplayManager(hub: hub)
  @MainActor private lazy var mock = MetaMockDeviceManager()
  @MainActor private lazy var inputs = InputsBridge(hub: hub)
  @MainActor private lazy var motion = MotionBridge(hub: hub)
  @MainActor private lazy var speech = SpeechBridge(hub: hub)
  @MainActor private lazy var voice = VoiceInvocationsBridge()

  public static func register(with registrar: FlutterPluginRegistrar) {
    configureWearables()
    let instance = MetaWearablesDatPlugin()
    instance.registrar = registrar
    let channel = FlutterMethodChannel(name: "meta_wearables_dat_flutter", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
    MainActor.assumeIsolated { instance.registerEventChannels(registrar) }

    // Host apps with a UIScene lifecycle forward callback URLs by posting
    // `MetaWearablesDatHandleURL` with `userInfo["url"]`.
    NotificationCenter.default.addObserver(
      instance, selector: #selector(handleURLNotification(_:)),
      name: Notification.Name("MetaWearablesDatHandleURL"), object: nil)
    NotificationCenter.default.addObserver(
      instance, selector: #selector(didEnterBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
  }

  private static func configureWearables() {
    guard !configured else { return }
    do {
      try Wearables.configure()
      configured = true
    } catch {
      if error == .alreadyConfigured {
        configured = true
        return
      }
      configureError = String(describing: error)
      print("[meta_wearables_dat_flutter] Wearables.configure() failed: \(error). "
        + "Check the MWDAT dictionary in Info.plist.")
    }
  }

  // MARK: - Event channels

  @MainActor
  private func registerEventChannels(_ registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    func bind(_ name: String, _ handler: @autoclosure () -> NSObject & FlutterStreamHandler) {
      let channel = FlutterEventChannel(name: "meta_wearables_dat_flutter/\(name)", binaryMessenger: messenger)
      channel.setStreamHandler(Self.configured || name == "mock_devices"
        ? handler() : NotConfiguredStreamHandler(message: Self.configureError))
    }
    bind("registration_state", registration.stateSink)
    bind("registration_errors", registration.errorSink)
    bind("registration_requests", registration.requestSink)
    bind("active_device", deviceState.activeDeviceSink)
    bind("devices", deviceState.devicesSink)
    bind("device_state", deviceState.deviceStateSink)
    bind("compatibility", deviceState.compatibilitySink)
    bind("device_session_state", hub.stateSink)
    bind("device_session_errors", hub.errorSink)
    bind("stream_session_state", camera.stateSink)
    bind("stream_session_errors", camera.errorSink)
    bind("camera_state", camera.cameraStateSink)
    bind("video_stream_size", camera.sizeSink)
    bind("video_frames", camera.framesSink)
    bind("audio_frames", camera.audioSink)
    bind("photo_state", camera.photoStateSink)
    bind("photo_progress", camera.photoProgressSink)
    bind("photo_errors", camera.photoErrorSink)
    bind("display_state", display.stateSink)
    bind("display_events", display.eventsSink)
    bind("display_errors", display.errorSink)
    bind("inputs_state", inputs.stateSink)
    bind("inputs_events", inputs.eventsSink)
    bind("inputs_errors", inputs.errorSink)
    bind("motion_state", motion.stateSink)
    bind("motion_samples", motion.samplesSink)
    bind("motion_errors", motion.errorSink)
    bind("speech_state", speech.stateSink)
    bind("speech_transcriptions", speech.transcriptionsSink)
    bind("speech_errors", speech.errorSink)
    bind("voice_invocations", voice.invocationsSink)
    bind("voice_state", voice.stateSink)
    bind("voice_errors", voice.errorSink)
    bind("mock_devices", mock.devicesSink)
  }

  // MARK: - Method calls

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    Task { @MainActor in
      do {
        result(try await self.route(call))
      } catch {
        let wire = WireErrors.from(error)
        print("[meta_wearables_dat_flutter] \(call.method) failed: \(wire)")
        result(wire.flutterError)
      }
    }
  }

  /// Methods that work without a configured `Wearables` instance.
  private static let unconfiguredMethods: Set<String> = [
    "getPlatformVersion", "dumpDiagnostics", "requestAndroidPermissions",
  ]

  @MainActor
  private func route(_ call: FlutterMethodCall) async throws -> Any? {
    let args = call.arguments as? [String: Any] ?? [:]
    if !Self.configured, !Self.unconfiguredMethods.contains(call.method) {
      throw WireError(
        category: WireCategory.plugin, caseName: "wearablesNotConfigured",
        message: "Wearables.configure() failed: \(Self.configureError ?? "unknown error"). "
          + "Check the MWDAT dictionary in Info.plist.")
    }
    func string(_ key: String) -> String? { args[key] as? String }
    func required(_ key: String) throws -> String {
      guard let value = args[key] as? String, !value.isEmpty else {
        throw WireError.invalidArgument("\(call.method) requires a non-empty '\(key)'.")
      }
      return value
    }

    switch call.method {
    // Platform & diagnostics
    case "getPlatformVersion":
      return "iOS \(UIDevice.current.systemVersion)"
    case "dumpDiagnostics":
      return diagnostics()
    case "requestAndroidPermissions":
      return true  // iOS uses Info.plist usage strings.

    // Registration
    case "getRegistrationState":
      return registration.registrationState()
    case "startRegistration":
      try await registration.startRegistration()
      return nil
    case "startUnregistration":
      await hub.stopAll()
      try await registration.startUnregistration()
      return nil
    case "handleUrl":
      guard let url = URL(string: try required("url")) else {
        throw WireError(category: WireCategory.handleUrl, caseName: "invalidUrl", message: "Not a valid URL.")
      }
      return try await registration.handleUrl(url)
    case "continueRegistrationRequest":
      try await registration.answer(requestId: try required("requestId"), accept: true)
      return nil
    case "cancelRegistrationRequest":
      try await registration.answer(requestId: try required("requestId"), accept: false)
      return nil

    // Permissions & Meta AI navigation
    case "requestPermission":
      return try await registration.requestPermission(string("permission"))
    case "checkPermissionStatus":
      return try await registration.checkPermission(string("permission"))
    case "openFirmwareUpdate":
      try await registration.openFirmwareUpdate()
      return nil
    case "openDatGlassesAppUpdate":
      try await registration.openDatGlassesAppUpdate()
      return nil

    // Devices
    case "getDevices":
      return deviceState.allDevices()
    case "getDevice":
      return deviceState.device(try required("deviceUuid"))
    case "getSessionDevice":
      return hub.sessionDevice()

    // Camera
    case "startStreamSession":
      return try await camera.startSession(try StreamSessionArgs(args))
    case "stopStreamSession":
      await camera.stopSession()
      return nil
    case "capturePhoto":
      let format: PhotoCaptureFormat = string("format") == "heic" ? .heic : .jpeg
      let photo = try await camera.capturePhoto(format: format)
      return [
        "bytes": FlutterStandardTypedData(bytes: photo.data),
        "format": photo.format == .heic ? "heic" : "jpeg",
      ] as [String: Any]
    case "capturePhotoHq":
      let resolution = PhotoResolution(rawValue: string("resolution") ?? "medium") ?? .medium
      let quality = PhotoQuality(rawValue: string("quality") ?? "medium") ?? .medium
      let photo = try await camera.captureHqPhoto(resolution: resolution, quality: quality)
      var map: [String: Any] = [
        "bytes": FlutterStandardTypedData(bytes: photo.imageData),
        "timestampMs": Int(photo.timestamp.timeIntervalSince1970 * 1000),
      ]
      if let metadata = photo.metadata { map["metadata"] = FlutterStandardTypedData(bytes: metadata) }
      return map
    case "enableBackgroundStreaming":
      try BackgroundStreamingController.shared.enable()
      camera.softwareDecoder = true
      return nil
    case "disableBackgroundStreaming":
      BackgroundStreamingController.shared.disable()
      camera.softwareDecoder = false
      return nil

    // Display
    case "startDisplaySession":
      try await display.startDisplaySession(deviceUuid: string("deviceUuid"))
      return nil
    case "sendDisplayView":
      guard let view = args["view"] as? [String: Any] else {
        throw WireError.invalidArgument("sendDisplayView requires a 'view' map.")
      }
      return try await display.sendView(view)
    case "clearDisplay":
      try await display.clearDisplay()
      return nil
    case "stopDisplayVideo":
      await display.stopVideo()
      return nil
    case "stopDisplaySession":
      await display.stopDisplaySession()
      return nil

    // Experimental capabilities
    case "startInputs":
      try await inputs.start(args: args)
      return nil
    case "stopInputs":
      await inputs.stop()
      return nil
    case "startMotion":
      try await motion.start(args: args)
      return nil
    case "stopMotion":
      await motion.stop()
      return nil
    case "startSpeech":
      try await speech.start(args: args)
      return nil
    case "stopSpeech":
      await speech.stop()
      return nil
    case "startVoiceInvocations":
      try await voice.start(deviceUuid: string("deviceUuid"))
      return nil
    case "stopVoiceInvocations":
      await voice.stop()
      return nil
    case "respondVoiceInvocation":
      return try await voice.respond(
        invocationId: try required("invocationId"),
        success: (args["success"] as? Bool) ?? true,
        actionOutput: string("actionOutput"))

    // Mock Device Kit
    case "enableMockDevice":
      await mock.enable(
        initiallyRegistered: (args["initiallyRegistered"] as? Bool) ?? true,
        initialPermissionsGranted: (args["initialPermissionsGranted"] as? Bool) ?? true)
      return nil
    case "disableMockDevice":
      await hub.stopAll()
      await mock.disable()
      return nil
    case "isMockDeviceEnabled":
      return mock.isEnabled
    case "pairMockGlasses":
      guard let model = WireCodec.glassesModel(string("model") ?? "rayBanMeta") else {
        throw WireError.invalidArgument("Unknown glasses model '\(string("model") ?? "")'.")
      }
      return try mock.pair(model: model)
    case "pairedMockDevices":
      return mock.pairedDevices()
    case "unpairMockDevice":
      try await mock.unpair(uuid: try required("uuid"))
      return nil
    case "mockPowerOn", "mockPowerOff", "mockDon", "mockDoff", "mockFold", "mockUnfold",
      "mockCaptouchTap", "mockCaptouchTapAndHold":
      try mock.perform(call.method, uuid: try required("uuid"))
      return nil
    case "setMockBatteryLevel":
      try mock.setBatteryLevel(uuid: try required("uuid"), level: args["level"] as? Int)
      return nil
    case "setMockChargingState":
      try mock.setChargingState(uuid: try required("uuid"), raw: string("state"))
      return nil
    case "setMockThermalLevel":
      try mock.setThermalLevel(uuid: try required("uuid"), raw: string("level"))
      return nil
    case "setMockCameraFacing":
      try mock.setCameraFacing(uuid: try required("uuid"), facing: string("facing"))
      return nil
    case "setMockCameraFeed":
      try mock.setCameraFeed(uuid: try required("uuid"), path: string("filePath"))
      return nil
    case "setMockCapturedImage":
      try mock.setCapturedImage(uuid: try required("uuid"), path: string("filePath"))
      return nil
    case "setMockCapturedPhoto":
      try mock.setCapturedPhoto(uuid: try required("uuid"), path: string("filePath"))
      return nil
    case "simulateMockCaptureFailure":
      try mock.simulateCaptureFailure(uuid: try required("uuid"))
      return nil
    case "setMockPermission":
      try mock.setPermission(string("permission"), status: string("status"), requestResult: false)
      return nil
    case "setMockPermissionRequestResult":
      try mock.setPermission(string("permission"), status: string("status"), requestResult: true)
      return nil
    case "mockInput":
      try mock.input(uuid: try required("uuid"), args: args)
      return nil
    case "mockSpeech":
      try mock.speech(uuid: try required("uuid"), args: args)
      return nil
    case "setMockMotionFeed":
      try mock.setMotionFeed(uuid: try required("uuid"), args: args)
      return nil
    case "simulateMockVoiceInvocation":
      return try mock.voice(uuid: try required("uuid"), incomplete: (args["incomplete"] as? Bool) ?? false)
    case "startMockTestServer":
      return try await mock.startTestServer(port: (args["port"] as? Int) ?? 9000)
    case "stopMockTestServer":
      await mock.stopTestServer()
      return nil
    case "sendMockDisplayClick":
      return try mock.sendDisplayClick(uuid: try required("uuid"), identifier: try required("identifier"))

    default:
      return FlutterMethodNotImplemented
    }
  }

  // MARK: - URL forwarding

  /// Forwards Meta AI callback URLs (those carrying `metaWearablesAction`)
  /// to the SDK. Other URLs are left to the host app.
  public func application(
    _ application: UIApplication, open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard Self.configured else { return false }
    return MainActor.assumeIsolated { registration.consume(url) }
  }

  @objc private func handleURLNotification(_ notification: Notification) {
    guard Self.configured, let url = notification.userInfo?["url"] as? URL else { return }
    Task { @MainActor in _ = self.registration.consume(url) }
  }

  // MARK: - Background policy

  /// Mirrors Meta's CameraAccess sample: without background streaming the
  /// stream is ended when the app backgrounds. With background streaming,
  /// `raw` frames pause (the SDK only delivers them in the foreground)
  /// while `hvc1` keeps flowing.
  @objc private func didEnterBackground() {
    Task { @MainActor in
      guard Self.configured, self.camera.isStreaming else { return }
      if BackgroundStreamingController.shared.isEnabled {
        if self.camera.activeCodec == .raw {
          self.camera.errorSink.send(WireError(
            category: WireCategory.stream, caseName: "rawPausedInBackground",
            message: "Raw frames pause while the app is in the background; use hvc1 to keep streaming.",
            extras: ["severity": "warning"]
          ).eventPayload)
        }
      } else {
        self.camera.errorSink.send(WireError(
          category: WireCategory.stream, caseName: "stoppedInBackground",
          message: "The stream was stopped because the app moved to the background. "
            + "Call enableBackgroundStreaming() to keep it running.",
          extras: ["severity": "warning"]
        ).eventPayload)
        await self.camera.stopSession()
      }
    }
  }

  // MARK: - Diagnostics

  @MainActor
  private func diagnostics() -> [String: Any] {
    let info = Bundle.main.infoDictionary ?? [:]
    var map: [String: Any] = [
      "platform": "ios",
      "pluginVersion": Self.pluginVersion,
      "sdkVersion": Self.sdkVersion,
      "os": "iOS \(UIDevice.current.systemVersion)",
      "bundleId": Bundle.main.bundleIdentifier ?? "",
      "wearablesConfigured": Self.configured,
      "findings": InfoPlistValidator.validate(info).map(\.map),
      "resources": ResourceLedger.shared.snapshot(),
      "experimentalModulesLinked": ExperimentalModules.linked,
      "crashReportingOptOut": InfoPlistValidator.optOut(info, key: "CrashReporting"),
      "analyticsOptOut": InfoPlistValidator.optOut(info, key: "Analytics"),
      "backgroundStreamingEnabled": BackgroundStreamingController.shared.isEnabled,
      "config": [
        "MWDAT": (info["MWDAT"] as? [String: Any]) ?? [:],
        "CFBundleURLSchemes": (info["CFBundleURLTypes"] as? [[String: Any]] ?? [])
          .compactMap { $0["CFBundleURLSchemes"] as? [String] }.flatMap { $0 },
        "UIBackgroundModes": info["UIBackgroundModes"] as? [String] ?? [],
        "UISupportedExternalAccessoryProtocols": info["UISupportedExternalAccessoryProtocols"] as? [String] ?? [],
      ],
    ]
    if let error = Self.configureError { map["configureError"] = error }
    if Self.configured {
      map["registrationState"] = registration.registrationState()
      map["devices"] = deviceState.allDevices()
      if let device = hub.sessionDevice() { map["sessionDevice"] = device }
    } else {
      map["registrationState"] = "unavailable"
      map["devices"] = [[String: Any]]()
    }
    return map
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    NotificationCenter.default.removeObserver(self)
    Task { @MainActor in
      self.registration.dropPendingRequests()
      await self.voice.stop()
      await self.inputs.stop()
      await self.motion.stop()
      await self.speech.stop()
      await self.display.stopDisplaySession()
      await self.camera.stopSession()
      await self.hub.stopAll()
    }
  }
}

/// Stream handler used for every channel when `Wearables.configure()`
/// failed: reports the configuration error to the Dart listener.
private final class NotConfiguredStreamHandler: NSObject, FlutterStreamHandler {
  private let message: String?
  init(message: String?) { self.message = message }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    WireError(
      category: WireCategory.plugin, caseName: "wearablesNotConfigured",
      message: "Wearables.configure() failed: \(message ?? "unknown error").").flutterError
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? { nil }
}
