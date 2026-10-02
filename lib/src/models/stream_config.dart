import 'package:meta/meta.dart';
import 'package:meta_wearables_dat_flutter/src/models/device_info.dart';
import 'package:meta_wearables_dat_flutter/src/models/stream_quality.dart';
import 'package:meta_wearables_dat_flutter/src/models/video_frame.dart';

/// Sample rates for experimental in-stream audio.
@experimental
enum AudioSampleRate {
  /// 16 kHz.
  hz16000(16000),

  /// 44.1 kHz.
  hz44100(44100),

  /// 48 kHz.
  hz48000(48000);

  const AudioSampleRate(this.value);

  /// Sample rate in Hz.
  final int value;
}

/// Experimental PCM audio from the glasses microphone, streamed with the
/// video. Not beamformed.
///
/// **Experimental:** cannot be used in apps on production release channels.
@experimental
class AudioStreamConfig {
  /// Creates an [AudioStreamConfig].
  const AudioStreamConfig({
    this.sampleRate = AudioSampleRate.hz16000,
    this.channels = 1,
  });

  /// Sample rate.
  final AudioSampleRate sampleRate;

  /// Channel count.
  final int channels;

  /// Platform-channel encoding.
  Map<String, Object?> toMap() => {
    'sampleRate': sampleRate.value,
    'channels': channels,
  };
}

/// Settings for `MetaWearablesDat.startStreamSession`.
class StreamSessionConfig {
  /// Creates a [StreamSessionConfig].
  const StreamSessionConfig({
    this.quality = StreamQuality.medium,
    this.frameRate = StreamFrameRate.fps24,
    this.videoCodec = VideoCodec.raw,
    this.deviceKinds,
    this.audio,
  });

  /// Requested resolution.
  final StreamQuality quality;

  /// Requested frame rate.
  final StreamFrameRate frameRate;

  /// Requested codec. Use [VideoCodec.hvc1] to keep streaming in the
  /// background on iOS or to record without re-encoding.
  final VideoCodec videoCodec;

  /// Only consider glasses of these families when picking a device.
  final Set<DeviceKind>? deviceKinds;

  /// Experimental: also stream PCM audio from the glasses microphone.
  @experimental
  final AudioStreamConfig? audio;

  /// Platform-channel encoding.
  Map<String, Object?> toMap({String? deviceUuid}) => {
    if (deviceUuid != null) 'deviceUuid': deviceUuid,
    'fps': frameRate.value,
    'quality': quality.name,
    'videoCodec': videoCodec.name,
    if (deviceKinds != null && deviceKinds!.isNotEmpty)
      'deviceKinds': deviceKinds!
          .map((k) => k.wireName)
          .toList(growable: false),
    if (audio != null) 'audio': audio!.toMap(),
  };
}
