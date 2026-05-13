---
description: Camera streaming with the texture path, video codecs, photo capture, and the opt-in videoFramesStream
globs: lib/**/*.dart, ios/**/MetaSessionManager.swift, android/**/MetaSessionManager.kt
---

# Camera Streaming (Flutter)

Guide for streaming video and capturing photos from Meta glasses via
the `meta_wearables_dat_flutter` plugin.

## Key concepts

- **`startStreamSession(...)`** — main entry point; returns a Flutter
  `textureId` that you wrap in a `Texture` widget.
- **`videoFramesStream`** — opt-in per-frame stream (raw BGRA on iOS,
  I420 on Android, or HEVC `hvc1` NAL bytes if `VideoCodec.hvc1`).
- **`capturePhoto`** — JPEG bytes from the glasses (works while
  streaming).

## Starting a stream

```dart
final textureId = await MetaWearablesDat.startStreamSession(
  fps: 24,
  resolution: VideoResolution.medium,  // 504x896
  videoCodec: VideoCodec.raw,          // or VideoCodec.hvc1 (iOS only for preview)
);
return Texture(textureId: textureId);
```

### Resolution options

| Resolution | Size       |
|-----------:|------------|
| `high`     | 720 x 1280 |
| `medium`   | 504 x 896  |
| `low`      | 360 x 640  |

### FPS options

`2`, `7`, `15`, `24`, `30`.

Lower resolution and FPS produce higher per-frame quality due to less
Bluetooth-classic compression.

## Observing state

```dart
MetaWearablesDat.streamSessionStateStream().listen((state) {
  // stopped | waitingForDevice | starting | streaming | paused
});
MetaWearablesDat.streamSessionErrorStream().listen((err) {
  if (err.isDeviceDisconnected) { /* show banner */ }
});
```

## Observing video size

```dart
MetaWearablesDat.videoStreamSizeStream().listen((size) {
  setState(() => _aspect = size.width / size.height);
});
```

## Opt-in per-frame stream

Use this for recording / ML / OCR. Don't subscribe if you only render
the texture — emission is gated on subscriber count.

```dart
final sub = MetaWearablesDat.videoFramesStream().listen((frame) {
  // frame.codec, frame.bytes, frame.width, frame.height,
  // frame.ptsUs, frame.isKeyframe
});
```

A 720x1280 raw frame is ~3.7 MB. At 24 fps that is ~90 MB/s — use HEVC
(`VideoCodec.hvc1`) for any sustained recording.

## Photo capture

```dart
final jpegBytes = await MetaWearablesDat.capturePhoto();
final image = Image.memory(jpegBytes);
```

You can call `capturePhoto()` while streaming.

## Background streaming

```dart
await MetaWearablesDat.enableBackgroundStreaming(
  androidNotification: const BackgroundNotification(
    title: 'Streaming',
    text: 'Meta glasses are recording',
    channelId: 'mwdat_streaming',
    channelName: 'Glass streaming',
  ),
);
// frames keep arriving when the screen locks
await MetaWearablesDat.disableBackgroundStreaming();
```

iOS requires the four background modes in `Info.plist`. Android
requests `POST_NOTIFICATIONS` at runtime and runs a foreground service.

## Device selection

```dart
// Auto-select (default)
await MetaWearablesDat.startStreamSession();

// Filter auto-select to a device kind
await MetaWearablesDat.startStreamSession(
  deviceKinds: {DeviceKind.raybanMeta, DeviceKind.oakleyMeta},
);

// Specific device
final devices = await MetaWearablesDat.getDevices();
await MetaWearablesDat.startStreamSession(
  deviceUUID: devices.first.uuid,
);
```

## Stopping

```dart
await MetaWearablesDat.stopStreamSession();
```

Always call this on dispose, otherwise the texture leaks GPU memory.

## Links

- [`doc/streaming.md`](../../doc/streaming.md)
- [`doc/frame_processing.md`](../../doc/frame_processing.md)
- Meta iOS `StreamSession`:
  <https://wearables.developer.meta.com/docs/reference/ios_swift/dat/0.6/mwdatcamera_streamsession>
