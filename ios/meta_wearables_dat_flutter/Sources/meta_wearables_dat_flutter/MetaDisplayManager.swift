// iOS Display bridge (DAT 0.7.0 `MWDATDisplay`).
//
// Owns:
//   - One `DeviceSession` targeting a (display-capable) device.
//   - One `Display` capability attached to that session.
//   - The display-state EventSink and the display-events EventSink
//     (tap / click / playback callbacks routed back to Dart by id).
//
// Declarative view trees arrive from Dart as plain JSON (`[String: Any]`),
// which we rebuild into Meta's `MWDATDisplay` component DSL
// (`FlexBox` / `Text` / `Image` / `Button` / `Icon` / `VideoPlayer`) and hand
// to `Display.send(_:)`. Interaction callbacks carry the Dart-assigned
// `callbackId` so the Dart side can dispatch to the right closure.
//
// All Meta SDK calls run on the main actor, matching `Wearables.shared`.

import Flutter
import UIKit
#if canImport(MWDATCore)
import MWDATCore
#endif
#if canImport(MWDATDisplay)
import MWDATDisplay
#endif

@MainActor
final class MetaDisplayManager: NSObject {
  /// The DeviceSession we created via `Wearables.shared.createSession`.
  private var deviceSession: DeviceSession?

  /// The display capability attached to `deviceSession`.
  private var display: Display?

  /// Guards against concurrent `startDisplaySession` calls (e.g. fast double-tap).
  private var isStartingSession = false

  private var stateToken: (any AnyListenerToken)?

  /// Last known display state, updated by the statePublisher listener on the
  /// main actor. Used to poll without subscribing a second time.
  private var currentDisplayState: DisplayState = .stopped

  /// The `onPlaybackEventId` of the `VideoPlayer` currently on screen, used to
  /// route `Display.onPlaybackEvent` back to the right Dart closure.
  private var currentVideoCallbackId: String?

  // EventSinks set by the plugin when Dart subscribes.
  fileprivate var displayStateSink: FlutterEventSink?
  fileprivate var displayEventsSink: FlutterEventSink?

  func setDisplayStateSink(_ sink: FlutterEventSink?) { displayStateSink = sink }
  func setDisplayEventsSink(_ sink: FlutterEventSink?) { displayEventsSink = sink }

  // MARK: - Lifecycle

  /// Creates a DeviceSession (targeting `deviceUUID` when given, otherwise the
  /// first paired device), attaches the display capability, and starts it.
  func startDisplaySession(deviceUUID: String?) async throws {
    if display != nil { return }
    if isStartingSession { return }
    isStartingSession = true
    defer { isStartingSession = false }

    // A previous failed attempt may have left a dangling DeviceSession without
    // a Display attached. Stop it so the SDK doesn't throw sessionAlreadyExists.
    if let stale = deviceSession {
      print("[meta_wearables_dat_flutter] startDisplaySession: stopping stale session before retry")
      stale.stop()
      deviceSession = nil
    }

    let allIds = Wearables.shared.devices
    print("[meta_wearables_dat_flutter] startDisplaySession: paired devices=\(allIds.count)")
    for id in allIds {
      let dev = Wearables.shared.deviceForIdentifier(id)
      let supportsDisplay = dev?.deviceType().supportsDisplay ?? false
      print("[meta_wearables_dat_flutter]   device id=\(id) type=\(String(describing: dev?.deviceType())) linkState=\(String(describing: dev?.linkState)) supportsDisplay=\(supportsDisplay)")
    }

    // Prefer display-capable devices (metaRayBanDisplay), then among those
    // prefer connected > connecting > any paired. Falls back to all paired
    // devices when none are display-typed (e.g. dev mode with a single device).
    let displayIds = allIds.filter {
      Wearables.shared.deviceForIdentifier($0)?.deviceType() == .metaRayBanDisplay
    }
    let candidates = displayIds.isEmpty ? allIds : displayIds
    let bestId = candidates.first(where: {
      Wearables.shared.deviceForIdentifier($0)?.linkState == .connected
    }) ?? candidates.first(where: {
      Wearables.shared.deviceForIdentifier($0)?.linkState == .connecting
    }) ?? candidates.first

    let selector: any DeviceSelector
    let chosenId: DeviceIdentifier
    if let uuid = deviceUUID, let match = allIds.first(where: { $0 == uuid }) {
      print("[meta_wearables_dat_flutter] startDisplaySession: using explicit uuid=\(match)")
      selector = SpecificDeviceSelector(device: match)
      chosenId = match
    } else if let pick = bestId {
      print("[meta_wearables_dat_flutter] startDisplaySession: using best device=\(pick)")
      selector = SpecificDeviceSelector(device: pick)
      chosenId = pick
    } else {
      print("[meta_wearables_dat_flutter] startDisplaySession: no paired devices, aborting")
      throw NSError(
        domain: "meta_wearables_dat_flutter",
        code: -20,
        userInfo: [NSLocalizedDescriptionKey:
          "No glasses are currently paired. Open Meta AI to pair " +
          "Ray-Ban Display glasses, then try again."],
      )
    }

    // NOTE: Do NOT wait for `linkState == .connected` here. `session.start()`
    // is what *drives* the BLE/Wi-Fi connection — pre-aborting on linkState
    // would deadlock (the device only reaches `.connected` because start()
    // pushes it there). We pin SpecificDeviceSelector and let start() + the
    // session-state wait do the work, matching the camera path.
    _ = chosenId

    print("[meta_wearables_dat_flutter] startDisplaySession: calling createSession")
    let session: DeviceSession
    do {
      session = try Wearables.shared.createSession(deviceSelector: selector)
    } catch {
      print("[meta_wearables_dat_flutter] startDisplaySession: createSession threw: \(error)")
      throw error
    }
    self.deviceSession = session
    print("[meta_wearables_dat_flutter] startDisplaySession: session created, state=\(session.state)")

    do {
      if session.state != .started {
        print("[meta_wearables_dat_flutter] startDisplaySession: calling session.start()")
        try session.start()
        print("[meta_wearables_dat_flutter] startDisplaySession: waiting for session to reach .started (start() drives the connection)")
        try await Self.waitForDeviceSessionStarted(
          session,
          timeoutNs: 45_000_000_000,
        )
        print("[meta_wearables_dat_flutter] startDisplaySession: session reached .started")
      }

      print("[meta_wearables_dat_flutter] startDisplaySession: calling session.addDisplay()")
      let display = try session.addDisplay()
      self.display = display
      print("[meta_wearables_dat_flutter] startDisplaySession: display capability attached")

      display.onPlaybackEvent = { [weak self] event in
        Task { @MainActor in self?.handlePlaybackEvent(event) }
      }
      stateToken = display.statePublisher.listen { [weak self] state in
        print("[meta_wearables_dat_flutter] displayState -> \(state)")
        Task { @MainActor in
          self?.currentDisplayState = state
          self?.displayStateSink?(Self.encode(state))
        }
      }

      await display.start()
    } catch {
      print("[meta_wearables_dat_flutter] startDisplaySession: failed after createSession, stopping session. error=\(error)")
      session.stop()
      deviceSession = nil
      throw error
    }
  }

  /// Rebuilds [json] into the `MWDATDisplay` DSL and sends it to the glasses.
  func sendDisplayView(_ json: [String: Any]) async throws {
    guard let display = display else {
      print("[meta_wearables_dat_flutter] sendDisplayView: no display session")
      throw NSError(
        domain: "meta_wearables_dat_flutter",
        code: -21,
        userInfo: [NSLocalizedDescriptionKey:
          "No display session - call startDisplaySession first"],
      )
    }
    print("[meta_wearables_dat_flutter] sendDisplayView: type=\(json["type"] as? String ?? "flexBox")")

    if (json["type"] as? String) == "videoPlayer" {
      let url = json["uri"] as? String ?? ""
      currentVideoCallbackId = json["onPlaybackEventId"] as? String
      let video = MWDATDisplay.VideoPlayer(
        provider: .uri(url),
        codec: .mp4,
        onError: { [weak self] _ in
          Task { @MainActor in self?.emitPlayback(eventName: "error") }
        },
      )
      try await display.send(video)
    } else {
      currentVideoCallbackId = nil
      let view = buildFlexBox(json)
      do {
        try await display.send(view)
        print("[meta_wearables_dat_flutter] sendDisplayView: send succeeded")
      } catch {
        print("[meta_wearables_dat_flutter] sendDisplayView: send threw: \(error)")
        let raw = String(describing: error)
        if raw.contains("deviceDisconnected") || raw.contains("deviceNotConnected") {
          // SDK docs: "If the glasses disconnect, you can restart by calling start() again."
          // Try one restart before giving up.
          print("[meta_wearables_dat_flutter] sendDisplayView: attempting display restart")
          do {
            await display.stop()
            try await Self.waitForDisplayState(
              self, target: .stopped, timeoutNs: 5_000_000_000)
            await display.start()
            try await Self.waitForDisplayState(
              self, target: .started, timeoutNs: 10_000_000_000)
            try await display.send(view)
            print("[meta_wearables_dat_flutter] sendDisplayView: send succeeded after restart")
            return
          } catch let restartError {
            print("[meta_wearables_dat_flutter] sendDisplayView: restart failed: \(restartError) — tearing down")
            await stopDisplaySession()
            throw restartError
          }
        }
        throw error
      }
    }
  }

  /// Detaches the display capability and tears down its device session.
  func stopDisplaySession() async {
    stateToken = nil
    currentDisplayState = .stopped
    currentVideoCallbackId = nil
    if let display = display {
      await display.stop()
    }
    display = nil
    deviceSession?.stop()
    deviceSession = nil
  }

  // MARK: - Callback plumbing

  private func emitCallback(_ id: String, type: String) {
    displayEventsSink?(["callbackId": id, "type": type] as [String: Any])
  }

  private func handlePlaybackEvent(_ event: VideoPlaybackEvent) {
    emitPlayback(eventName: Self.playbackWireName(event))
  }

  private func emitPlayback(eventName: String) {
    guard let id = currentVideoCallbackId else { return }
    displayEventsSink?(
      ["callbackId": id, "type": "playback", "event": eventName] as [String: Any]
    )
  }

  // MARK: - Tree builders

  private func buildChildren(_ json: [String: Any]) -> [any ViewComponent] {
    let kids = json["children"] as? [[String: Any]] ?? []
    return kids.compactMap { buildComponent($0) }
  }

  private func buildComponent(_ json: [String: Any]) -> (any ViewComponent)? {
    switch json["type"] as? String {
    case "flexBox": return buildFlexBox(json)
    case "text": return buildText(json)
    case "image": return buildImage(json)
    case "button": return buildButton(json)
    case "icon": return buildIcon(json)
    // `videoPlayer` is a root-only DisplayableView, not a nestable component.
    default: return nil
    }
  }

  private func buildFlexBox(_ json: [String: Any]) -> MWDATDisplay.FlexBox {
    let padding: MWDATDisplay.EdgeInsets? = (json["padding"] as? Int)
      .map { MWDATDisplay.EdgeInsets(all: CGFloat($0)) }

    // `FlexBox`'s content is a `@ComponentBuilder` result builder, so we
    // yield the precomputed children through it rather than returning an
    // array directly (the builder has no array `buildExpression`).
    let children = buildChildren(json)
    var box = MWDATDisplay.FlexBox(
      direction: Self.direction(json["direction"] as? String),
      spacing: CGFloat((json["spacing"] as? Int) ?? 0),
      alignment: Self.alignment(json["alignment"] as? String),
      crossAlignment: Self.alignment(json["crossAlignment"] as? String),
      wrap: (json["wrap"] as? Bool) ?? false,
      padding: padding,
    ) {
      for child in children { child }
    }

    if let bg = json["background"] as? String {
      box = box.background(Self.background(bg))
    }
    if let grow = json["flexGrow"] as? Double {
      box = box.flexGrow(Float(grow))
    }
    if let tapId = json["onTapId"] as? String {
      box = box.onTap { [weak self] in
        Task { @MainActor in self?.emitCallback(tapId, type: "tap") }
      }
    }
    return box
  }

  private func buildText(_ json: [String: Any]) -> MWDATDisplay.Text {
    MWDATDisplay.Text(
      json["text"] as? String ?? "",
      style: Self.textStyle(json["style"] as? String),
      color: Self.textColor(json["color"] as? String),
    )
  }

  private func buildImage(_ json: [String: Any]) -> MWDATDisplay.Image {
    MWDATDisplay.Image(
      uri: json["uri"] as? String ?? "",
      sizePreset: Self.imageSize(json["sizePreset"] as? String),
      cornerRadius: Self.cornerRadius(json["cornerRadius"] as? String),
    )
  }

  private func buildButton(_ json: [String: Any]) -> MWDATDisplay.Button {
    let iconName = (json["iconName"] as? String)
      .flatMap { MWDATDisplay.IconName(rawValue: $0) }
    let onClick: (@Sendable () -> Void)? = (json["onClickId"] as? String)
      .map { id in
        { [weak self] in
          Task { @MainActor in self?.emitCallback(id, type: "click") }
        }
      }
    return MWDATDisplay.Button(
      label: json["label"] as? String ?? "",
      style: Self.buttonStyle(json["style"] as? String),
      iconName: iconName,
      onClick: onClick,
    )
  }

  private func buildIcon(_ json: [String: Any]) -> MWDATDisplay.Icon {
    let name = (json["iconName"] as? String)
      .flatMap { MWDATDisplay.IconName(rawValue: $0) } ?? .checkmark
    return MWDATDisplay.Icon(name: name, style: .filled)
  }

  // MARK: - Enum mapping

  private static func direction(_ value: String?) -> MWDATDisplay.Direction {
    switch value {
    case "row": return .row
    case "column": return .column
    default: return .column
    }
  }

  private static func alignment(_ value: String?) -> MWDATDisplay.Alignment {
    switch value {
    case "center": return .center
    case "end": return .end
    case "start": return .start
    default: return .start
    }
  }

  private static func textStyle(_ value: String?) -> MWDATDisplay.TextStyle {
    switch value {
    case "heading": return .heading
    case "meta": return .meta
    default: return .body
    }
  }

  private static func textColor(_ value: String?) -> MWDATDisplay.TextColor {
    value == "secondary" ? .secondary : .primary
  }

  private static func imageSize(_ value: String?) -> MWDATDisplay.ImageSize {
    value == "icon" ? .icon : .fill
  }

  private static func cornerRadius(
    _ value: String?,
  ) -> MWDATDisplay.CornerRadius {
    switch value {
    case "small": return .small
    // The display SDK only ships none/small/medium; large collapses to medium.
    case "medium", "large": return .medium
    default: return .none
    }
  }

  private static func buttonStyle(
    _ value: String?,
  ) -> MWDATDisplay.ButtonStyle {
    value == "secondary" ? .secondary : .primary
  }

  private static func background(
    _ value: String?,
  ) -> MWDATDisplay.Background {
    value == "card" ? .card : .none
  }

  private static func encode(_ state: DisplayState) -> Int {
    switch state {
    case .starting: return 0
    case .started: return 1
    case .stopping: return 2
    case .stopped: return 3
    @unknown default: return 3
    }
  }

  /// Maps an iOS `VideoPlaybackEvent` to the wire token the Dart
  /// `DisplayPlaybackEventType` keys on. Derived from `String(describing:)` so
  /// it tolerates SDK additions to the playback-event enum.
  private static func playbackWireName(_ event: VideoPlaybackEvent) -> String {
    let raw = String(describing: event.type)
    if raw.hasPrefix("started") || raw.hasPrefix("playing") { return "playing" }
    if raw.hasPrefix("paused") { return "paused" }
    if raw.hasPrefix("ended") { return "ended" }
    if raw.hasPrefix("stopped") { return "stopped" }
    if raw.hasPrefix("error") { return "error" }
    return "unknown"
  }

  // MARK: - Display state wait

  /// Polls `currentDisplayState` until it matches `target`, throwing on timeout
  /// or an early `.stopped` when waiting for `.started`.
  private static func waitForDisplayState(
    _ manager: MetaDisplayManager,
    target: DisplayState,
    timeoutNs: UInt64,
  ) async throws {
    let pollIntervalNs: UInt64 = 100_000_000
    let maxIterations = max(1, Int(timeoutNs / pollIntervalNs))
    for _ in 0..<maxIterations {
      if manager.currentDisplayState == target { return }
      if target == .started && manager.currentDisplayState == .stopped {
        throw NSError(
          domain: "meta_wearables_dat_flutter",
          code: -24,
          userInfo: [NSLocalizedDescriptionKey:
            "Display stopped while waiting to reach .started"],
        )
      }
      try? await Task.sleep(nanoseconds: pollIntervalNs)
    }
    throw NSError(
      domain: "meta_wearables_dat_flutter",
      code: -25,
      userInfo: [NSLocalizedDescriptionKey:
        "Timeout waiting for display state \(target)"],
    )
  }

  // MARK: - DeviceSession wait

  /// Polls `session.state` until it reaches `.started`, throwing on timeout or
  /// an early `.stopped`. Mirrors `MetaSessionManager`'s helper.
  private static func waitForDeviceSessionStarted(
    _ session: DeviceSession,
    timeoutNs: UInt64,
  ) async throws {
    let pollIntervalNs: UInt64 = 250_000_000
    let maxIterations = max(1, Int(timeoutNs / pollIntervalNs))
    for _ in 0..<maxIterations {
      if session.state == .started { return }
      if session.state == .stopped {
        throw NSError(
          domain: "meta_wearables_dat_flutter",
          code: -22,
          userInfo: [NSLocalizedDescriptionKey:
            "DeviceSession stopped before reaching .started"],
        )
      }
      try? await Task.sleep(nanoseconds: pollIntervalNs)
    }
    session.stop()
    throw NSError(
      domain: "meta_wearables_dat_flutter",
      code: -23,
      userInfo: [NSLocalizedDescriptionKey:
        "Glasses did not connect in time. Take them out of the case " +
        "and put them on, then try again."],
    )
  }
}
