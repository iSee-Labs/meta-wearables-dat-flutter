// Registration, permissions and Meta AI navigation.
//
// Two registration flows are supported:
//   * app-initiated: startRegistration() opens Meta AI; Meta AI returns to
//     the app's URL scheme and the URL is forwarded to `handleUrl`.
//   * Meta AI-initiated (DAT 1.0): the callback URL carries a
//     `RegistrationRequest`. It is parked under a request id and surfaced
//     on `registration_requests`; Dart answers it exactly once with
//     continueRegistrationRequest / cancelRegistrationRequest.
// Only URLs carrying the `metaWearablesAction` query item are forwarded
// to the SDK; every other URL is left to the host app.

import Flutter
import Foundation
import MWDATCore

@MainActor
final class RegistrationBridge {
  static let requestLifetimeSeconds: Double = 300

  let stateSink = EventSinkHandler()
  let errorSink = EventSinkHandler()
  let requestSink = EventSinkHandler()

  private var stateTask: Task<Void, Never>?
  private var pending: [String: (request: RegistrationRequest, expiry: Task<Void, Never>)] = [:]

  init() {
    stateSink.onSinkChange = { [weak self] sink, _ in
      if sink != nil { self?.startState() } else { self?.stopState() }
    }
    requestSink.onSinkChange = { [weak self] sink, _ in
      guard let self, let sink else { return }
      for (id, entry) in self.pending { sink(Self.encode(id: id, entry.request)) }
    }
  }

  // MARK: - State

  func registrationState() -> String {
    WireCodec.registrationState(Wearables.shared.registrationState)
  }

  private func startState() {
    stopState()
    stateSink.send(registrationState())
    stateTask = Task { @MainActor [weak self] in
      for await state in Wearables.shared.registrationStateStream() {
        if Task.isCancelled { break }
        self?.stateSink.send(WireCodec.registrationState(state))
      }
    }
  }

  private func stopState() {
    stateTask?.cancel()
    stateTask = nil
  }

  // MARK: - Registration

  func startRegistration() async throws {
    do {
      try await Wearables.shared.startRegistration()
    } catch {
      let wire = WireErrors.from(error, fallbackCategory: WireCategory.registration)
      errorSink.send(wire.eventPayload)
      throw wire
    }
  }

  func startUnregistration() async throws {
    do {
      try await Wearables.shared.startUnregistration()
    } catch {
      throw WireErrors.from(error, fallbackCategory: WireCategory.unregistration)
    }
  }

  static func isDatUrl(_ url: URL) -> Bool {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true
  }

  /// Forwards `url` to the SDK. Returns whether the SDK consumed it.
  func handleUrl(_ url: URL) async throws -> Bool {
    do {
      return try await Wearables.shared.handleUrl(url, onRegistrationRequest: { [weak self] request in
        Task { @MainActor in self?.park(request) }
      })
    } catch {
      let wire = WireErrors.from(error, fallbackCategory: WireCategory.handleUrl)
      errorSink.send(wire.eventPayload)
      throw wire
    }
  }

  /// Fire-and-forget variant used by the app/scene delegate hooks.
  func consume(_ url: URL) -> Bool {
    guard Self.isDatUrl(url) else { return false }
    Task { @MainActor in _ = try? await self.handleUrl(url) }
    return true
  }

  private func park(_ request: RegistrationRequest) {
    let id = UUID().uuidString
    let expiry = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(Self.requestLifetimeSeconds * 1_000_000_000))
      guard !Task.isCancelled else { return }
      self?.pending.removeValue(forKey: id)
    }
    pending[id] = (request, expiry)
    requestSink.send(Self.encode(id: id, request))
  }

  private static func encode(id: String, _ request: RegistrationRequest) -> [String: Any] {
    ["requestId": id, "flowId": request.flowID, "protocolVersion": request.protocolVersion]
  }

  func answer(requestId: String, accept: Bool) async throws {
    guard let entry = pending.removeValue(forKey: requestId) else {
      throw WireError(
        category: WireCategory.registrationRequest, caseName: "alreadyHandled",
        message: "Registration request \(requestId) was already answered or has expired.")
    }
    entry.expiry.cancel()
    do {
      if accept {
        try await entry.request.continueRegistration()
      } else {
        try await entry.request.cancelRegistration()
      }
    } catch {
      throw WireErrors.from(error, fallbackCategory: WireCategory.registrationRequest)
    }
  }

  func dropPendingRequests() {
    for entry in pending.values { entry.expiry.cancel() }
    pending.removeAll()
  }

  // MARK: - Permissions

  func requestPermission(_ raw: String?) async throws -> String {
    guard let permission = WireCodec.permission(raw) else {
      throw WireError.invalidArgument("Unknown permission '\(raw ?? "")'.")
    }
    do {
      return WireCodec.permissionStatus(try await Wearables.shared.requestPermission(permission))
    } catch {
      throw WireErrors.from(error, fallbackCategory: WireCategory.permission)
    }
  }

  func checkPermission(_ raw: String?) async throws -> String {
    guard let permission = WireCodec.permission(raw) else {
      throw WireError.invalidArgument("Unknown permission '\(raw ?? "")'.")
    }
    do {
      return WireCodec.permissionStatus(try await Wearables.shared.checkPermissionStatus(permission))
    } catch {
      throw WireErrors.from(error, fallbackCategory: WireCategory.permission)
    }
  }

  // MARK: - Meta AI navigation

  func openFirmwareUpdate() async throws {
    do {
      try await Wearables.shared.openFirmwareUpdate()
    } catch {
      throw WireErrors.from(error, fallbackCategory: WireCategory.navigation)
    }
  }

  func openDatGlassesAppUpdate() async throws {
    do {
      try await Wearables.shared.openDATGlassesAppUpdate()
    } catch {
      throw WireErrors.from(error, fallbackCategory: WireCategory.navigation)
    }
  }
}
