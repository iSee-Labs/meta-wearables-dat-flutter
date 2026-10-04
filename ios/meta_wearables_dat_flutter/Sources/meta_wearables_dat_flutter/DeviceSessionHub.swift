// Owns the single `DeviceSession` the plugin keeps open.
//
// DAT 1.0 allows one session per app and device (`sessionAlreadyExists`),
// and Meta's samples attach every capability (camera, display, inputs,
// motion, speech) to that one session. Bridge components therefore
// `acquire` the shared session under an owner name and `release` it when
// they stop; the session is stopped when the last owner releases it.
//
// Lifecycle (mirrors Meta's CameraAccess / BirdSpotter samples):
//   createSession(SpecificDeviceSelector) -> subscribe state + errors
//   -> start() -> wait for .started -> hand out to owners
// A terminal `.stopped` (hinges closed, device gone, thermal shutdown)
// notifies every owner so it can release its own resources.

import Flutter
import Foundation
import MWDATCore

@MainActor
final class DeviceSessionHub {
  static let startTimeoutSeconds: Double = 45
  static let stopTimeoutSeconds: Double = 3

  private(set) var session: DeviceSession?
  private var owners: [String: () -> Void] = [:]
  private let tokens = ListenerTokenBag()
  private var lastError: DeviceSessionError?
  private var starting = false

  let stateSink = EventSinkHandler()
  let errorSink = EventSinkHandler()

  init() {
    stateSink.onSinkChange = { [weak self] sink, _ in
      guard let self, let sink else { return }
      sink(WireCodec.deviceSessionState(self.session?.state ?? .idle))
    }
  }

  var deviceId: DeviceIdentifier? { session?.deviceId }

  /// The live device snapshot of the session's device.
  func sessionDevice() -> [String: Any]? {
    guard let session else { return nil }
    return WireCodec.device(id: session.deviceId, session.device)
  }

  /// Returns a started session for `owner`, creating and starting one when
  /// none is open. `onTerminated` runs when the session stops on its own.
  func acquire(
    owner: String,
    deviceUuid: String?,
    deviceKinds: Set<String>? = nil,
    requireDisplay: Bool = false,
    onTerminated: @escaping () -> Void
  ) async throws -> DeviceSession {
    if let session, session.state != .stopped {
      if let deviceUuid, deviceUuid != session.deviceId {
        throw WireError(
          category: WireCategory.deviceSession, caseName: "sessionAlreadyExists",
          message: "A session is already open for device \(session.deviceId). Stop it before targeting \(deviceUuid).")
      }
      if requireDisplay, Wearables.shared.deviceForIdentifier(session.deviceId)?.supportsDisplay() == false {
        throw WireError(
          category: WireCategory.deviceSession, caseName: "noEligibleDevice",
          message: "The open session's device does not support Display.")
      }
      try await waitForStarted(session)
      owners[owner] = onTerminated
      return session
    }
    if starting {
      throw WireError(
        category: WireCategory.deviceSession, caseName: "sessionAlreadyExists",
        message: "A device session is already starting.")
    }
    starting = true
    defer { starting = false }

    let id = try DeviceRanking.resolve(
      requested: deviceUuid, kinds: deviceKinds, requireDisplay: requireDisplay)
    let session = try Wearables.shared.createSession(deviceSelector: SpecificDeviceSelector(device: id))
    self.session = session
    self.lastError = nil
    ResourceLedger.shared.acquire(.deviceSessions)
    observe(session)

    do {
      try session.start()
      try await waitForStarted(session)
    } catch {
      await teardown(session, notifyOwners: false)
      throw error
    }
    owners[owner] = onTerminated
    return session
  }

  /// Releases `owner`'s claim; stops the session when no owner remains.
  func release(owner: String) async {
    owners.removeValue(forKey: owner)
    guard owners.isEmpty, let session else { return }
    await teardown(session, notifyOwners: false)
  }

  /// Stops the session regardless of owners (plugin detach, unregistration).
  func stopAll() async {
    guard let session else { return }
    await teardown(session, notifyOwners: true)
  }

  // MARK: - Internals

  private func observe(_ session: DeviceSession) {
    session.statePublisher.listen { [weak self] state in
      Task { @MainActor in self?.handleState(state, for: session) }
    }.store(in: tokens)
    session.errorPublisher.listen { [weak self] error in
      Task { @MainActor in self?.handleError(error) }
    }.store(in: tokens)
    ResourceLedger.shared.acquire(.listeners, 2)
    stateSink.send(WireCodec.deviceSessionState(session.state))
  }

  private func handleState(_ state: DeviceSessionState, for session: DeviceSession) {
    stateSink.send(WireCodec.deviceSessionState(state))
    if state == .stopped, self.session === session, !starting {
      Task { await teardown(session, notifyOwners: true) }
    }
  }

  private func handleError(_ error: DeviceSessionError) {
    lastError = error
    errorSink.send(WireCodec.error(error).eventPayload)
  }

  private func waitForStarted(_ session: DeviceSession) async throws {
    let deadline = Date().addingTimeInterval(Self.startTimeoutSeconds)
    while Date() < deadline {
      switch session.state {
      case .started: return
      case .stopped:
        if let lastError { throw WireCodec.error(lastError) }
        throw WireError(
          category: WireCategory.deviceSession, caseName: "stoppedBeforeStart",
          message: "The device session stopped before it started.")
      default:
        try await Task.sleep(nanoseconds: 100_000_000)
      }
    }
    throw WireError(
      category: WireCategory.deviceSession, caseName: "startTimeout",
      message: "The glasses did not connect within \(Int(Self.startTimeoutSeconds)) s. "
        + "Take them out of the case, put them on and try again.")
  }

  private func teardown(_ session: DeviceSession, notifyOwners: Bool) async {
    guard self.session === session else { return }
    let callbacks = notifyOwners ? Array(owners.values) : []
    owners.removeAll()
    self.session = nil
    for callback in callbacks { callback() }

    if session.state != .stopped {
      session.stop()
      let deadline = Date().addingTimeInterval(Self.stopTimeoutSeconds)
      while session.state != .stopped, Date() < deadline {
        try? await Task.sleep(nanoseconds: 50_000_000)
      }
    }
    await tokens.cancelAll()
    ResourceLedger.shared.release(.listeners, 2)
    ResourceLedger.shared.release(.deviceSessions)
    stateSink.send(WireCodec.deviceSessionState(.stopped))
  }
}

/// Picks the device a session should target.
@MainActor
enum DeviceRanking {
  /// Explicit uuid wins; otherwise the best-ranked paired device:
  /// connected and worn, then connected, then compatible, then any.
  static func resolve(requested: String?, kinds: Set<String>?, requireDisplay: Bool) throws
    -> DeviceIdentifier
  {
    let candidates = Wearables.shared.devices.filter { id in
      let device = Wearables.shared.deviceForIdentifier(id)
      if let kinds, !kinds.isEmpty, !kinds.contains(WireCodec.deviceKind(device?.deviceType())) {
        return false
      }
      if requireDisplay, device?.supportsDisplay() != true { return false }
      return true
    }
    if let requested {
      if candidates.contains(requested) { return requested }
      throw WireError(
        category: WireCategory.deviceSession, caseName: "noEligibleDevice",
        message: "Device \(requested) is not paired or does not match the request.")
    }
    guard let best = candidates.min(by: { rank($0) < rank($1) }) else {
      throw WireError(
        category: WireCategory.deviceSession, caseName: "noEligibleDevice",
        message: requireDisplay
          ? "No display-capable glasses are paired. Pair Meta Ray-Ban Display glasses in the Meta AI app."
          : "No glasses are paired. Pair your glasses in the Meta AI app, then try again.")
    }
    return best
  }

  static func rank(_ id: DeviceIdentifier) -> Int {
    guard let device = Wearables.shared.deviceForIdentifier(id) else { return 4 }
    let connected = device.linkState == .connected
    if connected && device.donState == .donned { return 0 }
    if connected { return 1 }
    if device.compatibility() == .compatible { return 2 }
    return 3
  }
}
