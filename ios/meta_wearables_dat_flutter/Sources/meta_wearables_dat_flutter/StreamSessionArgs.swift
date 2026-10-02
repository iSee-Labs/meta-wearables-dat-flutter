// Parses and validates `startStreamSession` arguments.

import Foundation
import MWDATCamera

struct StreamSessionArgs {
  static let allowedFrameRates: Set<Int> = [2, 7, 15, 24, 30]

  let deviceUuid: String?
  let frameRate: Int
  let resolution: StreamingResolution
  let videoCodec: VideoCodec
  let deviceKinds: Set<String>?
  let audioSampleRate: AudioSampleRate?
  let audioChannels: UInt32

  init(_ arguments: Any?) throws {
    let args = arguments as? [String: Any] ?? [:]
    deviceUuid = args["deviceUuid"] as? String

    let fps = (args["fps"] as? Int) ?? 24
    guard Self.allowedFrameRates.contains(fps) else {
      throw WireError.invalidArgument("fps must be one of 2, 7, 15, 24, 30 (got \(fps)).")
    }
    frameRate = fps

    switch (args["quality"] as? String) ?? "medium" {
    case "low": resolution = .low
    case "medium": resolution = .medium
    case "high": resolution = .high
    case let other: throw WireError.invalidArgument("Unknown quality '\(other)'.")
    }

    switch (args["videoCodec"] as? String) ?? "raw" {
    case "raw": videoCodec = .raw
    case "hvc1": videoCodec = .hvc1
    case let other: throw WireError.invalidArgument("Unknown videoCodec '\(other)'.")
    }

    if let kinds = args["deviceKinds"] as? [String], !kinds.isEmpty {
      deviceKinds = Set(kinds)
    } else {
      deviceKinds = nil
    }

    if let audio = args["audio"] as? [String: Any] {
      switch (audio["sampleRate"] as? Int) ?? 16000 {
      case 16000: audioSampleRate = .rate16000
      case 44100: audioSampleRate = .rate44100
      case 48000: audioSampleRate = .rate48000
      case let other:
        throw WireError.invalidArgument("audio.sampleRate must be 16000, 44100 or 48000 (got \(other)).")
      }
      audioChannels = UInt32((audio["channels"] as? Int) ?? 1)
    } else {
      audioSampleRate = nil
      audioChannels = 1
    }
  }

  var configuration: StreamConfiguration {
    if let rate = audioSampleRate {
      return StreamConfiguration(
        videoCodec: videoCodec,
        audioCodec: .pcm(sampleRate: rate, numberOfChannels: audioChannels),
        resolution: resolution,
        frameRate: UInt(frameRate))
    }
    return StreamConfiguration(videoCodec: videoCodec, resolution: resolution, frameRate: UInt(frameRate))
  }
}
