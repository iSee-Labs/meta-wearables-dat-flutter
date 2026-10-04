// Camera streaming bridge (DAT 1.0 consolidated `Camera` capability).
//
// start: hub.acquire (shared DeviceSession, started) -> register texture
//        -> session.addCamera(config) -> subscribe camera / stream
//        publishers (before start) -> stream.start() -> wait for .streaming
// stop:  cancel listeners -> camera.stop() (cascades to the stream and
//        detaches it) -> hub.release -> unregister texture
//
// Every terminal path (user stop, stream stopped by the device, session
// ended) converges on `clearStreamResources()`, which is idempotent.
// Photos: `Stream.capturePhoto(format:)` (publishable) and the
// experimental high-resolution `Camera.photo`.

import AVFAudio
import CoreMedia
import Flutter
import Foundation
import MWDATCamera
import MWDATCore

@MainActor
final class MetaSessionManager {
  static let owner = "camera"
  static let streamingTimeoutSeconds: Double = 30
  static let photoTimeoutSeconds: Double = 15
  static let hqPhotoTimeoutSeconds: Double = 45

  private let hub: DeviceSessionHub
  private let pump: FramePump

  private var camera: Camera?
  private var stream: MWDATCamera.Stream?
  private let tokens = ListenerTokenBag()
  private var listenerCount = 0
  private var textureId: Int64?
  private var lastStreamState: StreamState = .stopped
  private var hasBeenActive = false

  private var pendingPhoto: CheckedContinuation<PhotoData, Error>?
  private var pendingPhotoTimeout: Task<Void, Never>?

  private var hqPhotoStarted = false
  private var pendingHqPhoto: CheckedContinuation<PhotoCaptureData, Error>?
  private var pendingHqTimeout: Task<Void, Never>?

  let stateSink = EventSinkHandler()
  let errorSink = EventSinkHandler()
  let cameraStateSink = EventSinkHandler(replaysLast: true)
  let sizeSink = EventSinkHandler()
  let framesSink = EventSinkHandler()
  let audioSink = EventSinkHandler()
  let photoProgressSink = EventSinkHandler()
  let photoStateSink = EventSinkHandler(replaysLast: true)
  let photoErrorSink = EventSinkHandler()

  /// Software HEVC decoding while background streaming is enabled.
  var softwareDecoder = false {
    didSet { pump.setSoftwareDecoder(softwareDecoder) }
  }

  init(registry: FlutterTextureRegistry, hub: DeviceSessionHub) {
    self.hub = hub
    self.pump = FramePump(registry: registry)
    framesSink.onSinkChange = { [weak self] sink, _ in self?.pump.framesSink = sink }
    sizeSink.onSinkChange = { [weak self] sink, _ in
      self?.pump.sizeSink = sink
      if sink != nil { self?.pump.replaySize() }
    }
    stateSink.onSinkChange = { [weak self] sink, _ in
      guard let self, let sink else { return }
      sink(WireCodec.streamState(self.lastStreamState))
    }
  }

  var isStreaming: Bool { camera != nil }
  var activeCodec: VideoCodec? { stream?.streamConfiguration.videoCodec }

  // MARK: - Lifecycle

  func startSession(_ args: StreamSessionArgs) async throws -> Int64 {
    if let textureId, camera != nil { return textureId }

    let session = try await hub.acquire(
      owner: Self.owner,
      deviceUuid: args.deviceUuid,
      deviceKinds: args.deviceKinds,
      onTerminated: { [weak self] in
        Task { @MainActor in await self?.clearStreamResources(releaseHub: false) }
      })

    let id = pump.start(codec: args.videoCodec, softwareDecoder: softwareDecoder)
    textureId = id
    ResourceLedger.shared.acquire(.textures)
    if args.videoCodec == .hvc1 { ResourceLedger.shared.acquire(.decoders) }

    let camera: Camera
    do {
      guard let added = try session.addCamera(config: args.configuration) else {
        throw WireError(
          category: WireCategory.deviceSession, caseName: "sessionIdle",
          message: "The device session is not started; the camera could not be added.")
      }
      camera = added
    } catch {
      await clearStreamResources(releaseHub: true)
      throw WireErrors.from(error, fallbackCategory: WireCategory.deviceSession)
    }
    self.camera = camera
    self.stream = camera.stream
    ResourceLedger.shared.acquire(.cameras)
    hasBeenActive = false

    subscribe(camera: camera, stream: camera.stream)
    camera.stream.start()

    try await waitForStreaming(camera.stream)
    return id
  }

  func stopSession() async {
    await clearStreamResources(releaseHub: true)
  }

  private func subscribe(camera: Camera, stream: MWDATCamera.Stream) {
    camera.statePublisher.listen { [weak self] state in
      Task { @MainActor in self?.cameraStateSink.send(WireCodec.cameraState(state)) }
    }.store(in: tokens)
    stream.statePublisher.listen { [weak self] state in
      Task { @MainActor in self?.handleStreamState(state) }
    }.store(in: tokens)
    stream.errorPublisher.listen { [weak self] error in
      Task { @MainActor in self?.handleStreamError(error) }
    }.store(in: tokens)
    let pump = self.pump
    stream.videoFramePublisher.listen { frame in
      pump.enqueue(frame)
    }.store(in: tokens)
    stream.photoDataPublisher.listen { [weak self] photo in
      Task { @MainActor in self?.deliverPhoto(.success(photo)) }
    }.store(in: tokens)
    stream.audioFramePublisher.listen { [weak self] frame in
      let payload = Self.audioPayload(frame)
      Task { @MainActor in self?.audioSink.send(payload) }
    }.store(in: tokens)
    listenerCount = 6
    ResourceLedger.shared.acquire(.listeners, listenerCount)
  }

  private func handleStreamState(_ state: StreamState) {
    lastStreamState = state
    stateSink.send(WireCodec.streamState(state))
    switch state {
    case .streaming, .paused, .starting, .waitingForDevice:
      hasBeenActive = true
    case .stopped:
      // A stream that stops on its own (hinges closed, error) while the
      // session stays up still detaches the camera so a later start works.
      if hasBeenActive, camera != nil {
        Task { await clearStreamResources(releaseHub: true) }
      }
    default:
      break
    }
  }

  private func handleStreamError(_ error: StreamError) {
    let wire = WireCodec.error(error)
    errorSink.send(wire.eventPayload)
    if case .photoCaptureFailed = error {
      deliverPhoto(.failure(WireError(
        category: WireCategory.capture, caseName: "captureFailed",
        message: wire.message, platformCase: wire.platformCase)))
    }
  }

  private func waitForStreaming(_ stream: MWDATCamera.Stream) async throws {
    let deadline = Date().addingTimeInterval(Self.streamingTimeoutSeconds)
    while Date() < deadline {
      guard self.stream === stream else {
        throw WireError(
          category: WireCategory.stream, caseName: "stoppedBeforeStart",
          message: "The stream stopped before it started.")
      }
      switch stream.state {
      case .streaming, .paused: return
      case .stopped where hasBeenActive:
        throw WireError(
          category: WireCategory.stream, caseName: "stoppedBeforeStart",
          message: "The stream stopped before it started.")
      default:
        try await Task.sleep(nanoseconds: 100_000_000)
      }
    }
    // Soft timeout: the texture is registered and the stream keeps trying
    // (for example while the glasses are doffed); report it as an event.
    errorSink.send(WireError(
      category: WireCategory.stream, caseName: "timeout",
      message: "The stream did not start within \(Int(Self.streamingTimeoutSeconds)) s; still waiting for the device."
    ).eventPayload)
  }

  /// Single teardown convergence point. Idempotent.
  private func clearStreamResources(releaseHub: Bool) async {
    let camera = self.camera
    let hadTexture = textureId != nil
    let hadDecoder = pump.hasDecoder
    self.camera = nil
    self.stream = nil

    await tokens.cancelAll()
    if listenerCount > 0 {
      ResourceLedger.shared.release(.listeners, listenerCount)
      listenerCount = 0
    }
    if let camera {
      camera.stop()
      ResourceLedger.shared.release(.cameras)
    }
    hqPhotoStarted = false
    lastPhotoState = .stopped
    failPendingPhotos(WireError(
      category: WireCategory.capture, caseName: "sessionStopped",
      message: "The stream stopped during the capture."))

    pump.stop()
    if hadTexture {
      textureId = nil
      ResourceLedger.shared.release(.textures)
    }
    if hadDecoder { ResourceLedger.shared.release(.decoders) }

    if lastStreamState != .stopped {
      lastStreamState = .stopped
      stateSink.send(WireCodec.streamState(.stopped))
    }
    if releaseHub { await hub.release(owner: Self.owner) }
  }

  // MARK: - Photo from the stream (publishable)

  func capturePhoto(format: PhotoCaptureFormat) async throws -> PhotoData {
    guard let stream else {
      throw WireError(
        category: WireCategory.capture, caseName: "notStreaming",
        message: "No active stream. Call startStreamSession first.")
    }
    if pendingPhoto != nil {
      throw WireError(
        category: WireCategory.capture, caseName: "captureInProgress",
        message: "A photo capture is already in progress.")
    }
    return try await withCheckedThrowingContinuation { continuation in
      pendingPhoto = continuation
      pendingPhotoTimeout = Task { @MainActor [weak self] in
        try? await Task.sleep(nanoseconds: UInt64(Self.photoTimeoutSeconds * 1_000_000_000))
        guard !Task.isCancelled else { return }
        self?.deliverPhoto(.failure(WireError(
          category: WireCategory.capture, caseName: "timeout",
          message: "The glasses did not return a photo within \(Int(Self.photoTimeoutSeconds)) s.")))
      }
      if !stream.capturePhoto(format: format) {
        deliverPhoto(.failure(WireError(
          category: WireCategory.capture, caseName: "captureFailed",
          message: "The SDK rejected the capture request (stream not streaming).")))
      }
    }
  }

  private func deliverPhoto(_ result: Result<PhotoData, Error>) {
    guard let continuation = pendingPhoto else { return }
    pendingPhoto = nil
    pendingPhotoTimeout?.cancel()
    pendingPhotoTimeout = nil
    continuation.resume(with: result)
  }

  // MARK: - Experimental high-resolution photo (Camera.photo)

  func captureHqPhoto(resolution: PhotoResolution, quality: PhotoQuality) async throws
    -> PhotoCaptureData
  {
    guard let camera else {
      throw WireError(
        category: WireCategory.photo, caseName: "notReady",
        message: "No active camera. Call startStreamSession first.")
    }
    if pendingHqPhoto != nil {
      throw WireError(
        category: WireCategory.photo, caseName: "busy",
        message: "A high-resolution capture is already in progress.")
    }
    let photo = camera.photo
    if !hqPhotoStarted {
      subscribe(photo: photo)
      photo.start()
      hqPhotoStarted = true
      let deadline = Date().addingTimeInterval(10)
      while lastPhotoState != .started, Date() < deadline {
        try await Task.sleep(nanoseconds: 100_000_000)
      }
    }
    return try await withCheckedThrowingContinuation { continuation in
      pendingHqPhoto = continuation
      pendingHqTimeout = Task { @MainActor [weak self] in
        try? await Task.sleep(nanoseconds: UInt64(Self.hqPhotoTimeoutSeconds * 1_000_000_000))
        guard !Task.isCancelled else { return }
        self?.deliverHqPhoto(.failure(WireError(
          category: WireCategory.photo, caseName: "timeout",
          message: "No photo arrived within \(Int(Self.hqPhotoTimeoutSeconds)) s.")))
      }
      photo.capturePhoto(resolution: resolution, quality: quality)
    }
  }

  private var lastPhotoState: PhotoState = .stopped

  private func subscribe(photo: Photo) {
    photo.statePublisher.listen { [weak self] state in
      Task { @MainActor in
        self?.lastPhotoState = state
        self?.photoStateSink.send(WireCodec.photoState(state))
      }
    }.store(in: tokens)
    photo.photoDataPublisher.listen { [weak self] data in
      Task { @MainActor in self?.deliverHqPhoto(.success(data)) }
    }.store(in: tokens)
    photo.errorPublisher.listen { [weak self] error in
      Task { @MainActor in
        let wire = WireCodec.error(error)
        self?.photoErrorSink.send(wire.eventPayload)
        self?.deliverHqPhoto(.failure(wire))
      }
    }.store(in: tokens)
    photo.transferProgressPublisher.listen { [weak self] progress in
      let payload: [String: Any] = [
        "bytesReceived": Int(progress.bytesReceived),
        "totalBytes": Int(progress.totalBytes),
      ]
      Task { @MainActor in self?.photoProgressSink.send(payload) }
    }.store(in: tokens)
    listenerCount += 4
    ResourceLedger.shared.acquire(.listeners, 4)
  }

  private func deliverHqPhoto(_ result: Result<PhotoCaptureData, Error>) {
    guard let continuation = pendingHqPhoto else { return }
    pendingHqPhoto = nil
    pendingHqTimeout?.cancel()
    pendingHqTimeout = nil
    continuation.resume(with: result)
  }

  private func failPendingPhotos(_ error: WireError) {
    deliverPhoto(.failure(error))
    deliverHqPhoto(.failure(WireError(
      category: WireCategory.photo, caseName: "deviceDisconnected", message: error.message)))
  }

  // MARK: - Audio (experimental)

  /// Interleaved 16-bit little-endian PCM, the same layout Android emits.
  nonisolated static func audioPayload(_ frame: AudioFrame) -> [String: Any] {
    let buffer = frame.pcmBuffer
    let channels = Int(buffer.format.channelCount)
    let frames = Int(buffer.frameLength)
    var pcm = Data(count: frames * channels * 2)
    pcm.withUnsafeMutableBytes { raw in
      let out = raw.bindMemory(to: Int16.self)
      if let floats = buffer.floatChannelData {
        for f in 0..<frames {
          for c in 0..<channels {
            let v = max(-1, min(1, floats[c][f]))
            out[f * channels + c] = Int16(v * Float(Int16.max)).littleEndian
          }
        }
      } else if let ints = buffer.int16ChannelData {
        for f in 0..<frames {
          for c in 0..<channels { out[f * channels + c] = ints[c][f].littleEndian }
        }
      }
    }
    let pts = frame.presentationTimeStamp
    return [
      "bytes": FlutterStandardTypedData(bytes: pcm),
      "sampleRate": Int(buffer.format.sampleRate),
      "channels": channels,
      "ptsUs": pts.isValid ? Int(CMTimeGetSeconds(pts) * 1_000_000) : 0,
    ]
  }
}
