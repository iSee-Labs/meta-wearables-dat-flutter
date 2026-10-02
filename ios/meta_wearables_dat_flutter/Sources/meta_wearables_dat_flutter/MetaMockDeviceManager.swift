// Mock Device Kit bridge (DAT 1.0 `MWDATMockDevice`).
//
// Simulates glasses so host apps can develop and test without hardware.
// Mock devices appear in `devices` only after `powerOn()` + `unfold()`.
// Camera feed files must be H.265; `setCameraFeed(cameraFacing:)` streams
// the phone camera instead.

import Flutter
import Foundation
import MWDATCore
import MWDATMockDevice
import UIKit

@MainActor
final class MetaMockDeviceManager {
  private let kit: MockDeviceKitInterface = MockDeviceKit.shared
  private var config = MockDeviceKitConfig()
  /// Model per paired mock id (the SDK does not expose it on the device).
  private var models: [String: GlassesModel] = [:]

  let devicesSink = EventSinkHandler()

  init() {
    devicesSink.onSinkChange = { [weak self] sink, _ in
      guard let self, let sink else { return }
      sink(self.pairedDevices())
    }
  }

  // MARK: - Kit lifecycle

  func enable(initiallyRegistered: Bool, initialPermissionsGranted: Bool) async {
    config = MockDeviceKitConfig(
      initiallyRegistered: initiallyRegistered,
      initialPermissionsGranted: initialPermissionsGranted)
    if kit.isEnabled { await kit.disable() }
    kit.enable(config: config)
    models.removeAll()
    syncLedger()
    emitDevices()
  }

  func disable() async {
    if kit.isEnabled { await kit.disable() }
    models.removeAll()
    syncLedger()
    emitDevices()
  }

  var isEnabled: Bool { kit.isEnabled }

  // MARK: - Pairing

  func pair(model: GlassesModel) throws -> [String: Any] {
    if !kit.isEnabled { kit.enable(config: config) }
    let glasses: any MockGlasses
    do {
      glasses = try kit.pairGlasses(model: model)
    } catch {
      throw WireErrors.from(error, fallbackCategory: WireCategory.mock)
    }
    models[glasses.deviceIdentifier] = model
    syncLedger()
    emitDevices()
    return encode(glasses)
  }

  func unpair(uuid: String) async throws {
    let device = try glasses(uuid)
    await kit.unpairDevice(device)
    models.removeValue(forKey: uuid)
    syncLedger()
    emitDevices()
  }

  func pairedDevices() -> [[String: Any]] {
    kit.pairedDevices.map { encode($0) }
  }

  // MARK: - Device state

  func perform(_ action: String, uuid: String) throws {
    let device = try glasses(uuid)
    switch action {
    case "mockPowerOn": device.powerOn()
    case "mockPowerOff": device.powerOff()
    case "mockDon": device.don()
    case "mockDoff": device.doff()
    case "mockFold": device.fold()
    case "mockUnfold": device.unfold()
    case "mockCaptouchTap": device.services.captouch.tap()
    case "mockCaptouchTapAndHold": device.services.captouch.tapAndHold()
    default: throw WireError.invalidArgument("Unknown mock action \(action).")
    }
    emitDevices()
  }

  func setBatteryLevel(uuid: String, level: Int?) throws {
    if let level, !(0...100).contains(level) {
      throw WireError.invalidArgument("Battery level must be between 0 and 100 (got \(level)).")
    }
    try glasses(uuid).setBatteryLevel(level)
  }

  func setChargingState(uuid: String, raw: String?) throws {
    guard let state = WireCodec.parseChargingState(raw) else {
      throw WireError.invalidArgument("Unknown charging state '\(raw ?? "")'.")
    }
    try glasses(uuid).setChargingState(state)
  }

  func setThermalLevel(uuid: String, raw: String?) throws {
    guard let level = WireCodec.parseThermalLevel(raw) else {
      throw WireError.invalidArgument("Unknown thermal level '\(raw ?? "")'.")
    }
    try glasses(uuid).setThermalLevel(level)
  }

  // MARK: - Permissions

  func setPermission(_ permission: String?, status: String?, requestResult: Bool) throws {
    guard let perm = WireCodec.permission(permission) else {
      throw WireError.invalidArgument("Unknown permission '\(permission ?? "")'.")
    }
    guard let st = WireCodec.parsePermissionStatus(status) else {
      throw WireError.invalidArgument("Unknown permission status '\(status ?? "")'.")
    }
    if !kit.isEnabled { kit.enable(config: config) }
    if requestResult {
      kit.permissions.setRequestResult(perm, result: st)
    } else {
      kit.permissions.set(perm, st)
    }
  }

  // MARK: - Camera

  func setCameraFacing(uuid: String, facing: String?) throws {
    try glasses(uuid).services.camera.setCameraFeed(cameraFacing: facing == "front" ? .front : .back)
  }

  func setCameraFeed(uuid: String, path: String?) throws {
    try glasses(uuid).services.camera.setCameraFeed(fileURL: try fileURL(path))
  }

  func setCapturedImage(uuid: String, path: String?) throws {
    try glasses(uuid).services.camera.setCapturedImage(fileURL: try fileURL(path))
  }

  func setCapturedPhoto(uuid: String, path: String?) throws {
    try glasses(uuid).services.cameraCapture.setCapturedPhoto(fileURL: try fileURL(path))
  }

  func simulateCaptureFailure(uuid: String) throws {
    try glasses(uuid).services.cameraCapture.simulateCaptureFailure()
  }

  // MARK: - Inputs (experimental)

  func input(uuid: String, args: [String: Any]) throws {
    let input = try glasses(uuid).services.input
    let source = Self.inputSource(args["source"] as? String)
    switch args["action"] as? String {
    case "navUp": input.navUp(source: source)
    case "navDown": input.navDown(source: source)
    case "navLeft": input.navLeft(source: source)
    case "navRight": input.navRight(source: source)
    case "select": input.select(source: source)
    case "back": input.back(source: source)
    case "capture":
      let press: MWDATMockDevice.CapturePressType
      switch args["pressType"] as? String {
      case "hold": press = .hold
      case "doublePress": press = .doublePress
      default: press = .shortPress
      }
      input.capture(pressType: press)
    case "button": input.button(type: .action)
    case "drag":
      let action: MWDATMockDevice.DragAction
      switch args["dragAction"] as? String {
      case "down": action = .down
      case "up": action = .up
      default: action = .move
      }
      input.drag(
        action: action,
        x: Self.float(args["x"]), y: Self.float(args["y"]),
        dx: Self.float(args["dx"]), dy: Self.float(args["dy"]))
    case let other:
      throw WireError.invalidArgument("Unknown input action '\(other ?? "")'.")
    }
  }

  // MARK: - Speech (experimental)

  func speech(uuid: String, args: [String: Any]) throws {
    let speech = try glasses(uuid).services.speech
    switch args["action"] as? String {
    case "source":
      speech.setTranscriptionSource((args["source"] as? String) == "liveDeviceAsr" ? .liveDeviceAsr : .injected)
    case "transcription":
      speech.simulateTranscription(
        text: args["text"] as? String ?? "",
        isFinal: (args["isFinal"] as? Bool) ?? true,
        confidence: Self.float(args["confidence"], default: 1))
    case "error":
      speech.simulateError(
        errorCode: Int32((args["errorCode"] as? Int) ?? 0),
        message: args["message"] as? String ?? "")
    case "completion":
      speech.simulateCompletion()
    case "locale":
      speech.setLocale(args["locale"] as? String ?? "en-US")
    case let other:
      throw WireError.invalidArgument("Unknown speech action '\(other ?? "")'.")
    }
  }

  // MARK: - Motion (experimental)

  func setMotionFeed(uuid: String, args: [String: Any]) throws {
    let motion = try glasses(uuid).services.motion
    if let path = args["filePath"] as? String {
      motion.setMotionFeed(fileURL: try fileURL(path))
      return
    }
    let samples = (args["samples"] as? [[String: Any]] ?? []).map { map in
      MWDATMockDevice.MotionSample(
        timestampNs: Int64((map["timestampNs"] as? Int) ?? 0),
        accelerometer: Self.vector(map["accelerometer"]),
        gyroscope: Self.vector(map["gyroscope"]),
        magnetometer: Self.vector(map["magnetometer"]),
        orientation: Self.quaternion(map["orientation"]),
        source: (map["source"] as? String) == "neuralBand" ? .neuralBand : .glasses)
    }
    motion.setMotionFeed(samples)
  }

  // MARK: - Voice invocations (experimental)

  func voice(uuid: String, incomplete: Bool) throws -> String? {
    let voice = try glasses(uuid).services.voiceInvocation
    return incomplete ? voice.sendIncompleteAction() : voice.sendLaunchAppAction()
  }

  // MARK: - Display

  func sendDisplayClick(uuid: String, identifier: String) throws -> Bool {
    try glasses(uuid).services.display.sendClick(identifier: identifier)
  }

  func previewView(uuid: String) -> UIView? {
    (kit.pairedDevices.first { $0.deviceIdentifier == uuid } as? any MockGlasses)?
      .services.display.createPreviewView()
  }

  func startTestServer(port: Int) async throws -> Int {
    if !kit.isEnabled { kit.enable(config: config) }
    do {
      return Int(try await kit.startTestServer(port: UInt16(clamping: port)))
    } catch {
      throw WireErrors.from(error, fallbackCategory: WireCategory.mock)
    }
  }

  func stopTestServer() async {
    await kit.stopTestServer()
  }

  // MARK: - Helpers

  private func glasses(_ uuid: String) throws -> any MockGlasses {
    guard let device = kit.pairedDevices.first(where: { $0.deviceIdentifier == uuid }) else {
      throw WireError(
        category: WireCategory.mock, caseName: "deviceNotFound",
        message: "No paired mock device \(uuid).")
    }
    guard let glasses = device as? any MockGlasses else {
      throw WireError(
        category: WireCategory.mock, caseName: "wrongDeviceKind",
        message: "Mock device \(uuid) is not a pair of glasses.")
    }
    return glasses
  }

  private func fileURL(_ path: String?) throws -> URL {
    guard let path, !path.isEmpty else {
      throw WireError.invalidArgument("filePath is required.")
    }
    guard FileManager.default.fileExists(atPath: path) else {
      throw WireError.invalidArgument("File not found: \(path)")
    }
    return URL(fileURLWithPath: path)
  }

  private func encode(_ device: any MockDevice) -> [String: Any] {
    let id = device.deviceIdentifier
    var map = WireCodec.device(id: id, Wearables.shared.deviceForIdentifier(id))
    if let model = models[id] {
      map["model"] = WireCodec.glassesModelName(model)
      if (map["deviceType"] as? String) == "unknown" {
        map["deviceType"] = WireCodec.glassesModelName(model)
      }
    }
    map["isMock"] = true
    return map
  }

  private func emitDevices() {
    devicesSink.send(pairedDevices())
  }

  private func syncLedger() {
    ResourceLedger.shared.set(.mockDevices, kit.isEnabled ? kit.pairedDevices.count : 0)
  }

  private static func inputSource(_ raw: String?) -> MWDATMockDevice.InputSource {
    switch raw {
    case "neuralBand": return .neuralBand
    case "captureButton": return .captureButton
    case "actionButton": return .actionButton
    case "neuralBandDrag": return .neuralBandDrag
    case "unknown": return .unknown
    default: return .captouch
    }
  }

  private static func float(_ value: Any?, default fallback: Float = 0) -> Float {
    switch value {
    case let v as Double: return Float(v)
    case let v as Int: return Float(v)
    case let v as NSNumber: return v.floatValue
    default: return fallback
    }
  }

  private static func vector(_ value: Any?) -> MWDATMockDevice.Vector3? {
    guard let map = value as? [String: Any] else { return nil }
    return MWDATMockDevice.Vector3(x: float(map["x"]), y: float(map["y"]), z: float(map["z"]))
  }

  private static func quaternion(_ value: Any?) -> MWDATMockDevice.Quaternion? {
    guard let map = value as? [String: Any] else { return nil }
    return MWDATMockDevice.Quaternion(
      x: float(map["x"]), y: float(map["y"]), z: float(map["z"]), w: float(map["w"], default: 1))
  }
}
