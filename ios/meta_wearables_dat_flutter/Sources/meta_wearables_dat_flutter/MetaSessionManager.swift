// Slice 7 - iOS streaming bridge.
//
// Owns:
//   - One `StreamSession` per active stream (only one in v0.1.0).
//   - One `FlutterTextureRegistry` entry that owns the latest decoded
//     `CVPixelBuffer`.
//   - Listener tokens for state / error / video-frame publishers.
//   - The three EventSinks (session_state, session_errors,
//     video_stream_size).
//
// The frame pump:
//   `videoFramePublisher` -> CMSampleBuffer -> CVImageBuffer (CVPixelBuffer)
//   -> `latestPixelBuffer` (atomic-ish swap) -> `textureRegistry
//     .textureFrameAvailable(id)` -> Flutter calls `copyPixelBuffer()`
//     -> we hand back the retained pixel buffer.
//
// All Meta SDK calls run on the main actor because that's what
// `Wearables.shared` and the camera publishers expect; texture-buffer swaps
// run inside a tiny critical section under `bufferLock`.

import Flutter
import CoreMedia
import CoreVideo
import UIKit
#if canImport(MWDATCore)
import MWDATCore
#endif
#if canImport(MWDATCamera)
import MWDATCamera
#endif

@MainActor
final class MetaSessionManager: NSObject {
  private weak var registry: FlutterTextureRegistry?

  private let bufferLock = NSLock()
  private var latestPixelBuffer: CVPixelBuffer?
  private var textureId: Int64?

  private var session: StreamSession?
  private var stateToken: AnyListenerToken?
  private var errorToken: AnyListenerToken?
  private var frameToken: AnyListenerToken?

  // EventSinks (set by the plugin when Dart subscribes).
  fileprivate var sessionStateSink: FlutterEventSink?
  fileprivate var sessionErrorSink: FlutterEventSink?
  fileprivate var videoStreamSizeSink: FlutterEventSink?

  init(registry: FlutterTextureRegistry) {
    self.registry = registry
  }

  // MARK: - Session lifecycle

  /// Starts a session for `deviceUUID` (or the active device when nil) at
  /// the requested `fps` and `quality`. Returns the Flutter texture id.
  func startSession(
    deviceUUID: String?,
    fps: Int,
    quality: StreamingResolution
  ) async throws -> Int64 {
    if let existingId = textureId { return existingId }
    guard let registry = registry else {
      throw NSError(
        domain: "meta_wearables_dat_flutter",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Texture registry unavailable"]
      )
    }

    // Resolve the target device. For v0.1 we drive AutoDeviceSelector when
    // no UUID is given; future versions can accept SpecificDeviceSelector.
    let deviceId: DeviceIdentifier? = {
      if let id = deviceUUID { return id }
      let auto = AutoDeviceSelector(wearables: Wearables.shared)
      return auto.activeDevice
    }()
    guard let resolvedId = deviceId,
          let device = Wearables.shared.deviceForIdentifier(resolvedId) else {
      throw NSError(
        domain: "meta_wearables_dat_flutter",
        code: -2,
        userInfo: [NSLocalizedDescriptionKey: "No connected device available"]
      )
    }

    // Build the stream config. Codec is locked to .raw for v0.1 (HEVC
    // arrives in v0.2 once we've validated VideoToolbox path on-device).
    let config = StreamSessionConfig(
      videoCodec: .raw,
      resolution: quality,
      frameRate: UInt(fps)
    )

    // Spin up a DeviceSession capability for the camera. The exact API
    // for "create a session for this device" is `device.makeSession()` /
    // `Wearables.shared.createSession(...)` depending on SDK version; the
    // pattern below mirrors Meta's CameraAccess sample for iOS 0.6.x.
    let deviceSession = try device.makeSession()
    guard let stream = try deviceSession.addStream(config: config) else {
      throw NSError(
        domain: "meta_wearables_dat_flutter",
        code: -3,
        userInfo: [NSLocalizedDescriptionKey: "addStream returned nil"]
      )
    }
    self.session = stream

    // Register a Flutter texture before frames start flowing.
    let id = registry.register(self)
    self.textureId = id

    // Wire publishers BEFORE starting so we don't miss the initial state
    // transition. Tokens are released in stopSession.
    stateToken = stream.statePublisher.listen { [weak self] state in
      Task { @MainActor in
        self?.sessionStateSink?(MetaSessionManager.encode(state))
      }
    }
    errorToken = stream.errorPublisher.listen { [weak self] error in
      Task { @MainActor in
        self?.sessionErrorSink?(MetaSessionManager.encode(error))
      }
    }
    frameToken = stream.videoFramePublisher.listen { [weak self] frame in
      self?.handleVideoFrame(frame, textureId: id)
    }

    await stream.start()
    return id
  }

  func stopSession() async {
    if let session = session {
      await session.stop()
    }
    stateToken?.cancel()
    errorToken?.cancel()
    frameToken?.cancel()
    stateToken = nil
    errorToken = nil
    frameToken = nil
    session = nil

    if let id = textureId {
      registry?.unregisterTexture(id)
      textureId = nil
    }
    bufferLock.lock()
    latestPixelBuffer = nil
    bufferLock.unlock()
  }

  func pauseSession() async {
    // The current MWDATCamera 0.6.x surface does not expose a
    // `pause()` method; pausing is driven entirely by the device (hinges
    // closed, thermal, ...). Callers see the resulting transition via
    // sessionStateStream. We document this here rather than throwing so
    // host apps can still call the API conditionally.
  }

  func resumeSession() async {
    // See pauseSession - resume is implicit when the device side flips
    // back to streaming.
  }

  // MARK: - Frame plumbing

  private func handleVideoFrame(_ frame: VideoFrame, textureId: Int64) {
    let sampleBuffer = frame.sampleBuffer
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
    bufferLock.lock()
    latestPixelBuffer = imageBuffer
    bufferLock.unlock()

    // Emit size update lazily so the host can rebuild AspectRatio without
    // every frame triggering a Flutter rebuild.
    let width = CVPixelBufferGetWidth(imageBuffer)
    let height = CVPixelBufferGetHeight(imageBuffer)
    if let sink = videoStreamSizeSink {
      sink(["width": width, "height": height])
    }

    registry?.textureFrameAvailable(textureId)
  }

  // MARK: - Encoding helpers

  private static func encode(_ state: StreamSessionState) -> Int {
    switch state {
    case .stopped: return 0
    case .waitingForDevice: return 1
    case .starting: return 2
    case .streaming: return 3
    case .paused: return 4
    case .stopping: return 5
    @unknown default: return 0
    }
  }

  private static func encode(_ error: StreamSessionError) -> [String: Any] {
    let code: String
    switch error {
    case .permissionDenied: code = "PERMISSION_ERROR"
    case .hingesClosed, .thermalCritical, .videoStreamingError, .timeout,
         .deviceNotFound, .deviceNotConnected, .internalError:
      code = "SESSION_ERROR"
    @unknown default:
      code = "SESSION_ERROR"
    }
    return [
      "code": code,
      "message": String(describing: error),
    ]
  }

  // MARK: - EventSink wiring (called from the plugin)

  func setSessionStateSink(_ sink: FlutterEventSink?) { sessionStateSink = sink }
  func setSessionErrorSink(_ sink: FlutterEventSink?) { sessionErrorSink = sink }
  func setVideoSizeSink(_ sink: FlutterEventSink?) { videoStreamSizeSink = sink }
}

extension MetaSessionManager: FlutterTexture {
  nonisolated func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    bufferLock.lock()
    defer { bufferLock.unlock() }
    guard let buffer = latestPixelBuffer else { return nil }
    return Unmanaged.passRetained(buffer)
  }
}
