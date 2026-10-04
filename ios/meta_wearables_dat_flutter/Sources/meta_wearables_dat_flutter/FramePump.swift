// Moves camera frames from the DAT SDK to Flutter.
//
// Frames arrive on an SDK thread and are processed on one serial queue:
//   raw  -> the sample buffer's CVPixelBuffer is shown directly
//   hvc1 -> VTDecompressionPipeline decodes to BGRA for the texture
// The latest pixel buffer is published to Flutter's texture registry
// (`copyPixelBuffer`), never over a method channel. The opt-in
// `video_frames` and `video_stream_size` payloads are built only while a
// Dart listener is attached and are delivered on the main thread.

import CoreMedia
import CoreVideo
import Flutter
import Foundation
import MWDATCamera

final class FramePump: NSObject, FlutterTexture, @unchecked Sendable {
  private let frameQueue = DispatchQueue(label: "meta_wearables_dat_flutter.frames", qos: .userInitiated)
  private let lock = NSLock()

  // Guarded by `lock`.
  private var latestPixelBuffer: CVPixelBuffer?
  private var wantsFrames = false
  private var wantsSize = false

  // Owned by `frameQueue`.
  private weak var registry: FlutterTextureRegistry?
  private var textureId: Int64 = -1
  private var codec: VideoCodec = .raw
  private var pipeline: VTDecompressionPipeline?
  private var lastWidth = 0
  private var lastHeight = 0

  // Main-thread only.
  var framesSink: FlutterEventSink? {
    didSet { setFlag(\.wantsFrames, framesSink != nil) }
  }
  var sizeSink: FlutterEventSink? {
    didSet { setFlag(\.wantsSize, sizeSink != nil) }
  }

  init(registry: FlutterTextureRegistry) {
    self.registry = registry
  }

  private func setFlag(_ key: ReferenceWritableKeyPath<FramePump, Bool>, _ value: Bool) {
    lock.lock()
    self[keyPath: key] = value
    lock.unlock()
  }

  private func flag(_ key: KeyPath<FramePump, Bool>) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return self[keyPath: key]
  }

  /// Registers the Flutter texture and prepares the decoder for `codec`.
  func start(codec: VideoCodec, softwareDecoder: Bool) -> Int64 {
    let id = registry?.register(self) ?? -1
    frameQueue.sync {
      self.textureId = id
      self.codec = codec
      self.lastWidth = 0
      self.lastHeight = 0
      if codec == .hvc1 {
        let pipeline = VTDecompressionPipeline()
        pipeline.softwareOnly = softwareDecoder
        self.pipeline = pipeline
      } else {
        self.pipeline = nil
      }
    }
    return id
  }

  /// Unregisters the texture and releases the decoder. Waits for any frame
  /// being processed so no callback outlives the stop.
  func stop() {
    var id: Int64 = -1
    frameQueue.sync {
      id = self.textureId
      self.textureId = -1
      self.pipeline?.invalidate()
      self.pipeline = nil
    }
    lock.lock()
    latestPixelBuffer = nil
    lock.unlock()
    if id >= 0 { registry?.unregisterTexture(id) }
  }

  var hasDecoder: Bool { frameQueue.sync { pipeline != nil } }

  func setSoftwareDecoder(_ enabled: Bool) {
    frameQueue.async { self.pipeline?.softwareOnly = enabled }
  }

  /// Entry point from `Stream.videoFramePublisher` (any thread).
  func enqueue(_ frame: VideoFrame) {
    let sampleBuffer = frame.sampleBuffer
    frameQueue.async { [weak self] in self?.process(sampleBuffer) }
  }

  private func process(_ sampleBuffer: CMSampleBuffer) {
    guard textureId >= 0 else { return }
    let pixelBuffer: CVPixelBuffer?
    if codec == .hvc1 {
      pixelBuffer = pipeline?.decode(sampleBuffer)
    } else {
      pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    }

    if codec == .hvc1, flag(\.wantsFrames), let payload = Self.hevcPayload(sampleBuffer) {
      deliverFrame(payload)
    }

    guard let pixelBuffer else { return }
    lock.lock()
    latestPixelBuffer = pixelBuffer
    lock.unlock()

    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    if width != lastWidth || height != lastHeight {
      lastWidth = width
      lastHeight = height
      DispatchQueue.main.async { [weak self] in
        self?.sizeSink?(["width": width, "height": height])
      }
    }

    if codec == .raw, flag(\.wantsFrames) {
      deliverFrame(Self.rawPayload(sampleBuffer: sampleBuffer, pixelBuffer: pixelBuffer))
    }

    registry?.textureFrameAvailable(textureId)
  }

  private func deliverFrame(_ payload: [String: Any]) {
    DispatchQueue.main.async { [weak self] in self?.framesSink?(payload) }
  }

  /// Re-emits the current size to a newly attached listener.
  func replaySize() {
    let (w, h) = frameQueue.sync { (lastWidth, lastHeight) }
    if w > 0, h > 0 { sizeSink?(["width": w, "height": h]) }
  }

  // MARK: FlutterTexture

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    lock.lock()
    defer { lock.unlock() }
    guard let buffer = latestPixelBuffer else { return nil }
    return Unmanaged.passRetained(buffer)
  }

  // MARK: Payloads

  static func ptsMicros(_ sampleBuffer: CMSampleBuffer) -> Int {
    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    return pts.isValid ? Int(CMTimeGetSeconds(pts) * 1_000_000.0) : 0
  }

  /// Annex-B HEVC payload; parameter sets are prepended on keyframes.
  static func hevcPayload(_ sampleBuffer: CMSampleBuffer) -> [String: Any]? {
    let isKeyframe = VTDecompressionPipeline.isKeyframe(sampleBuffer)
    guard let nal = VTDecompressionPipeline.annexBNalBytes(from: sampleBuffer) else { return nil }
    var bytes = Data()
    let desc = CMSampleBufferGetFormatDescription(sampleBuffer)
    if isKeyframe, let desc, let params = VTDecompressionPipeline.annexBParameterSets(from: desc) {
      bytes.append(params)
    }
    bytes.append(nal)
    let dims = desc.map(CMVideoFormatDescriptionGetDimensions) ?? CMVideoDimensions(width: 0, height: 0)
    return [
      "codec": "hvc1",
      "bytes": FlutterStandardTypedData(bytes: bytes),
      "width": Int(dims.width),
      "height": Int(dims.height),
      "ptsUs": ptsMicros(sampleBuffer),
      "isKeyframe": isKeyframe,
      "isCodecConfig": false,
    ]
  }

  /// Raw payload. Single-plane buffers (BGRA) travel in `bytes`; bi-planar
  /// YUV (420v / 420f) travels as `planes`, with `bytes` holding the planes
  /// concatenated for consumers that only read one buffer.
  static func rawPayload(sampleBuffer: CMSampleBuffer, pixelBuffer: CVPixelBuffer) -> [String: Any] {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    var payload: [String: Any] = [
      "codec": "raw",
      "width": width,
      "height": height,
      "ptsUs": ptsMicros(sampleBuffer),
      "isKeyframe": true,
      "isCodecConfig": false,
    ]
    let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
    if CVPixelBufferIsPlanar(pixelBuffer) {
      payload["pixelFormat"] = "nv12"
      var planes: [[String: Any]] = []
      var all = Data()
      for index in 0..<CVPixelBufferGetPlaneCount(pixelBuffer) {
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, index) else { continue }
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, index)
        let rows = CVPixelBufferGetHeightOfPlane(pixelBuffer, index)
        let data = Data(bytes: base, count: rowBytes * rows)
        all.append(data)
        planes.append([
          "bytes": FlutterStandardTypedData(bytes: data),
          "bytesPerRow": rowBytes,
          "width": CVPixelBufferGetWidthOfPlane(pixelBuffer, index),
          "height": rows,
        ])
      }
      payload["planes"] = planes
      payload["bytes"] = FlutterStandardTypedData(bytes: all)
      payload["bytesPerRow"] = planes.first?["bytesPerRow"] ?? width
      payload["fullRange"] = format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    } else {
      payload["pixelFormat"] = format == kCVPixelFormatType_32BGRA ? "bgra" : "unknown"
      if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        payload["bytes"] = FlutterStandardTypedData(bytes: Data(bytes: base, count: rowBytes * height))
        payload["bytesPerRow"] = rowBytes
      }
    }
    return payload
  }
}
