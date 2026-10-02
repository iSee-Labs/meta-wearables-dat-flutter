// HEVC (`hvc1`) -> BGRA decoding pipeline for the texture preview, plus
// Annex-B helpers for the opt-in `videoFramesStream` payload.
//
// When `videoCodec: .hvc1` is selected on iOS, the MWDATCamera SDK emits
// compressed `CMSampleBuffer`s carrying HEVC NAL units. This pipeline:
//
//   - Lazily builds a `VTDecompressionSession` keyed on the
//     `CMVideoFormatDescription` of the first incoming sample buffer,
//     output pixel format `kCVPixelFormatType_32BGRA`.
//   - Decodes each sample synchronously so the resulting `CVPixelBuffer`
//     can be handed to Flutter's texture path on the same frame.
//   - Optionally surfaces the compressed NAL bytes (with VPS/SPS/PPS
//     prepended on every keyframe, in Annex-B form) so host apps can
//     forward them to an `mp4` muxer or to disk through
//     `videoFramesStream`.
//
// Software-only fallback is requested at build time via
// `kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder = false`
// when the caller flags `softwareOnly`, which the plugin does while
// background streaming is enabled (hardware decoders are suspended by
// the OS as soon as the app backgrounds).

import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

/// HEVC decoder for the texture preview. Not thread-safe: the owner calls it
/// from a single serial queue (`FramePump.frameQueue`).
final class VTDecompressionPipeline {
  /// Output pixel format handed to Flutter's external texture.
  private let outputPixelFormat: OSType = kCVPixelFormatType_32BGRA

  /// When true, build the `VTDecompressionSession` with hardware
  /// acceleration disabled. Costs some CPU but keeps decoding alive while
  /// the app is backgrounded (iOS suspends hardware decoders).
  var softwareOnly: Bool = false {
    didSet { if oldValue != softwareOnly { invalidate() } }
  }

  /// Rebuilt whenever the format description changes (resolution ladder).
  private var session: VTDecompressionSession?
  private var formatDescription: CMFormatDescription?
  /// After a (re)build, frames are skipped until the next keyframe so the
  /// decoder never starts from a dependent frame.
  private var awaitingKeyframe = true
  private var consecutiveFailures = 0
  private static let maxConsecutiveFailures = 3

  init() {}

  deinit {
    if let session { VTDecompressionSessionInvalidate(session) }
  }

  /// Releases the decoder. The next `decode(_:)` rebuilds it.
  func invalidate() {
    if let session {
      VTDecompressionSessionInvalidate(session)
      self.session = nil
    }
    formatDescription = nil
    awaitingKeyframe = true
    consecutiveFailures = 0
  }

  /// Decodes one HEVC sample buffer to a BGRA pixel buffer. Returns nil
  /// while waiting for a keyframe or when decoding fails; after repeated
  /// failures the session is rebuilt.
  func decode(_ sampleBuffer: CMSampleBuffer) -> CVPixelBuffer? {
    guard let desc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
    guard ensureSession(for: desc), let session else { return nil }

    if awaitingKeyframe {
      guard Self.isKeyframe(sampleBuffer) else { return nil }
      awaitingKeyframe = false
    }

    var decoded: CVPixelBuffer?
    var infoFlags = VTDecodeInfoFlags()
    let status = VTDecompressionSessionDecodeFrame(
      session,
      sampleBuffer: sampleBuffer,
      flags: [],
      infoFlagsOut: &infoFlags,
      outputHandler: { status, _, buffer, _, _ in
        if status == noErr { decoded = buffer }
      }
    )
    if status != noErr || decoded == nil {
      consecutiveFailures += 1
      if consecutiveFailures >= Self.maxConsecutiveFailures {
        print("[meta_wearables_dat_flutter] HEVC decode failed \(consecutiveFailures)x " +
          "(status=\(status)); rebuilding decoder")
        invalidate()
      }
      return nil
    }
    consecutiveFailures = 0
    return decoded
  }

  /// (Re)builds the decompression session when the format changes.
  private func ensureSession(for desc: CMFormatDescription) -> Bool {
    if let existing = formatDescription, session != nil {
      if CFEqual(existing, desc) { return true }
      if let session, VTDecompressionSessionCanAcceptFormatDescription(session, formatDescription: desc) {
        formatDescription = desc
        return true
      }
    }
    if let stale = session {
      VTDecompressionSessionInvalidate(stale)
      session = nil
    }
    formatDescription = desc
    awaitingKeyframe = true

    let dims = CMVideoFormatDescriptionGetDimensions(desc)
    let imageBufferAttrs: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: outputPixelFormat,
      kCVPixelBufferWidthKey as String: Int(dims.width),
      kCVPixelBufferHeightKey as String: Int(dims.height),
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
      kCVPixelBufferMetalCompatibilityKey as String: true,
    ]
    let spec: [String: Any] = [
      kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder as String: !softwareOnly
    ]

    var newSession: VTDecompressionSession?
    let status = VTDecompressionSessionCreate(
      allocator: kCFAllocatorDefault,
      formatDescription: desc,
      decoderSpecification: spec as CFDictionary,
      imageBufferAttributes: imageBufferAttrs as CFDictionary,
      outputCallback: nil,
      decompressionSessionOut: &newSession
    )
    if status != noErr {
      print("[meta_wearables_dat_flutter] VTDecompressionSessionCreate failed " +
        "status=\(status) software=\(softwareOnly)")
      session = nil
      return false
    }
    session = newSession
    return true
  }

  /// Extracts the HEVC `VPS`, `SPS`, and `PPS` parameter sets from a
  /// `CMVideoFormatDescription` and returns them as Annex-B encoded
  /// NAL units (i.e. each prefixed with the `00 00 00 01` start code).
  /// Returns `nil` when the format description does not carry HEVC
  /// parameter sets (e.g. for `kCMVideoCodecType_H264`).
  static func annexBParameterSets(from desc: CMFormatDescription) -> Data? {
    var count = 0
    let probe = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
      desc,
      parameterSetIndex: 0,
      parameterSetPointerOut: nil,
      parameterSetSizeOut: nil,
      parameterSetCountOut: &count,
      nalUnitHeaderLengthOut: nil
    )
    if probe != noErr || count == 0 { return nil }

    var out = Data()
    for i in 0..<count {
      var pointer: UnsafePointer<UInt8>?
      var size = 0
      let status = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
        desc,
        parameterSetIndex: i,
        parameterSetPointerOut: &pointer,
        parameterSetSizeOut: &size,
        parameterSetCountOut: nil,
        nalUnitHeaderLengthOut: nil
      )
      if status == noErr, let pointer = pointer, size > 0 {
        out.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        out.append(pointer, count: size)
      }
    }
    return out.isEmpty ? nil : out
  }

  /// Reads the (length-prefixed AVCC-style) NAL bytes from a sample
  /// buffer's underlying `CMBlockBuffer` and returns them as an
  /// Annex-B encoded `Data` (start codes between NAL units instead of
  /// 4-byte length prefixes).
  static func annexBNalBytes(from sampleBuffer: CMSampleBuffer) -> Data? {
    guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else {
      return nil
    }
    // The block buffer may be non-contiguous; copy it into one Data first.
    let totalLength = CMBlockBufferGetDataLength(block)
    guard totalLength > 0 else { return nil }
    var source = Data(count: totalLength)
    let copyStatus = source.withUnsafeMutableBytes { raw -> OSStatus in
      guard let base = raw.baseAddress else { return -1 }
      return CMBlockBufferCopyDataBytes(
        block, atOffset: 0, dataLength: totalLength, destination: base)
    }
    if copyStatus != noErr { return nil }
    return source.withUnsafeBytes { raw -> Data? in
      guard let bytes = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
      return annexB(from: bytes, totalLength: totalLength)
    }
  }

  private static func annexB(from bytes: UnsafePointer<UInt8>, totalLength: Int) -> Data? {
    var out = Data()
    out.reserveCapacity(totalLength + 16)
    var offset = 0
    while offset + 4 <= totalLength {
      // AVCC NAL units are prefixed with a 4-byte big-endian length.
      let length = (UInt32(bytes[offset]) << 24) |
        (UInt32(bytes[offset + 1]) << 16) |
        (UInt32(bytes[offset + 2]) << 8) |
        UInt32(bytes[offset + 3])
      offset += 4
      if length == 0 || offset + Int(length) > totalLength { break }
      out.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
      out.append(bytes + offset, count: Int(length))
      offset += Int(length)
    }
    return out.isEmpty ? nil : out
  }

  /// Reports whether a sample buffer's primary attachment marks it as a
  /// keyframe (i.e. independent of any other frame).
  static func isKeyframe(_ sampleBuffer: CMSampleBuffer) -> Bool {
    guard
      let attachments = CMSampleBufferGetSampleAttachmentsArray(
        sampleBuffer,
        createIfNecessary: false
      ) as? [[CFString: Any]],
      let first = attachments.first
    else {
      // No attachments → assume keyframe (matches Apple's behaviour for
      // single-NAL CMSampleBuffers).
      return true
    }
    if let dependsOnOthers = first[kCMSampleAttachmentKey_DependsOnOthers]
      as? Bool {
      return !dependsOnOthers
    }
    if let notSync = first[kCMSampleAttachmentKey_NotSync] as? Bool {
      return !notSync
    }
    return true
  }
}
