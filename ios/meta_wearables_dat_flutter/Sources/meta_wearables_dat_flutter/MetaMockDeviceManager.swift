// iOS Mock Device Kit bridge.
//
// Wraps `MockDeviceKit.shared` and offers a uuid-keyed surface to Dart.
// Paired device references are sourced from `MockDeviceKit.shared
// .pairedDevices` on demand rather than cached, so the kit remains the
// single source of truth — disable/enable cycles don't leave stale
// entries behind.
//
// Mock device APIs ship inside `MWDATMockDevice`. Per Meta's iOS sample,
// production builds typically gate Mock Device usage with `#if DEBUG`.
// This plugin intentionally does NOT — it is itself an unofficial
// development aid, and host apps that don't want mocks in release
// simply won't call the Mock APIs. (Strip the `MWDATMockDevice` product
// from the SPM target if you need to keep mock symbols out of a release
// binary.)

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

  /// The MockDeviceKitConfig that will be re-applied on every `enable()`.
  /// Mutated by `configure(initiallyRegistered:initialPermissionsGranted:)`.
  private var config: MockDeviceKitConfig = MockDeviceKitConfig()

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

  /// Enables (or re-enables) MockDeviceKit with the current config.
  /// Matches Meta's `MockDeviceKit.shared.enable(config:)`.
  func enable(initiallyRegistered: Bool, initialPermissionsGranted: Bool) {
    config = MockDeviceKitConfig(
      initiallyRegistered: initiallyRegistered,
      initialPermissionsGranted: initialPermissionsGranted,
    )
    if kit.isEnabled {
      kit.disable()
    }
    kit.enable(config: config)
    emitDevices()
  }

  func disable() {
    if kit.isEnabled {
      kit.disable()
    }
    emitDevices()
  }

  func isEnabled() -> Bool {
    kit.isEnabled
  }

  // MARK: - Pairing

  @discardableResult
  func pairRayBanMeta() -> String {
    ensureEnabled()
    let mock = kit.pairRaybanMeta()
    emitDevices()
    return mock.deviceIdentifier
  }

  func unpair(uuid: String) throws {
    let device = try requireDevice(uuid: uuid)
    kit.unpairDevice(device)
    emitDevices()
  }

  /// Returns a serialisable snapshot of every currently paired mock
  /// device. Matches `pairedMockDevices()` in the Dart facade.
  func pairedDevices() -> [[String: Any]] {
    kit.pairedDevices.map(MetaMockDeviceManager.encodeDevice)
  }

  // MARK: - Device control

  func powerOn(uuid: String) throws {
    try requireDevice(uuid: uuid).powerOn()
  }

  func powerOff(uuid: String) throws {
    try requireDevice(uuid: uuid).powerOff()
  }

  func don(uuid: String) throws {
    try requireDevice(uuid: uuid).don()
  }

  func doff(uuid: String) throws {
    try requireDevice(uuid: uuid).doff()
  }

  func fold(uuid: String) throws {
    let device = try requireDevice(uuid: uuid)
    guard let displayless = device as? any MockDisplaylessGlasses else {
      throw MockError.wrongDeviceKind(uuid)
    }
    displayless.fold()
  }

  func unfold(uuid: String) throws {
    let device = try requireDevice(uuid: uuid)
    guard let displayless = device as? any MockDisplaylessGlasses else {
      throw MockError.wrongDeviceKind(uuid)
    }
    displayless.unfold()
  }

  // MARK: - Permissions (kit-level, not per-device)

  func setPermission(permission: String, status: String) throws {
    ensureEnabled()
    let perm = try parsePermission(permission)
    let st = try parsePermissionStatus(status)
    kit.permissions.set(perm, st)
  }

  func setPermissionRequestResult(permission: String, status: String) throws {
    ensureEnabled()
    let perm = try parsePermission(permission)
    let st = try parsePermissionStatus(status)
    kit.permissions.setRequestResult(perm, result: st)
  }

  // MARK: - Camera

  func setCameraFacing(uuid: String, facing: CameraFacing) async throws {
    let camera = try requireCameraKit(uuid: uuid)
    await camera.setCameraFeed(cameraFacing: facing)
  }

  /// Passing a `nil` filePath is a no-op (Dart's nullable signature).
  /// The native MockCameraKit's `setCameraFeed(fileURL:)` does not
  /// accept a clear-to-default, so we simply skip the call. The kit
  /// will continue to use whatever feed was previously installed (or
  /// the platform camera if `setCameraFacing` was called).
  func setCameraFeed(uuid: String, filePath: String?) async throws {
    let camera = try requireCameraKit(uuid: uuid)
    guard let path = filePath, !path.isEmpty else { return }
    let url = URL(fileURLWithPath: path)
    camera.setCameraFeed(fileURL: url)
  }

  func setCapturedImage(uuid: String, filePath: String?) async throws {
    let camera = try requireCameraKit(uuid: uuid)
    guard let path = filePath, !path.isEmpty else { return }
    let url = URL(fileURLWithPath: path)
    camera.setCapturedImage(fileURL: url)
  }

  // MARK: - Helpers

  private func ensureEnabled() {
    if !kit.isEnabled {
      kit.enable(config: config)
    }
  }

  @discardableResult
  private func requireDevice(uuid: String) throws -> any MockDevice {
    if let match = kit.pairedDevices.first(where: { $0.deviceIdentifier == uuid }) {
      return match
    }
    throw MockError.notFound(uuid)
  }

  private func requireCameraKit(uuid: String) throws -> any MockCameraKit {
    let device = try requireDevice(uuid: uuid)
    guard let displayless = device as? any MockDisplaylessGlasses else {
      throw MockError.wrongDeviceKind(uuid)
    }
    return displayless.services.camera
  }

  private func parsePermission(_ raw: String) throws -> MWDATCore.Permission {
    switch raw {
    case "camera": return .camera
    case "microphone": return .microphone
    default: throw MockError.invalidArg("permission", raw)
    }
  }

  private func parsePermissionStatus(_ raw: String) throws -> MWDATCore.PermissionStatus {
    switch raw {
    case "granted": return .granted
    case "denied": return .denied
    default: throw MockError.invalidArg("status", raw)
    }
  }

  private func emitDevices() {
    guard let sink = mockDevicesSink else { return }
    sink(pairedDevices())
  }

  private static func encodeDevice(_ device: any MockDevice) -> [String: Any] {
    return [
      "uuid": device.deviceIdentifier,
      "name": "Mock Ray-Ban Meta",
      "kind": "rayBanMeta",
    ]
  }
}

enum MockError: LocalizedError {
  case notFound(String)
  case wrongDeviceKind(String)
  case invalidArg(String, String)

  var errorDescription: String? {
    switch self {
    case .notFound(let uuid): return "Mock device not found: \(uuid)"
    case .wrongDeviceKind(let uuid):
      return "Mock device \(uuid) is not a displayless-glasses device"
    case .invalidArg(let name, let value):
      return "Invalid \(name): \(value)"
    }
  }
}
