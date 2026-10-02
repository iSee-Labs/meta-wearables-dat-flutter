// Experimental DAT 1.0 capabilities: Inputs, Motion, Speech and Voice
// invocations.
//
// Meta marks these experimental: apps can build and test with them in
// Developer Mode and Beta release channels, but cannot publish to
// production release channels. Inputs, Motion and Speech attach to the
// shared DeviceSession; voice invocations run on their own stream.

import Flutter
import Foundation
import MWDATCore
#if canImport(MWDATInputs)
import MWDATInputs
#endif
#if canImport(MWDATMotion)
import MWDATMotion
#endif
#if canImport(MWDATSpeech)
import MWDATSpeech
#endif

enum ExperimentalModules {
  static var linked: [String: Bool] {
    var map: [String: Bool] = ["voiceInvocations": true, "cameraPhoto": true, "cameraAudio": true]
    #if canImport(MWDATInputs)
    map["inputs"] = true
    #else
    map["inputs"] = false
    #endif
    #if canImport(MWDATMotion)
    map["motion"] = true
    #else
    map["motion"] = false
    #endif
    #if canImport(MWDATSpeech)
    map["speech"] = true
    #else
    map["speech"] = false
    #endif
    return map
  }

  static func notLinked(_ module: String) -> WireError {
    WireError(
      category: WireCategory.experimentalNotLinked, caseName: "notLinked",
      message: "The \(module) module is not linked into this build.")
  }
}

// MARK: - Inputs

@MainActor
final class InputsBridge {
  static let owner = "inputs"
  private let hub: DeviceSessionHub
  let eventsSink = EventSinkHandler()
  let stateSink = EventSinkHandler()
  let errorSink = EventSinkHandler()
  private var active = false
  private var eventsTask: Task<Void, Never>?
  private let tokens = ListenerTokenBag()

  init(hub: DeviceSessionHub) { self.hub = hub }

  func start(args: [String: Any]) async throws {
    #if canImport(MWDATInputs)
    if active { return }
    let session = try await hub.acquire(
      owner: Self.owner, deviceUuid: args["deviceUuid"] as? String,
      onTerminated: { [weak self] in Task { @MainActor in await self?.clear(release: false) } })
    var sources = Set<InputSource>()
    for raw in args["sources"] as? [String] ?? [] {
      if let source = Self.source(raw) { sources.insert(source) }
    }
    let config = sources.isEmpty
      ? InputsConfiguration(consumeBack: (args["consumeBack"] as? Bool) ?? true)
      : InputsConfiguration(sources: sources, consumeBack: (args["consumeBack"] as? Bool) ?? true)
    let inputs: Inputs
    do {
      guard let added = try session.addInputs(configuration: config) else {
        throw WireError(
          category: WireCategory.inputs, caseName: "capabilityUnavailable",
          message: "Inputs are not available on this device.")
      }
      inputs = added
    } catch {
      await hub.release(owner: Self.owner)
      throw WireErrors.from(error, fallbackCategory: WireCategory.inputs)
    }
    active = true
    ResourceLedger.shared.acquire(.capabilities)
    inputs.statePublisher.listen { [weak self] state in
      Task { @MainActor in self?.stateSink.send(Self.state(state)) }
    }.store(in: tokens)
    inputs.errorPublisher.listen { [weak self] error in
      Task { @MainActor in self?.errorSink.send(Self.error(error).eventPayload) }
    }.store(in: tokens)
    stateSink.send(Self.state(inputs.state))
    let events = inputs.events
    eventsTask = Task { @MainActor [weak self] in
      for await event in events {
        if Task.isCancelled { break }
        self?.eventsSink.send(Self.encode(event))
      }
    }
    #else
    throw ExperimentalModules.notLinked("MWDATInputs")
    #endif
  }

  func stop() async {
    await clear(release: true)
  }

  private func clear(release: Bool) async {
    guard active else { return }
    active = false
    eventsTask?.cancel()
    eventsTask = nil
    await tokens.cancelAll()
    #if canImport(MWDATInputs)
    try? hub.session?.removeInputs()
    #endif
    ResourceLedger.shared.release(.capabilities)
    stateSink.send("inactive")
    if release { await hub.release(owner: Self.owner) }
  }

  #if canImport(MWDATInputs)
  static func source(_ raw: String) -> InputSource? {
    switch raw {
    case "captouch": return .captouch
    case "neuralBand": return .neuralBand
    case "captureButton": return .captureButton
    case "actionButton": return .actionButton
    case "neuralBandDrag": return .neuralBandDrag
    default: return nil
    }
  }

  static func sourceName(_ source: InputSource) -> String {
    switch source {
    case .captouch: return "captouch"
    case .neuralBand: return "neuralBand"
    case .captureButton: return "captureButton"
    case .actionButton: return "actionButton"
    case .neuralBandDrag: return "neuralBandDrag"
    case .unknown: return "unknown"
    @unknown default: return "unknown"
    }
  }

  static func state(_ state: InputsState) -> String {
    switch state {
    case .inactive: return "inactive"
    case .activating: return "activating"
    case .active: return "active"
    case .deactivating: return "deactivating"
    @unknown default: return "unknown"
    }
  }

  static func error(_ error: InputsError) -> WireError {
    let name: String
    switch error {
    case .permissionDenied: name = "permissionDenied"
    case .connectionClosed: name = "connectionClosed"
    case .activationTimeout: name = "activationTimeout"
    case .activationFailed: name = "activationFailed"
    case .capabilityUnavailable: name = "capabilityUnavailable"
    case .deviceDisconnected: name = "deviceDisconnected"
    case .communicationError: name = "communicationError"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.inputs, caseName: name, message: error.description,
      platformCase: WireCodec.caseLabel(error))
  }

  static func encode(_ event: InputEvent) -> [String: Any] {
    var map: [String: Any] = [
      "source": sourceName(event.source),
      "timestampMs": Int(event.timestampMs),
    ]
    switch event {
    case .nav(let direction, _, _):
      map["type"] = "nav"
      switch direction {
      case .up: map["direction"] = "up"
      case .down: map["direction"] = "down"
      case .left: map["direction"] = "left"
      case .right: map["direction"] = "right"
      @unknown default: map["direction"] = "unknown"
      }
    case .select: map["type"] = "select"
    case .back: map["type"] = "back"
    case .button:
      map["type"] = "button"
      map["buttonType"] = "action"
    case .capture(let press, _, _):
      map["type"] = "capture"
      switch press {
      case .shortPress: map["pressType"] = "shortPress"
      case .hold: map["pressType"] = "hold"
      case .doublePress: map["pressType"] = "doublePress"
      @unknown default: map["pressType"] = "unknown"
      }
    case .drag(let action, let x, let y, let dx, let dy, _, _):
      map["type"] = "drag"
      switch action {
      case .down: map["dragAction"] = "down"
      case .move: map["dragAction"] = "move"
      case .up: map["dragAction"] = "up"
      @unknown default: map["dragAction"] = "unknown"
      }
      map["x"] = Double(x)
      map["y"] = Double(y)
      map["dx"] = Double(dx)
      map["dy"] = Double(dy)
    @unknown default:
      map["type"] = "unknown"
    }
    return map
  }
  #endif
}

// MARK: - Motion

@MainActor
final class MotionBridge {
  static let owner = "motion"
  private let hub: DeviceSessionHub
  let samplesSink = EventSinkHandler()
  let stateSink = EventSinkHandler()
  let errorSink = EventSinkHandler()
  private var active = false
  private var samplesTask: Task<Void, Never>?
  private let tokens = ListenerTokenBag()
  #if canImport(MWDATMotion)
  private var motion: Motion?
  #endif

  init(hub: DeviceSessionHub) { self.hub = hub }

  func start(args: [String: Any]) async throws {
    #if canImport(MWDATMotion)
    if active { return }
    let session = try await hub.acquire(
      owner: Self.owner, deviceUuid: args["deviceUuid"] as? String,
      onTerminated: { [weak self] in Task { @MainActor in await self?.clear(release: false) } })
    let rate: MotionSamplingRate
    switch args["samplingRate"] as? Int {
    case 5: rate = .hz5
    case 15: rate = .hz15
    case 24: rate = .hz24
    case 30: rate = .hz30
    case 60: rate = .hz60
    default: rate = .hz10
    }
    let motion: Motion
    do {
      guard let added = try session.addMotion(configuration: MotionConfiguration(samplingRate: rate)) else {
        throw WireError(
          category: WireCategory.motion, caseName: "sensorUnavailable",
          message: "Motion is not available on this device.")
      }
      motion = added
    } catch {
      await hub.release(owner: Self.owner)
      throw WireErrors.from(error, fallbackCategory: WireCategory.motion)
    }
    self.motion = motion
    active = true
    ResourceLedger.shared.acquire(.capabilities)
    motion.statePublisher.listen { [weak self] state in
      Task { @MainActor in self?.stateSink.send(Self.state(state)) }
    }.store(in: tokens)
    motion.errorPublisher.listen { [weak self] error in
      Task { @MainActor in self?.errorSink.send(Self.error(error).eventPayload) }
    }.store(in: tokens)
    let samples = motion.samples
    samplesTask = Task { @MainActor [weak self] in
      for await sample in samples {
        if Task.isCancelled { break }
        guard let self, self.samplesSink.hasListener else { continue }
        self.samplesSink.send(Self.encode(sample))
      }
    }
    motion.start()
    #else
    throw ExperimentalModules.notLinked("MWDATMotion")
    #endif
  }

  func stop() async {
    await clear(release: true)
  }

  private func clear(release: Bool) async {
    guard active else { return }
    active = false
    samplesTask?.cancel()
    samplesTask = nil
    await tokens.cancelAll()
    #if canImport(MWDATMotion)
    motion?.stop()
    motion = nil
    try? hub.session?.removeMotion()
    #endif
    ResourceLedger.shared.release(.capabilities)
    stateSink.send("stopped")
    if release { await hub.release(owner: Self.owner) }
  }

  #if canImport(MWDATMotion)
  static func state(_ state: MotionState) -> String {
    switch state {
    case .stopped: return "stopped"
    case .starting: return "starting"
    case .started: return "started"
    case .stopping: return "stopping"
    @unknown default: return "unknown"
    }
  }

  static func error(_ error: MotionError) -> WireError {
    let name: String
    switch error {
    case .sensorUnavailable: name = "sensorUnavailable"
    case .capabilityClosed: name = "capabilityClosed"
    case .deviceDisconnected: name = "deviceDisconnected"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.motion, caseName: name, message: error.description,
      platformCase: WireCodec.caseLabel(error))
  }

  static func encode(_ sample: MotionSample) -> [String: Any] {
    var map: [String: Any] = ["timestampNs": Int(sample.timestampNs)]
    func vec(_ v: Vector3) -> [String: Double] { ["x": Double(v.x), "y": Double(v.y), "z": Double(v.z)] }
    if let a = sample.accelerometer { map["accelerometer"] = vec(a) }
    if let g = sample.gyroscope { map["gyroscope"] = vec(g) }
    if let m = sample.magnetometer { map["magnetometer"] = vec(m) }
    if let q = sample.orientation {
      map["orientation"] = ["x": Double(q.x), "y": Double(q.y), "z": Double(q.z), "w": Double(q.w)]
    }
    switch sample.source {
    case .glasses: map["source"] = "glasses"
    case .neuralBand: map["source"] = "neuralBand"
    case .unknown: map["source"] = "unknown"
    @unknown default: map["source"] = "unknown"
    }
    return map
  }
  #endif
}

// MARK: - Speech

@MainActor
final class SpeechBridge {
  static let owner = "speech"
  private let hub: DeviceSessionHub
  let transcriptionsSink = EventSinkHandler()
  let stateSink = EventSinkHandler()
  let errorSink = EventSinkHandler()
  private var active = false
  private let tokens = ListenerTokenBag()
  #if canImport(MWDATSpeech)
  private var speech: Speech?
  #endif

  init(hub: DeviceSessionHub) { self.hub = hub }

  func start(args: [String: Any]) async throws {
    #if canImport(MWDATSpeech)
    if active { return }
    let session = try await hub.acquire(
      owner: Self.owner, deviceUuid: args["deviceUuid"] as? String,
      onTerminated: { [weak self] in Task { @MainActor in await self?.clear(release: false) } })
    let speech: Speech
    do {
      guard let added = try session.addSpeech() else {
        throw WireError(
          category: WireCategory.speech, caseName: "unavailable",
          message: "Speech is not available on this device.")
      }
      speech = added
    } catch {
      await hub.release(owner: Self.owner)
      throw WireErrors.from(error, fallbackCategory: WireCategory.speech)
    }
    self.speech = speech
    active = true
    ResourceLedger.shared.acquire(.capabilities)
    speech.statePublisher.listen { [weak self] state in
      Task { @MainActor in self?.stateSink.send(Self.state(state)) }
    }.store(in: tokens)
    speech.errorPublisher.listen { [weak self] error in
      Task { @MainActor in self?.errorSink.send(Self.error(error).eventPayload) }
    }.store(in: tokens)
    speech.transcriptionPublisher.listen { [weak self] result in
      let payload: [String: Any] = [
        "text": result.text, "isFinal": result.isFinal, "confidence": Double(result.confidence),
      ]
      Task { @MainActor in self?.transcriptionsSink.send(payload) }
    }.store(in: tokens)
    speech.start()
    #else
    throw ExperimentalModules.notLinked("MWDATSpeech")
    #endif
  }

  func stop() async {
    await clear(release: true)
  }

  private func clear(release: Bool) async {
    guard active else { return }
    active = false
    await tokens.cancelAll()
    #if canImport(MWDATSpeech)
    speech?.stop()
    speech = nil
    try? hub.session?.removeSpeech()
    #endif
    ResourceLedger.shared.release(.capabilities)
    stateSink.send("stopped")
    if release { await hub.release(owner: Self.owner) }
  }

  #if canImport(MWDATSpeech)
  static func state(_ state: SpeechState) -> String {
    switch state {
    case .starting: return "starting"
    case .started: return "started"
    case .stopping: return "stopping"
    case .stopped: return "stopped"
    @unknown default: return "unknown"
    }
  }

  static func error(_ error: SpeechError) -> WireError {
    let name: String
    switch error {
    case .deviceDisconnected: name = "deviceDisconnected"
    case .invalidState: name = "invalidState"
    case .unavailable: name = "unavailable"
    case .alreadyListening: name = "alreadyListening"
    case .startFailed: name = "startFailed"
    case .unexpectedError: name = "unexpectedError"
    @unknown default: name = "unknown"
    }
    return WireError(
      category: WireCategory.speech, caseName: name, message: error.description,
      platformCase: WireCodec.caseLabel(error))
  }
  #endif
}

// MARK: - Voice invocations

@MainActor
final class VoiceInvocationsBridge {
  let invocationsSink = EventSinkHandler()
  let stateSink = EventSinkHandler()
  let errorSink = EventSinkHandler()
  private var stream: VoiceInvocationsStream?
  private let tokens = ListenerTokenBag()
  private var pending: [String: any ResponseHandle] = [:]

  func start(deviceUuid: String?) async throws {
    if stream != nil { return }
    let id = try DeviceRanking.resolve(requested: deviceUuid, kinds: nil, requireDisplay: false)
    do {
      let stream = try VoiceInvocationsStream(wearables: Wearables.shared)
      stream.invocationsPublisher.listen { [weak self] invocation in
        Task { @MainActor in self?.received(invocation) }
      }.store(in: tokens)
      stream.errorPublisher.listen { [weak self] error in
        Task { @MainActor in self?.errorSink.send(WireCodec.error(error).eventPayload) }
      }.store(in: tokens)
      stateSink.send("starting")
      try stream.start(deviceIdentifier: id)
      self.stream = stream
      ResourceLedger.shared.acquire(.capabilities)
      stateSink.send("started")
    } catch {
      await tokens.cancelAll()
      stateSink.send("stopped")
      throw WireErrors.from(error, fallbackCategory: WireCategory.voiceInvocation)
    }
  }

  func stop() async {
    guard let stream else { return }
    self.stream = nil
    stream.stop()
    await tokens.cancelAll()
    // Unanswered invocations are failed so the glasses are not left waiting.
    let handles = pending.values
    pending.removeAll()
    for handle in handles { _ = await handle.sendFailure(actionOutput: nil) }
    ResourceLedger.shared.release(.capabilities)
    stateSink.send("stopped")
  }

  private func received(_ invocation: any VoiceInvocation) {
    guard let launch = invocation as? LaunchApp else { return }
    let id = UUID().uuidString
    pending[id] = launch.responseHandle
    invocationsSink.send([
      "invocationId": id, "type": "launchApp", "deviceUuid": launch.deviceIdentifier,
    ])
  }

  func respond(invocationId: String, success: Bool, actionOutput: String?) async throws -> Bool {
    guard let handle = pending.removeValue(forKey: invocationId) else {
      throw WireError(
        category: WireCategory.voiceInvocation, caseName: "alreadyResponded",
        message: "Voice invocation \(invocationId) was already answered.")
    }
    return success
      ? await handle.sendSuccess(actionOutput: actionOutput)
      : await handle.sendFailure(actionOutput: actionOutput)
  }
}
