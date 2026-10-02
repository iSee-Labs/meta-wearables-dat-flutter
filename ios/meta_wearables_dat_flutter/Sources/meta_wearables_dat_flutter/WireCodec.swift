// Wire encoding shared by every iOS bridge component.
//
// Every value that crosses the platform channel is produced here, so the
// Dart side and the Android bridge (`WireCodec.kt`) can rely on one table of
// names. Enum values travel as lowerCamelCase strings that match the iOS
// SDK case names. Errors travel as:
//
//   * method-call failures: FlutterError(code: <CATEGORY>, message:
//     <description>, details: {case, description, platformCase, platform,
//     ...extras})
//   * event-channel errors: {code: <case>, category: <CATEGORY>, message,
//     platformCase, platform, ...extras}
//
// Every `switch` below is exhaustive over the DAT 1.0.0 cases, with an
// `@unknown default` that reports `unknown` plus the raw `platformCase` so
// nothing is lost if Meta adds a case in a later SDK.

import Flutter
import Foundation
import MWDATCamera
import MWDATCore
import MWDATDisplay
import MWDATMockDevice

/// Error categories shared with Dart (`DatErrorCodes`) and Android.
enum WireCategory {
  static let registration = "REGISTRATION_ERROR"
  static let unregistration = "UNREGISTRATION_ERROR"
  static let handleUrl = "HANDLE_URL_ERROR"
  static let registrationRequest = "REGISTRATION_REQUEST_ERROR"
  static let permission = "PERMISSION_ERROR"
  static let navigation = "NAVIGATION_ERROR"
  static let deviceSession = "DEVICE_SESSION_ERROR"
  static let stream = "STREAM_ERROR"
  static let capture = "CAPTURE_ERROR"
  static let photo = "PHOTO_ERROR"
  static let display = "DISPLAY_ERROR"
  static let inputs = "INPUTS_ERROR"
  static let motion = "MOTION_ERROR"
  static let speech = "SPEECH_ERROR"
  static let voiceInvocation = "VOICE_INVOCATION_ERROR"
  static let mock = "MOCK_ERROR"
  static let invalidArgument = "INVALID_ARGUMENT"
  static let notSupported = "NOT_SUPPORTED"
  static let experimentalNotLinked = "EXPERIMENTAL_NOT_LINKED"
  static let plugin = "PLUGIN_ERROR"
}

/// A plugin error in wire form. Thrown by bridge components and converted to
/// a `FlutterError` (method calls) or an event map (event channels).
struct WireError: Error, CustomStringConvertible {
  let category: String
  let caseName: String
  let message: String
  let platformCase: String?
  var extras: [String: Any] = [:]

  init(
    category: String,
    caseName: String,
    message: String,
    platformCase: String? = nil,
    extras: [String: Any] = [:]
  ) {
    self.category = category
    self.caseName = caseName
    self.message = message
    self.platformCase = platformCase
    self.extras = extras
  }

  var description: String { "\(category)/\(caseName): \(message)" }

  var details: [String: Any] {
    var map: [String: Any] = [
      "case": caseName,
      "description": message,
      "platform": "ios",
    ]
    if let platformCase { map["platformCase"] = platformCase }
    for (key, value) in extras { map[key] = value }
    return map
  }

  var flutterError: FlutterError {
    FlutterError(code: category, message: message, details: details)
  }

  var eventPayload: [String: Any] {
    var map: [String: Any] = [
      "code": caseName,
      "category": category,
      "message": message,
      "platform": "ios",
    ]
    if let platformCase { map["platformCase"] = platformCase }
    for (key, value) in extras { map[key] = value }
    return map
  }

  // MARK: Plugin-side errors

  static func invalidArgument(_ message: String) -> WireError {
    WireError(category: WireCategory.invalidArgument, caseName: "invalidArgument", message: message)
  }

  static func plugin(_ caseName: String, _ message: String) -> WireError {
    WireError(category: WireCategory.plugin, caseName: caseName, message: message)
  }
}

/// Converts any thrown error into wire form. Typed SDK errors keep their
/// category; anything else becomes `PLUGIN_ERROR/unknown`.
enum WireErrors {
  static func from(_ error: Error, fallbackCategory: String = WireCategory.plugin) -> WireError {
    if let wire = error as? WireError { return wire }
    if let e = error as? RegistrationError { return WireCodec.error(e) }
    if let e = error as? UnregistrationError { return WireCodec.error(e) }
    if let e = error as? WearablesHandleURLError { return WireCodec.error(e) }
    if let e = error as? RegistrationRequestError { return WireCodec.error(e) }
    if let e = error as? PermissionError { return WireCodec.error(e) }
    if let e = error as? NavigationError { return WireCodec.error(e) }
    if let e = error as? DeviceSessionError { return WireCodec.error(e) }
    if let e = error as? StreamError { return WireCodec.error(e) }
    if let e = error as? PhotoError { return WireCodec.error(e) }
    if let e = error as? DisplayError { return WireCodec.error(e) }
    if let e = error as? VideoError { return WireCodec.error(e) }
    if let e = error as? MockDeviceKitError { return WireCodec.error(e) }
    if let e = error as? VoiceInvocationError { return WireCodec.error(e) }
    if let e = error as? WearablesError {
      return WireError(
        category: WireCategory.plugin,
        caseName: "wearablesNotConfigured",
        message: e.localizedDescription,
        platformCase: String(describing: e)
      )
    }
    return WireError(
      category: fallbackCategory,
      caseName: "unknown",
      message: error.localizedDescription,
      platformCase: String(describing: type(of: error))
    )
  }
}

enum WireCodec {
  /// The case label of an enum value, without associated values or module
  /// prefix (`deviceNotFound("x")` -> `deviceNotFound`).
  static func caseLabel(_ value: Any) -> String {
    let raw = String(describing: value)
    let head = raw.split(separator: "(", maxSplits: 1).first.map(String.init) ?? raw
    return head.split(separator: ".").last.map(String.init) ?? head
  }

  // MARK: - States

  static func registrationState(_ state: RegistrationState) -> String {
    switch state {
    case .unavailable: return "unavailable"
    case .available: return "available"
    case .registering: return "registering"
    case .registered: return "registered"
    @unknown default: return "unknown"
    }
  }

  static func deviceSessionState(_ state: DeviceSessionState) -> String {
    switch state {
    case .idle: return "idle"
    case .starting: return "starting"
    case .started: return "started"
    case .paused: return "paused"
    case .stopping: return "stopping"
    case .stopped: return "stopped"
    @unknown default: return "unknown"
    }
  }

  static func streamState(_ state: StreamState) -> String {
    switch state {
    case .stopped: return "stopped"
    case .waitingForDevice: return "waitingForDevice"
    case .starting: return "starting"
    case .streaming: return "streaming"
    case .paused: return "paused"
    case .stopping: return "stopping"
    @unknown default: return "unknown"
    }
  }

  static func cameraState(_ state: CameraState) -> String {
    switch state {
    case .starting: return "starting"
    case .started: return "started"
    case .stopping: return "stopping"
    case .stopped: return "stopped"
    @unknown default: return "unknown"
    }
  }

  static func photoState(_ state: PhotoState) -> String {
    switch state {
    case .stopped: return "stopped"
    case .starting: return "starting"
    case .started: return "started"
    case .stopping: return "stopping"
    @unknown default: return "unknown"
    }
  }

  static func displayState(_ state: DisplayState) -> String {
    switch state {
    case .starting: return "starting"
    case .started: return "started"
    case .stopping: return "stopping"
    case .stopped: return "stopped"
    @unknown default: return "unknown"
    }
  }

  // MARK: - Device

  static func deviceType(_ type: DeviceType?) -> String {
    switch type {
    case .rayBanMeta?: return "rayBanMeta"
    case .oakleyMetaHSTN?: return "oakleyMetaHSTN"
    case .oakleyMetaVanguard?: return "oakleyMetaVanguard"
    case .metaRayBanDisplay?: return "metaRayBanDisplay"
    case .rayBanMetaOptics?: return "rayBanMetaOptics"
    case .metaGlasses?: return "metaGlasses"
    case .unknown?, .none: return "unknown"
    @unknown default: return "unknown"
    }
  }

  /// Coarse device family used by the 0.x `DeviceKind` API and by the
  /// `deviceKinds` stream filter.
  static func deviceKind(_ type: DeviceType?) -> String {
    switch type {
    case .rayBanMeta?, .rayBanMetaOptics?: return "rayBanMeta"
    case .metaRayBanDisplay?: return "rayBanDisplay"
    case .oakleyMetaHSTN?, .oakleyMetaVanguard?: return "oakleyMeta"
    case .metaGlasses?: return "metaGlasses"
    case .unknown?, .none: return "unknown"
    @unknown default: return "unknown"
    }
  }

  static func linkState(_ state: LinkState?) -> String {
    switch state {
    case .disconnected?: return "disconnected"
    case .connecting?: return "connecting"
    case .connected?: return "connected"
    case .none: return "unknown"
    @unknown default: return "unknown"
    }
  }

  static func compatibility(_ value: Compatibility?) -> String {
    switch value {
    case .compatible?: return "compatible"
    case .deviceUpdateRequired?: return "deviceUpdateRequired"
    case .sdkUpdateRequired?: return "sdkUpdateRequired"
    case .undefined?, .none: return "unknown"
    @unknown default: return "unknown"
    }
  }

  static func chargingState(_ state: ChargingState) -> String {
    switch state {
    case .unknown: return "unknown"
    case .charging: return "charging"
    case .notCharging: return "notCharging"
    @unknown default: return "unknown"
    }
  }

  static func donState(_ state: DonState) -> String {
    switch state {
    case .unknown: return "unknown"
    case .doffed: return "doffed"
    case .donned: return "donned"
    @unknown default: return "unknown"
    }
  }

  static func hingeState(_ state: HingeState) -> String {
    switch state {
    case .unknown: return "unknown"
    case .closed: return "closed"
    case .open: return "open"
    @unknown default: return "unknown"
    }
  }

  static func thermalLevel(_ level: ThermalLevel) -> String {
    switch level {
    case .unknown: return "unknown"
    case .none: return "none"
    case .light: return "light"
    case .moderate: return "moderate"
    case .severe: return "severe"
    case .critical: return "critical"
    case .emergency: return "emergency"
    case .shutdown: return "shutdown"
    @unknown default: return "unknown"
    }
  }

  static func parseThermalLevel(_ raw: String?) -> ThermalLevel? {
    switch raw {
    case "unknown": return .unknown
    case "none": return ThermalLevel.none
    case "light": return .light
    case "moderate": return .moderate
    case "severe": return .severe
    case "critical": return .critical
    case "emergency": return .emergency
    case "shutdown": return .shutdown
    default: return nil
    }
  }

  static func parseChargingState(_ raw: String?) -> ChargingState? {
    switch raw {
    case "unknown": return .unknown
    case "charging": return .charging
    case "notCharging": return .notCharging
    default: return nil
    }
  }

  /// Full device snapshot. Shape matches Dart `DeviceInfo.fromMap`.
  static func device(id: DeviceIdentifier, _ device: Device?) -> [String: Any] {
    guard let device else {
      return [
        "uuid": id,
        "name": id,
        "kind": "unknown",
        "deviceType": "unknown",
        "linkState": "unknown",
        "compatibility": "unknown",
        "chargingState": "unknown",
        "donState": "unknown",
        "hingeState": "unknown",
        "thermalLevel": "unknown",
        "supportsDisplay": false,
      ]
    }
    var map: [String: Any] = [
      "uuid": id,
      "name": device.nameOrId(),
      "kind": deviceKind(device.deviceType()),
      "deviceType": deviceType(device.deviceType()),
      "linkState": linkState(device.linkState),
      "compatibility": compatibility(device.compatibility()),
      "chargingState": chargingState(device.chargingState),
      "donState": donState(device.donState),
      "hingeState": hingeState(device.hingeState),
      "thermalLevel": thermalLevel(device.thermalLevel),
      "supportsDisplay": device.supportsDisplay(),
    ]
    if let battery = device.batteryLevel { map["batteryLevel"] = battery }
    return map
  }

  /// Device snapshot built from a `DeviceState` listener payload.
  static func device(id: DeviceIdentifier, _ device: Device?, state: DeviceState) -> [String: Any] {
    var map = self.device(id: id, device)
    map["linkState"] = linkState(state.linkState)
    map["compatibility"] = compatibility(state.compatibility)
    map["chargingState"] = chargingState(state.chargingState)
    map["donState"] = donState(state.donState)
    map["hingeState"] = hingeState(state.hingeState)
    map["thermalLevel"] = thermalLevel(state.thermalLevel)
    if let battery = state.batteryLevel {
      map["batteryLevel"] = battery
    } else {
      map.removeValue(forKey: "batteryLevel")
    }
    return map
  }

  // MARK: - Errors

  static func error(_ e: RegistrationError) -> WireError {
    let name: String
    switch e {
    case .alreadyRegistered: name = "alreadyRegistered"
    case .configurationInvalid: name = "configurationInvalid"
    case .metaAINotInstalled: name = "metaAINotInstalled"
    case .networkUnavailable: name = "networkUnavailable"
    case .unknown: name = "unknown"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.registration, caseName: name,
      message: e.localizedDescription, platformCase: caseLabel(e))
  }

  static func error(_ e: UnregistrationError) -> WireError {
    let name: String
    switch e {
    case .alreadyUnregistered: name = "alreadyUnregistered"
    case .configurationInvalid: name = "configurationInvalid"
    case .metaAINotInstalled: name = "metaAINotInstalled"
    case .unknown: name = "unknown"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.unregistration, caseName: name,
      message: e.localizedDescription, platformCase: caseLabel(e))
  }

  static func error(_ e: WearablesHandleURLError) -> WireError {
    let name: String
    switch e {
    case .registrationError: name = "registrationError"
    case .unregistrationError: name = "unregistrationError"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.handleUrl, caseName: name,
      message: e.localizedDescription, platformCase: caseLabel(e))
  }

  static func error(_ e: RegistrationRequestError) -> WireError {
    let name: String
    switch e {
    case .invalidRequest: name = "invalidRequest"
    case .alreadyHandled: name = "alreadyHandled"
    case .configurationInvalid: name = "configurationInvalid"
    case .networkUnavailable: name = "networkUnavailable"
    case .metaAINotInstalled: name = "metaAINotInstalled"
    case .registrationFailed: name = "registrationFailed"
    case .cancellationFailed: name = "cancellationFailed"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.registrationRequest, caseName: name,
      message: e.description, platformCase: caseLabel(e))
  }

  static func error(_ e: PermissionError) -> WireError {
    let name: String
    switch e {
    case .noDevice: name = "noDevice"
    case .noDeviceWithConnection: name = "noDeviceWithConnection"
    case .connectionError: name = "connectionError"
    case .metaAINotInstalled: name = "metaAINotInstalled"
    case .requestInProgress: name = "requestInProgress"
    case .requestTimeout: name = "requestTimeout"
    case .internalError: name = "internalError"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.permission, caseName: name,
      message: e.localizedDescription, platformCase: caseLabel(e))
  }

  static func error(_ e: NavigationError) -> WireError {
    let name: String
    switch e {
    case .metaAINotInstalled: name = "metaAINotInstalled"
    case .notRegistered: name = "notRegistered"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.navigation, caseName: name,
      message: e.localizedDescription, platformCase: caseLabel(e))
  }

  /// Session errors carry two flags so Dart can follow Meta's handling
  /// table without string matching: `terminal` (a new app build is required)
  /// and `severity` (`warning` for the non-blocking compatibility nudge).
  static func error(_ e: DeviceSessionError) -> WireError {
    let name: String
    var extras: [String: Any] = ["terminal": false, "severity": "error"]
    switch e {
    case .noEligibleDevice: name = "noEligibleDevice"
    case .sessionAlreadyStopped: name = "sessionAlreadyStopped"
    case .sessionAlreadyExists: name = "sessionAlreadyExists"
    case .sessionIdle: name = "sessionIdle"
    case .capabilityAlreadyActive: name = "capabilityAlreadyActive"
    case .capabilityNotFound: name = "capabilityNotFound"
    case .unexpectedError(let description):
      name = "unexpectedError"
      extras["reason"] = description
    case .thermalCritical: name = "thermalCritical"
    case .thermalEmergency: name = "thermalEmergency"
    case .peakPowerShutdown: name = "peakPowerShutdown"
    case .batteryCritical: name = "batteryCritical"
    case .datAppOnTheGlassesUpdateRequired: name = "datAppOnTheGlassesUpdateRequired"
    case .dwaUnavailable: name = "dwaUnavailable"
    case .insufficientSDKVersion:
      name = "insufficientSDKVersion"
      extras["terminal"] = true
    case .dwaOutOfStuRange:
      name = "dwaOutOfStuRange"
      extras["severity"] = "warning"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.deviceSession, caseName: name,
      message: e.description, platformCase: caseLabel(e), extras: extras)
  }

  static func error(_ e: StreamError) -> WireError {
    let name: String
    var extras: [String: Any] = [:]
    switch e {
    case .internalError: name = "internalError"
    case .deviceNotFound(let id):
      name = "deviceNotFound"
      extras["deviceUuid"] = id
    case .deviceNotConnected(let id):
      name = "deviceNotConnected"
      extras["deviceUuid"] = id
    case .timeout: name = "timeout"
    case .videoStreamingError: name = "videoStreamingError"
    case .audioStreamingError: name = "audioStreamingError"
    case .permissionDenied: name = "permissionDenied"
    case .hingesClosed: name = "hingesClosed"
    case .thermalHot: name = "thermalHot"
    case .batteryLow: name = "batteryLow"
    case .peakPowerLimit: name = "peakPowerLimit"
    case .photoCaptureFailed: name = "photoCaptureFailed"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.stream, caseName: name,
      message: e.description, platformCase: caseLabel(e), extras: extras)
  }

  static func error(_ e: PhotoError) -> WireError {
    let name: String
    var extras: [String: Any] = [:]
    switch e {
    case .notReady: name = "notReady"
    case .captureFailure(let underlying):
      name = "captureFailure"
      if let underlying { extras["underlying"] = String(describing: underlying) }
    case .sessionSetupFailed(let underlying):
      name = "sessionSetupFailed"
      if let underlying { extras["underlying"] = String(describing: underlying) }
    case .busy: name = "busy"
    case .serviceUnavailable: name = "serviceUnavailable"
    case .permissionDenied: name = "permissionDenied"
    case .deviceHealthCritical: name = "deviceHealthCritical"
    case .deviceDisconnected: name = "deviceDisconnected"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.photo, caseName: name,
      message: e.description, platformCase: caseLabel(e), extras: extras)
  }

  static func error(_ e: DisplayError) -> WireError {
    let name: String
    var extras: [String: Any] = [:]
    switch e {
    case .deviceDisconnected: name = "deviceDisconnected"
    case .invalidVideoURL: name = "invalidVideoURL"
    case .displayError(let reason):
      name = "displayError"
      extras["reason"] = reason
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.display, caseName: name,
      message: e.description, platformCase: caseLabel(e), extras: extras)
  }

  static func error(_ e: VideoError) -> WireError {
    var extras: [String: Any] = [:]
    if case .playbackFailed(let type) = e {
      extras["videoErrorType"] = videoErrorType(type)
    }
    return WireError(
      category: WireCategory.display, caseName: "videoPlaybackFailed",
      message: e.description, platformCase: caseLabel(e), extras: extras)
  }

  static func videoErrorType(_ type: VideoErrorType) -> String {
    switch type {
    case .unknown: return "unknown"
    case .urlInvalid: return "urlInvalid"
    case .alreadyPlaying: return "alreadyPlaying"
    case .playbackFailed: return "playbackFailed"
    @unknown default: return "unknown"
    }
  }

  static func playbackEvent(_ type: VideoPlaybackEventType) -> String {
    switch type {
    case .unknown: return "unknown"
    case .started: return "started"
    case .ended: return "ended"
    case .stopped: return "stopped"
    case .error: return "error"
    @unknown default: return "unknown"
    }
  }

  static func error(_ e: MockDeviceKitError) -> WireError {
    let name: String
    switch e {
    case .notEnabled: name = "notEnabled"
    case .testServerUnavailable: name = "testServerUnavailable"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.mock, caseName: name,
      message: e.description, platformCase: caseLabel(e))
  }

  static func error(_ e: VoiceInvocationError) -> WireError {
    let name: String
    switch e {
    case .deviceNotFound: name = "deviceNotFound"
    case .invalidWearablesInterface: name = "invalidWearablesInterface"
    case .channelNotConnected: name = "channelNotConnected"
    case .channelError: name = "channelError"
    case .failToSendInitRequest: name = "failToSendInitRequest"
    case .failToSendMessage: name = "failToSendMessage"
    case .initRequestError: name = "initRequestError"
    case .invalidActionMessageProto: name = "invalidActionMessageProto"
    case .unknownMessageType: name = "unknownMessageType"
    case .actionFailed: name = "actionFailed"
    case .invalidSessionState: name = "invalidSessionState"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.voiceInvocation, caseName: name,
      message: e.description, platformCase: caseLabel(e))
  }

  // MARK: - Small parsers

  static func permission(_ raw: String?) -> Permission? {
    switch raw {
    case "camera": return .camera
    case "microphone": return .microphone
    default: return nil
    }
  }

  static func permissionStatus(_ status: PermissionStatus) -> String {
    switch status {
    case .granted: return "granted"
    case .denied: return "denied"
    @unknown default: return "unknown"
    }
  }

  static func parsePermissionStatus(_ raw: String?) -> PermissionStatus? {
    switch raw {
    case "granted": return .granted
    case "denied": return .denied
    default: return nil
    }
  }

  static func glassesModel(_ raw: String?) -> GlassesModel? {
    switch raw {
    case "rayBanMeta": return .rayBanMeta
    case "oakleyMetaHSTN", "oakleyMetaHstn": return .oakleyMetaHSTN
    case "oakleyMetaVanguard": return .oakleyMetaVanguard
    case "rayBanMetaOptics": return .rayBanMetaOptics
    case "metaGlasses": return .metaGlasses
    case "metaRayBanDisplay": return .metaRayBanDisplay
    default: return nil
    }
  }

  static func glassesModelName(_ model: GlassesModel) -> String {
    switch model {
    case .rayBanMeta: return "rayBanMeta"
    case .oakleyMetaHSTN: return "oakleyMetaHSTN"
    case .oakleyMetaVanguard: return "oakleyMetaVanguard"
    case .rayBanMetaOptics: return "rayBanMetaOptics"
    case .metaGlasses: return "metaGlasses"
    case .metaRayBanDisplay: return "metaRayBanDisplay"
    @unknown default: return "unknown"
    }
  }

  /// Converts a mock glasses model to the `DeviceType` wire name.
  static func deviceTypeName(for model: GlassesModel) -> String {
    glassesModelName(model)
  }
}
