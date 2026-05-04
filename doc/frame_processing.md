# Frame processing

Two ways to grab still imagery from a running stream.

## `capturePhoto()` — high-resolution still

Triggers the device's actual photo capture path (full sensor
resolution). Available formats: `PhotoFormat.jpeg` (always) and
`PhotoFormat.heic` (iOS, recent Android devices).

```dart
final photo = await MetaWearablesDat.capturePhoto(
  format: PhotoFormat.jpeg,
);
print('Got ${photo.bytes.length} bytes (${photo.format.name})');
```

The returned `format` reflects what the device chose, which can differ
from the requested format on Android.

Notes:

- One capture in flight at a time. Subsequent calls fail with
  `CaptureError(ALREADY_REQUESTING)` until the previous one resolves.
- Captures interleave naturally with the live preview.
- On iOS the capture flows back via the SDK's `photoDataPublisher`; the
  plugin owns a single-slot continuation that resumes on the next
  emitted `PhotoData`.

## `captureStreamFrame(textureId)` — Dart-side snapshot

Pure-Dart RGBA / PNG snapshot of whatever frame is currently rendered
into the Flutter texture. Slow path: allocates a `ui.Image` per call.
Suitable for OCR / ML inference / screenshots at ~2-5 Hz, **not** for
every-frame consumption.

```dart
final frame = await MetaWearablesDat.captureStreamFrame(
  textureId,
  format: FrameFormat.rawRgba,
);
print('Frame: ${frame!.width}x${frame.height}');
```

The plugin caches the latest `VideoStreamSize` from
`videoStreamSizeStream`; you don't need to pass dimensions explicitly.
Falls back to 1280x720 if no size has been observed yet.

## Choosing between the two

| Need                           | Use                  |
| ------------------------------ | -------------------- |
| Highest possible resolution    | `capturePhoto`       |
| Saving photos to gallery       | `capturePhoto`       |
| OCR / ML on live frames        | `captureStreamFrame` |
| Single-frame screenshot of UI  | `captureStreamFrame` |

A future `videoFramesStream()` API (planned for v0.2) will expose every
decoded frame for true real-time processing.
