// Display bridge (DAT 1.0 `MWDATDisplay`).
//
// start: hub.acquire(requireDisplay) -> session.addDisplay() -> subscribe
//        state (before start) -> display.start() -> wait for .started
// send:  JSON -> DisplayNodeBuilder -> display.send(_:) (replaces the
//        whole view and every tap handler)
// stop:  cancel listeners -> display.stop() -> hub.release
//
// Interaction and playback callbacks carry the Dart-assigned callback id
// back over `display_events`.

import Flutter
import Foundation
import MWDATCore
import MWDATDisplay

@MainActor
final class MetaDisplayManager {
  static let owner = "display"
  static let startTimeoutSeconds: Double = 10

  private let hub: DeviceSessionHub
  private var display: Display?
  private let tokens = ListenerTokenBag()
  private var lastState: DisplayState = .stopped
  private var currentVideoCallbackId: String?

  let stateSink = EventSinkHandler()
  let eventsSink = EventSinkHandler()
  let errorSink = EventSinkHandler()

  init(hub: DeviceSessionHub) {
    self.hub = hub
    stateSink.onSinkChange = { [weak self] sink, _ in
      guard let self, let sink else { return }
      sink(WireCodec.displayState(self.lastState))
    }
  }

  var isActive: Bool { display != nil }

  func startDisplaySession(deviceUuid: String?) async throws {
    if display != nil { return }
    let session = try await hub.acquire(
      owner: Self.owner,
      deviceUuid: deviceUuid,
      requireDisplay: true,
      onTerminated: { [weak self] in
        Task { @MainActor in await self?.clear(releaseHub: false) }
      })

    let display: Display
    do {
      display = try session.addDisplay()
    } catch {
      await hub.release(owner: Self.owner)
      throw WireErrors.from(error, fallbackCategory: WireCategory.deviceSession)
    }
    self.display = display
    ResourceLedger.shared.acquire(.displays)

    display.onPlaybackEvent = { [weak self] event in
      Task { @MainActor in self?.handlePlayback(event) }
    }
    display.statePublisher.listen { [weak self] state in
      Task { @MainActor in self?.handleState(state) }
    }.store(in: tokens)
    ResourceLedger.shared.acquire(.listeners)

    display.start()

    let deadline = Date().addingTimeInterval(Self.startTimeoutSeconds)
    while display.state != .started {
      if Date() >= deadline {
        await clear(releaseHub: true)
        throw WireError(
          category: WireCategory.display, caseName: "timeout",
          message: "The display did not start within \(Int(Self.startTimeoutSeconds)) s.")
      }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
  }

  /// Returns build warnings (unsupported values that were substituted).
  func sendView(_ json: [String: Any]) async throws -> [String] {
    guard let display else {
      throw WireError(
        category: WireCategory.display, caseName: "notStarted",
        message: "No display session. Call startDisplaySession first.")
    }
    let sink = eventsSink
    var builder = DisplayNodeBuilder(emit: { id, type in
      Task { @MainActor in sink.send(["callbackId": id, "type": type]) }
    })
    do {
      if (json["type"] as? String) == "videoPlayer" {
        let codec = (json["codec"] as? String) ?? "mp4"
        guard codec == "mp4" else {
          throw WireError(
            category: WireCategory.display, caseName: "unsupportedCodec",
            message: "VideoPlayer only supports mp4 (got \(codec)).")
        }
        currentVideoCallbackId = json["onPlaybackEventId"] as? String
        let player = VideoPlayer(
          provider: .uri(json["uri"] as? String ?? ""),
          codec: .mp4,
          onError: { [weak self] error in
            Task { @MainActor in
              self?.errorSink.send(WireCodec.error(error).eventPayload)
              self?.emitPlayback("error")
            }
          })
        try await display.send(player)
      } else {
        currentVideoCallbackId = nil
        let root = builder.buildRoot(json)
        try await display.send(root)
      }
    } catch {
      let wire = WireErrors.from(error, fallbackCategory: WireCategory.display)
      throw wire
    }
    for warning in builder.warnings {
      eventsSink.send(["type": "warning", "message": warning])
    }
    return builder.warnings
  }

  func clearDisplay() async throws {
    guard let display else { return }
    do {
      try await display.clearDisplay()
    } catch {
      throw WireErrors.from(error, fallbackCategory: WireCategory.display)
    }
  }

  func stopVideo() async {
    await display?.sendVideoStop()
  }

  func stopDisplaySession() async {
    await clear(releaseHub: true)
  }

  private func handleState(_ state: DisplayState) {
    lastState = state
    stateSink.send(WireCodec.displayState(state))
    // Back (two-finger temple tap) or the device ends the display.
    if state == .stopped, display != nil {
      Task { await clear(releaseHub: true) }
    }
  }

  private func handlePlayback(_ event: VideoPlaybackEvent) {
    emitPlayback(WireCodec.playbackEvent(event.type))
    if event.type == .error {
      errorSink.send(WireError(
        category: WireCategory.display, caseName: "videoPlaybackFailed",
        message: "Video playback failed.",
        extras: ["videoErrorType": WireCodec.videoErrorType(event.errorType)]
      ).eventPayload)
    }
  }

  private func emitPlayback(_ name: String) {
    guard let id = currentVideoCallbackId else { return }
    eventsSink.send(["callbackId": id, "type": "playback", "event": name])
  }

  private func clear(releaseHub: Bool) async {
    guard let display else {
      if releaseHub { await hub.release(owner: Self.owner) }
      return
    }
    self.display = nil
    currentVideoCallbackId = nil
    display.onPlaybackEvent = nil
    await tokens.cancelAll()
    ResourceLedger.shared.release(.listeners)
    display.stop()
    ResourceLedger.shared.release(.displays)
    if lastState != .stopped {
      lastState = .stopped
      stateSink.send(WireCodec.displayState(.stopped))
    }
    if releaseHub { await hub.release(owner: Self.owner) }
  }
}
