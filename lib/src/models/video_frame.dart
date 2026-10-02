import 'dart:typed_data';

/// Video codec requested from the glasses.
enum VideoCodec {
  /// Decoded frames. iOS delivers them only while the app is in the
  /// foreground.
  raw,

  /// Compressed HEVC (H.265). Keeps flowing while backgrounded; the plugin
  /// still decodes it for the texture preview.
  hvc1,
}

/// Pixel layout of a raw [VideoFrame].
enum VideoPixelFormat {
  /// Android: planar YUV 4:2:0 (Y, then U, then V).
  i420,

  /// iOS: bi-planar YUV 4:2:0 (Y plane, then interleaved CbCr) in [VideoFrame.planes].
  nv12,

  /// iOS: 32-bit BGRA.
  bgra,

  /// Compressed ([VideoCodec.hvc1]) or not recognised.
  unknown,
}

/// One plane of a planar raw frame.
class VideoFramePlane {
  /// Creates a [VideoFramePlane].
  const VideoFramePlane({
    required this.bytes,
    required this.bytesPerRow,
    required this.width,
    required this.height,
  });

  /// Decodes a platform-channel map.
  factory VideoFramePlane.fromMap(Map<Object?, Object?> map) => VideoFramePlane(
    bytes: _bytes(map['bytes']),
    bytesPerRow: (map['bytesPerRow'] as num?)?.toInt() ?? 0,
    width: (map['width'] as num?)?.toInt() ?? 0,
    height: (map['height'] as num?)?.toInt() ?? 0,
  );

  /// Plane data, `bytesPerRow * height` bytes.
  final Uint8List bytes;

  /// Row stride in bytes.
  final int bytesPerRow;

  /// Plane width in samples.
  final int width;

  /// Plane height in rows.
  final int height;
}

Uint8List _bytes(Object? raw) => switch (raw) {
  final Uint8List u => u,
  final List<int> l => Uint8List.fromList(l),
  _ => Uint8List(0),
};

/// A camera frame from `MetaWearablesDat.videoFramesStream()`.
///
/// Opt-in and expensive: a 720x1280 raw frame is about 1.4 MB (I420/NV12)
/// to 3.7 MB (BGRA), copied across the platform channel for every frame.
/// Use the texture preview when you only need to show video.
class VideoFrame {
  /// Creates a [VideoFrame].
  const VideoFrame({
    required this.codec,
    required this.bytes,
    required this.width,
    required this.height,
    required this.ptsUs,
    required this.isKeyframe,
    this.bytesPerRow,
    this.pixelFormat = VideoPixelFormat.unknown,
    this.planes = const <VideoFramePlane>[],
    this.isCodecConfig = false,
  });

  /// Decodes a platform-channel map.
  factory VideoFrame.fromMap(Map<Object?, Object?> map) {
    final codec = map['codec'] == 'hvc1' ? VideoCodec.hvc1 : VideoCodec.raw;
    final planes =
        (map['planes'] as List<Object?>?)
            ?.whereType<Map<Object?, Object?>>()
            .map(VideoFramePlane.fromMap)
            .toList(growable: false) ??
        const <VideoFramePlane>[];
    return VideoFrame(
      codec: codec,
      bytes: _bytes(map['bytes']),
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      ptsUs: (map['ptsUs'] as num?)?.toInt() ?? 0,
      isKeyframe: map['isKeyframe'] as bool? ?? true,
      bytesPerRow: (map['bytesPerRow'] as num?)?.toInt(),
      pixelFormat: codec == VideoCodec.hvc1
          ? VideoPixelFormat.unknown
          : switch (map['pixelFormat']) {
              'i420' => VideoPixelFormat.i420,
              'nv12' => VideoPixelFormat.nv12,
              'bgra' => VideoPixelFormat.bgra,
              _ => VideoPixelFormat.unknown,
            },
      planes: planes,
      isCodecConfig: map['isCodecConfig'] as bool? ?? false,
    );
  }

  /// Codec of [bytes].
  final VideoCodec codec;

  /// Frame data. Raw: the pixels (planes concatenated for planar formats).
  /// hvc1: Annex-B HEVC; parameter sets are included on keyframes (iOS) or
  /// sent as a separate [isCodecConfig] frame (Android).
  final Uint8List bytes;

  /// Frame width in pixels.
  final int width;

  /// Frame height in pixels.
  final int height;

  /// Presentation timestamp in microseconds.
  final int ptsUs;

  /// Whether the frame is independently decodable. Always true for raw.
  final bool isKeyframe;

  /// Row stride of [bytes] (first plane) when known.
  final int? bytesPerRow;

  /// Pixel layout of a raw frame.
  final VideoPixelFormat pixelFormat;

  /// Individual planes for planar raw formats (iOS NV12).
  final List<VideoFramePlane> planes;

  /// Android hvc1: this frame only carries codec parameter sets.
  final bool isCodecConfig;
}

/// Experimental in-stream PCM audio from the glasses microphone.
///
/// **Experimental:** cannot be used in apps on production release channels.
class AudioFrame {
  /// Creates an [AudioFrame].
  const AudioFrame({
    required this.bytes,
    required this.ptsUs,
    this.sampleRate,
    this.channels,
  });

  /// Decodes a platform-channel map.
  factory AudioFrame.fromMap(Map<Object?, Object?> map) => AudioFrame(
    bytes: _bytes(map['bytes']),
    ptsUs: (map['ptsUs'] as num?)?.toInt() ?? 0,
    sampleRate: (map['sampleRate'] as num?)?.toInt(),
    channels: (map['channels'] as num?)?.toInt(),
  );

  /// Interleaved signed 16-bit little-endian PCM.
  final Uint8List bytes;

  /// Presentation timestamp in microseconds.
  final int ptsUs;

  /// Sample rate in Hz, when reported (iOS).
  final int? sampleRate;

  /// Channel count, when reported (iOS).
  final int? channels;
}
