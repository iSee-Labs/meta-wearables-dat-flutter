# Frame processing

The texture preview is free: frames go straight to the Flutter texture
registry and never cross a platform channel. When you need the pixels
or the encoded video yourself, pick one of these:

| Need | Use | Cost |
| --- | --- | --- |
| Every frame (ML, recording, forwarding) | `videoFramesStream()` | One copy per frame across the channel |
| An occasional snapshot of the preview (OCR, thumbnails) | `captureStreamFrame(textureId)` | One GPU readback per call, no native round-trip |
| A real photo from the glasses camera | `capturePhoto()` ([Streaming](streaming.md#photo-capture)) | One capture |
| Full-resolution photo | `captureHighResPhoto()` ([experimental](experimental.md#high-resolution-photos)) | One capture plus transfer |
| Microphone audio with the stream | `audioFramesStream()` ([experimental](#audioframesstream-experimental)) | PCM chunks |

## `videoFramesStream()`

Opt-in stream of every frame of the running stream session.

- **Gated on subscribers.** While nobody listens, the native side does
  not copy or send anything. Cancel your subscription as soon as you no
  longer need frames.
- **Backpressure-safe.** Pausing or cancelling the Dart subscription
  stops native emission.
- Subscribe before or after `startStreamSession`; frames flow while
  both are active.

```dart
final subscription = MetaWearablesDat.videoFramesStream().listen((frame) {
  switch (frame.codec) {
    case VideoCodec.raw:
      processPixels(frame);
    case VideoCodec.hvc1:
      if (!frame.isCodecConfig) writeNalUnits(frame.bytes);
  }
});

// Later:
await subscription.cancel();
```

### Cost

| Format at 720 x 1280 | Per frame | At 30 fps |
| --- | --- | --- |
| I420 or NV12 (raw) | about 1.4 MB | about 41 MB/s |
| BGRA (raw) | about 3.7 MB | about 110 MB/s |
| H.265 (hvc1) | a few KB to tens of KB | a small fraction of raw |

Use the lowest `StreamQuality` and `StreamFrameRate` your processing
needs. For ML, `StreamQuality.low` at `fps7` or `fps15` is usually
enough. For recording or forwarding, prefer `hvc1`. Write to disk
inside the listener instead of buffering frames in memory.

### `VideoFrame` fields

| Field | Meaning |
| --- | --- |
| `codec` | `VideoCodec.raw` or `VideoCodec.hvc1` |
| `bytes` | Raw: pixel data (see below). hvc1: Annex-B H.265 |
| `width`, `height` | Frame size |
| `ptsUs` | Presentation timestamp, microseconds |
| `isKeyframe` | hvc1: whether this is an IDR/keyframe. Always `true` for raw |
| `isCodecConfig` | hvc1: the frame carries only parameter sets (VPS/SPS/PPS) |
| `pixelFormat` | Raw: `i420`, `nv12`, `bgra`; `unknown` for hvc1 |
| `bytesPerRow` | Raw: row stride of `bytes`, when single-plane |
| `planes` | Raw: per-plane `VideoFramePlane` (`bytes`, `bytesPerRow`, `width`, `height`) for planar formats |

### Raw frames per platform

| Platform | `pixelFormat` | Layout |
| --- | --- | --- |
| Android | `i420` | Tightly packed Y, U, V in `bytes` (`width * height * 3 / 2`), `bytesPerRow == width`, `planes` empty |
| iOS | `nv12` | Bi-planar: `planes[0]` is Y, `planes[1]` is interleaved CbCr, each with its own `bytesPerRow`. `bytes` holds the planes concatenated |
| iOS | `bgra` | Single plane in `bytes` with `bytesPerRow` |

Always read `pixelFormat` and the strides instead of assuming a layout:

```dart
void processPixels(VideoFrame frame) {
  switch (frame.pixelFormat) {
    case VideoPixelFormat.i420:
      final ySize = frame.width * frame.height;
      final y = frame.bytes.sublist(0, ySize);
      runModelOnLuma(y, frame.width, frame.height);
    case VideoPixelFormat.nv12:
      final yPlane = frame.planes[0];
      runModelOnLuma(yPlane.bytes, yPlane.width, yPlane.height,
          stride: yPlane.bytesPerRow);
    case VideoPixelFormat.bgra:
      runModelOnBgra(frame.bytes, frame.width, frame.height,
          stride: frame.bytesPerRow ?? frame.width * 4);
    case VideoPixelFormat.unknown:
      break;
  }
}
```

(`runModelOnLuma` and `runModelOnBgra` stand for your own code.)

On iOS, raw frames pause while the app is in the background, even with
background streaming enabled.

### hvc1 frames (Annex-B)

With `VideoCodec.hvc1`, `bytes` is H.265 in **Annex-B** form (NAL units
with `00 00 00 01` or `00 00 01` start codes), ready for a muxer, a network stream or
a decoder that accepts Annex-B.

- iOS: the VPS/SPS/PPS parameter sets are prepended to every keyframe;
  `isCodecConfig` is always `false`.
- Android: frames are passed through as the SDK delivers them. A frame
  with `isCodecConfig == true` carries only the parameter sets; keep it
  and feed it before the next keyframe.
- Start writing or decoding at the first frame with `isKeyframe == true`
  (after the parameter sets).

## `captureStreamFrame`

Renders the current texture into an image in Dart, without a native
round-trip. Suitable for a few snapshots per second, not for every
frame.

```dart
final frame = await MetaWearablesDat.captureStreamFrame(
  textureId,
  format: FrameFormat.png, // or rawRgba (default) / rawStraightRgba
);
if (frame != null) {
  // frame.bytes, frame.width, frame.height, frame.format
}
```

- Returns `null` when no frame size is known within one second (for
  example before the first frame).
- Throws `CaptureError` (`captureFailed`) if the image could not be
  read back.
- The size comes from `videoStreamSizeStream()`, so it follows the
  SDK's bandwidth adaptation.

## `audioFramesStream` (experimental)

Experimental PCM audio from the glasses microphone, delivered with the
video. It is not beamformed. Enable it in the stream config:

```dart
// Experimental: see doc/experimental.md about the analyzer warning.
final textureId = await MetaWearablesDat.startStreamSession(
  config: const StreamSessionConfig(
    audio: AudioStreamConfig(sampleRate: AudioSampleRate.hz16000),
  ),
);
final audio = MetaWearablesDat.audioFramesStream().listen((chunk) {
  // chunk.bytes (PCM), chunk.ptsUs, chunk.sampleRate, chunk.channels
});
```

Failures arrive on `streamErrorStream()` as
`StreamErrorCase.audioStreamingError`. Apps that use it cannot ship to
production release channels; see [Experimental APIs](experimental.md).
