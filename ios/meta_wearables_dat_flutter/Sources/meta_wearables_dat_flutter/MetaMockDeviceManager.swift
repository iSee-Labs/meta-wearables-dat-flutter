// Slice 10 - iOS Mock Device Kit bridge.
//
// Wraps `MockDeviceKit.shared` (or the SDK-provided shared instance) and
// keeps a `[String: MockDevice]` registry so Dart-side callers can refer
// to mock devices by their UUID string without holding native references.
//
// Mock device APIs ship inside `MWDATMockDevice`; per Meta's iOS sample,
// production builds typically gate Mock Device usage with `#if DEBUG`. We
// intentionally do NOT - this plugin is itself an unofficial development
// aid, and host apps that don't want mocks in release simply won't call
// the Mock APIs. (Strip flag in podspec / SPM target if you need to keep
// mock symbols out of a release binary.)

import Flutter
#if canImport(MWDATCore)
import MWDATCore
#endif
#if canImport(MWDATMockDevice)
import MWDATMockDevice
#endif

@MainActor
final class MetaMockDeviceManager {
  private let kit: MockDeviceKitInterface
  private var devices: [String: MockDevice] = [:]

  /// Sink for `meta_wearables_dat_flutter/mock_devices`. Emits a list of
  /// serialised mock devices on every paired-set change.
  fileprivate var mockDevicesSink: FlutterEventSink?

  init() {
    self.kit = MockDeviceKit.shared
  }

  func setMockDevicesSink(_ sink: FlutterEventSink?) {
    mockDevicesSink = sink
    emitDevices()
  }

  // MARK: - Lifecycle

  func enable() {
    kit.enable()
    emitDevices()
  }

  func disable() {
    kit.disable()
    devices.removeAll()
    emitDevices()
  }

  // MARK: - Pairing

  @discardableResult
  func pairRayBanMeta() -> String {
    let mock = kit.pairRaybanMeta()
    let uuid = mock.deviceIdentifier
    devices[uuid] = mock
    emitDevices()
    return uuid
  }

  func unpair(uuid: String) throws {
    guard let mock = devices.removeValue(forKey: uuid) else {
      throw MockError.notFound(uuid)
    }
    kit.unpairDevice(mock)
    emitDevices()
  }

  // MARK: - Device control

  func powerOn(uuid: String) throws {
    let device = try requireMockRayBan(uuid: uuid)
    device.powerOn()
  }

  func don(uuid: String) throws {
    let device = try requireMockRayBan(uuid: uuid)
    device.don()
  }

  func setCameraFacing(uuid: String, facing: CameraFacing) throws {
    let device = try requireMockRayBan(uuid: uuid)
    device.services.camera.setCameraFeed(facing)
  }

  func setCameraFeed(uuid: String, filePath: String) throws {
    let device = try requireMockRayBan(uuid: uuid)
    let url = URL(fileURLWithPath: filePath)
    device.services.camera.setCameraFeed(url)
  }

  func setCapturedImage(uuid: String, filePath: String) throws {
    let device = try requireMockRayBan(uuid: uuid)
    let url = URL(fileURLWithPath: filePath)
    device.services.camera.setCapturedImage(url)
  }

  // MARK: - Helpers

  private func requireMockRayBan(uuid: String) throws -> MockRaybanMeta {
    guard let device = devices[uuid] else {
      throw MockError.notFound(uuid)
    }
    guard let typed = device as? MockRaybanMeta else {
      throw MockError.wrongDeviceKind(uuid)
    }
    return typed
  }

  private func emitDevices() {
    guard let sink = mockDevicesSink else { return }
    let payload = devices.map { uuid, device -> [String: Any] in
      [
        "uuid": uuid,
        "name": "Mock Ray-Ban Meta",
        "kind": "rayBanMeta",
      ]
    }
    sink(payload)
  }
}

enum MockError: LocalizedError {
  case notFound(String)
  case wrongDeviceKind(String)

  var errorDescription: String? {
    switch self {
    case .notFound(let uuid): return "Mock device not found: \(uuid)"
    case .wrongDeviceKind(let uuid):
      return "Mock device \(uuid) is not a Ray-Ban Meta"
    }
  }
}
