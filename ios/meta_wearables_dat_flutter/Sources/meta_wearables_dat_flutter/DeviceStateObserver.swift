// Device discovery and live device state.
//
// Keeps one `Device.addDeviceStateListener` per paired device (it fires
// immediately and on every change) and fans the snapshots out to:
//   devices       full list on every membership or state change
//   device_state  one DeviceInfo map per change (Dart filters by uuid)
//   compatibility {deviceUuid, compatibility} when the verdict changes
//   active_device AutoDeviceSelector's pick, or null
// Observation runs only while at least one of these channels has a listener.

import Flutter
import Foundation
import MWDATCore

@MainActor
final class DeviceStateObserver {
  let devicesSink = EventSinkHandler()
  let deviceStateSink = EventSinkHandler()
  let compatibilitySink = EventSinkHandler()
  let activeDeviceSink = EventSinkHandler()

  private var devicesTask: Task<Void, Never>?
  private var activeTask: Task<Void, Never>?
  private var activeSelector: AutoDeviceSelector?
  private var tokens: [DeviceIdentifier: any AnyListenerToken] = [:]
  private var snapshots: [DeviceIdentifier: [String: Any]] = [:]
  private var order: [DeviceIdentifier] = []

  init() {
    for handler in [devicesSink, deviceStateSink, compatibilitySink] {
      handler.onSinkChange = { [weak self] sink, _ in self?.sinksChanged(replayTo: sink, handler: handler) }
    }
    activeDeviceSink.onSinkChange = { [weak self] sink, _ in
      if sink != nil { self?.startActiveDevice() } else { self?.stopActiveDevice() }
    }
  }

  /// Snapshot of every paired device (used by `getDevices`).
  func allDevices() -> [[String: Any]] {
    Wearables.shared.devices.map { id in snapshots[id] ?? WireCodec.device(id: id, Wearables.shared.deviceForIdentifier(id)) }
  }

  func device(_ id: String) -> [String: Any]? {
    guard Wearables.shared.devices.contains(id) else { return nil }
    return snapshots[id] ?? WireCodec.device(id: id, Wearables.shared.deviceForIdentifier(id))
  }

  private var anyListener: Bool {
    devicesSink.hasListener || deviceStateSink.hasListener || compatibilitySink.hasListener
  }

  private func sinksChanged(replayTo sink: FlutterEventSink?, handler: EventSinkHandler) {
    if anyListener {
      if devicesTask == nil { startObserving() }
      guard let sink else { return }
      // Replay current values to the new listener.
      if handler === devicesSink { sink(allDevices()) }
      if handler === deviceStateSink { for id in order { if let s = snapshots[id] { sink(s) } } }
      if handler === compatibilitySink {
        for id in order {
          if let s = snapshots[id] {
            sink(["deviceUuid": id, "compatibility": s["compatibility"] ?? "unknown"])
          }
        }
      }
    } else {
      stopObserving()
    }
  }

  private func startObserving() {
    syncDevices(Wearables.shared.devices)
    devicesTask = Task { @MainActor [weak self] in
      for await ids in Wearables.shared.devicesStream() {
        if Task.isCancelled { break }
        self?.syncDevices(ids)
      }
    }
  }

  private func stopObserving() {
    devicesTask?.cancel()
    devicesTask = nil
    let old = tokens
    tokens.removeAll()
    snapshots.removeAll()
    order.removeAll()
    ResourceLedger.shared.release(.listeners, old.count)
    Task { for token in old.values { await token.cancel() } }
  }

  private func syncDevices(_ ids: [DeviceIdentifier]) {
    let live = Set(ids)
    order = ids
    for id in tokens.keys where !live.contains(id) {
      if let token = tokens.removeValue(forKey: id) {
        ResourceLedger.shared.release(.listeners)
        Task { await token.cancel() }
      }
      snapshots.removeValue(forKey: id)
    }
    for id in ids where tokens[id] == nil {
      guard let device = Wearables.shared.deviceForIdentifier(id) else {
        snapshots[id] = WireCodec.device(id: id, nil)
        continue
      }
      snapshots[id] = WireCodec.device(id: id, device)
      tokens[id] = device.addDeviceStateListener { [weak self] state in
        Task { @MainActor in self?.stateChanged(id: id, state: state) }
      }
      ResourceLedger.shared.acquire(.listeners)
    }
    devicesSink.send(allDevices())
  }

  private func stateChanged(id: DeviceIdentifier, state: DeviceState) {
    guard tokens[id] != nil else { return }
    let previous = snapshots[id]
    let snapshot = WireCodec.device(id: id, Wearables.shared.deviceForIdentifier(id), state: state)
    snapshots[id] = snapshot
    deviceStateSink.send(snapshot)
    devicesSink.send(allDevices())
    let compat = snapshot["compatibility"] as? String
    if previous?["compatibility"] as? String != compat {
      compatibilitySink.send(["deviceUuid": id, "compatibility": compat ?? "unknown"])
    }
  }

  // MARK: - Active device

  private func startActiveDevice() {
    stopActiveDevice()
    let selector = AutoDeviceSelector(wearables: Wearables.shared)
    activeSelector = selector
    activeDeviceSink.send(encodeActive(selector.activeDevice))
    activeTask = Task { @MainActor [weak self] in
      for await id in selector.activeDeviceStream() {
        if Task.isCancelled { break }
        guard let self else { break }
        self.activeDeviceSink.send(self.encodeActive(id))
      }
    }
  }

  private func stopActiveDevice() {
    activeTask?.cancel()
    activeTask = nil
    activeSelector = nil
  }

  private func encodeActive(_ id: DeviceIdentifier?) -> Any {
    guard let id else { return NSNull() }
    return snapshots[id] ?? WireCodec.device(id: id, Wearables.shared.deviceForIdentifier(id))
  }
}
