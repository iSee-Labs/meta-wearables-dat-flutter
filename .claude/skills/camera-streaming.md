---
description: Camera streaming with the texture path, StreamSessionConfig, video codecs, photo capture, background streaming, and the opt-in videoFramesStream (DAT 1.0)
globs: lib/**/*.dart, ios/**/MetaSessionManager.swift, ios/**/FramePump.swift, ios/**/VTDecompressionPipeline.swift, android/**/MetaSessionManager.kt, android/**/HevcSurfaceDecoder.kt
---

# Camera Streaming (Flutter, DAT 1.0)

Streaming video and capturing photos from Meta glasses via
`meta_wearables_dat_flutter` 1.0.

## Key concepts

- **`startStreamSession({deviceUUID, config})`** returns a Flutter
  `textureId` for `Texture(textureId:)`. Camera shares the device session
  with display and experimental capabilities (`DeviceSessionHub`).
- **`StreamSessionConfig`** replaces the legacy `fps`/`quality`/
  `videoCodec`/`deviceKinds` named args (deprecated).
- **`videoFramesStream()`** — opt-in per-frame stream, gated on
  subscribers.
- **`capturePhoto({format})`** → `PhotoResult` (`bytes`, `format`).

## Starting a stream

```dart
final textureId = await MetaWearablesDat.startStreamSession(
  config: const StreamSessionConfig(
    quality: StreamQuality.medium,      // default
    frameRate: StreamFrameRate.fps24,   // default
    videoCodec: VideoCodec.raw,         // or VideoCodec.hvc1
  ),
);
return Texture(textureId: textureId);
```

| `StreamQuality` | Size |
|---|---|
| `low` | 360 x 640 |
| `medium` | 504 x 896 |
| `high` | 720 x 1280 |

`StreamFrameRate`: `fps2`, `fps7`, `fps15`, `fps24`, `fps30`. Lower
resolution/FPS gives higher per-frame quality over Bluetooth.

Both platforms render `hvc1` to the texture (iOS
`VTDecompressionPipeline`, Android `HevcSurfaceDecoder`/MediaCodec).

## Observing state and errors

```dart
MetaWearablesDat.streamSessionStateStream().listen((s) {
  // stopped | waitingForDevice | starting | streaming | paused | stopping
});
MetaWearablesDat.cameraStateStream().listen((s) {
  // starting | started | stopping | stopped
});
MetaWearablesDat.streamErrorStream().listen((e) {
  switch (e.reason) {
    case StreamErrorCase.hingesClosed: askToOpen();
    case StreamErrorCase.thermalHot: coolDown();
    default: show(e.message);
  }
});
```

`streamSessionErrorStream()` is deprecated; use `streamErrorStream()`.
`startStreamSession` throws `DeviceSessionError`, `StreamError` or
`DatArgumentError`.

## Video size

`videoStreamSizeStream()` emits `VideoStreamSize` only when the size
changes (and replays the last value to new listeners).

## Opt-in per-frame stream

```dart
final sub = MetaWearablesDat.videoFramesStream().listen((f) {
  // raw:  f.pixelFormat (i420 | nv12 | bgra), f.planes, f.width, f.height
  // hvc1: f.bytes (Annex-B), f.isKeyframe, f.isCodecConfig
  // both: f.codec, f.ptsUs
});
```

720x1280 raw is ~1.4 MB (I420) / ~3.7 MB (BGRA) per frame. Prefer `hvc1`
for recording. Do not subscribe if you only render the texture.

`captureStreamFrame(textureId, {format: FrameFormat.rawRgba|rawStraightRgba|png})`
renders the current texture frame in Dart without native round trips.

## Photo capture

```dart
final photo = await MetaWearablesDat.capturePhoto(format: PhotoFormat.jpeg);
Image.memory(photo.bytes);
```

Requires a running stream; throws `CaptureError`. High-resolution
capture (`captureHighResPhoto`) is experimental — see
[experimental-modules.md](experimental-modules.md).

## Background streaming

```dart
await MetaWearablesDat.enableBackgroundStreaming(
  androidNotification: const BackgroundNotification(
    title: 'Streaming',
    text: 'Glasses camera is live',
    channelId: 'mwdat_streaming',
    channelName: 'Glasses streaming',
  ),
);
await MetaWearablesDat.disableBackgroundStreaming();
```

- iOS: the stream session ends on `didEnterBackground` unless
  background streaming is enabled. Raw frames pause in background
  (`StreamErrorCase.rawPausedInBackground`); `hvc1` continues.
- Android: foreground service (`BackgroundStreamingService`); request
  `POST_NOTIFICATIONS` first on Android 13+.

## Device selection

```dart
await MetaWearablesDat.startStreamSession(
  config: const StreamSessionConfig(deviceKinds: {DeviceKind.rayBanMeta}),
);
await MetaWearablesDat.startStreamSession(deviceUUID: devices.first.uuid);
```

## Stopping

`stopStreamSession()` unregisters the texture and releases the camera's
hold on the shared session. Always call it on dispose. Afterwards
`dumpDiagnostics().isIdle` should be true.

## Links

- [`doc/streaming.md`](../../doc/streaming.md)
- [`doc/frame_processing.md`](../../doc/frame_processing.md)
- Meta docs: <https://wearables.developer.meta.com/docs/develop/>
