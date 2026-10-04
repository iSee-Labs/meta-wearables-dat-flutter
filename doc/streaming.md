# Streaming

The glasses camera streams into a Flutter `Texture`. Decoded frames
never cross the method channel: iOS hands pixel buffers to the Flutter
texture registry, Android draws into a `SurfaceTexture`. Per-frame data
for your own processing is opt-in, see
[Frame processing](frame_processing.md).

## Before you start

1. The app is registered (`RegistrationState.registered`), see
   [Registration](registration_flow.md).
2. `Permission.camera` is granted.
3. Glasses are connected, unfolded and worn. Check with
   [`deviceStateStream`](device_state.md).

## Start and stop

```dart
final textureId = await MetaWearablesDat.startStreamSession(
  config: const StreamSessionConfig(
    quality: StreamQuality.medium,
    frameRate: StreamFrameRate.fps24,
    videoCodec: VideoCodec.raw,
  ),
);

// In build():
AspectRatio(
  aspectRatio: StreamQuality.medium.width / StreamQuality.medium.height,
  child: Texture(textureId: textureId),
);

// When the screen goes away:
await MetaWearablesDat.stopStreamSession();
```

- `startStreamSession` picks the best connected, worn device. Pass
  `deviceUUID:` to target one, or `StreamSessionConfig(deviceKinds: {DeviceKind.rayBanMeta})`
  to restrict the device family.
- The legacy named arguments `fps:`, `quality:`, `videoCodec:` and
  `deviceKinds:` still work but are deprecated; use `config:`.
- Use `videoStreamSizeStream()` for the real frame size. It emits only
  when the size changes (the SDK lowers resolution under poor
  bandwidth).

## `StreamSessionConfig`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `quality` | `StreamQuality` | `medium` | See the resolution table |
| `frameRate` | `StreamFrameRate` | `fps24` | 2, 7, 15, 24 or 30 fps |
| `videoCodec` | `VideoCodec` | `raw` | `raw` or `hvc1` |
| `deviceKinds` | `Set<DeviceKind>?` | `null` (any) | `rayBanMeta`, `rayBanDisplay`, `oakleyMeta`, `metaGlasses` |
| `audio` | `AudioStreamConfig?` | `null` | Experimental in-stream audio, see [Experimental APIs](experimental.md#in-stream-audio) |

| `StreamQuality` | Size (portrait) |
| --- | --- |
| `low` | 360 x 640 |
| `medium` | 504 x 896 |
| `high` | 720 x 1280 |

| `StreamFrameRate` | fps |
| --- | --- |
| `fps2` | 2 |
| `fps7` | 7 |
| `fps15` | 15 |
| `fps24` | 24 (SDK default) |
| `fps30` | 30 |

Under limited bandwidth the SDK lowers resolution first, then frame
rate, but not below 15 fps. Your requested values are an upper bound.

## `raw` vs `hvc1`

| | `VideoCodec.raw` | `VideoCodec.hvc1` |
| --- | --- | --- |
| What the glasses send | Uncompressed frames | H.265 (HEVC) |
| Texture preview | Yes | Yes on both platforms (iOS VideoToolbox, Android MediaCodec) |
| `videoFramesStream()` payload | Pixel planes (`i420`, `nv12` or `bgra`) | Annex-B H.265 bytes |
| iOS background | Frames **pause** | Keeps streaming |
| Use for | Preview, per-frame ML on pixels | Background streaming, recording or forwarding without re-encoding |

On Android, `hvc1` preview needs a hardware HEVC decoder. Without one
the preview stays empty and `streamErrorStream()` reports
`StreamErrorCase.hevcDecoderUnavailable`.

## Texture lifecycle

- Each `startStreamSession` registers one texture. `stopStreamSession`
  unregisters it and releases its GPU memory. Always stop the stream in
  `dispose()` or when the user leaves the screen.
- When the stream ends on its own (glasses folded, thermal shutdown,
  disconnect), the plugin releases the texture too. Do not reuse an old
  `textureId` after `streamSessionStateStream()` reports `stopped`;
  start a new session.
- `dumpDiagnostics().resources` counts textures, decoders and sessions.
  All counters must return to `0` after `stopStreamSession()`
  (`DatDiagnostics.isIdle`). The integration tests assert this.

```dart
await MetaWearablesDat.stopStreamSession();
final diagnostics = await MetaWearablesDat.dumpDiagnostics();
assert(diagnostics.resources['textures'] == 0);
```

## State streams

All state streams emit the current value first, then changes.

| Stream | Values |
| --- | --- |
| `streamSessionStateStream()` | `StreamSessionState`: `stopped`, `waitingForDevice` (iOS), `starting`, `streaming`, `paused`, `stopping` |
| `cameraStateStream()` | `CameraState`: `starting`, `started`, `stopping`, `stopped` |
| `deviceSessionStateStream()` | `DeviceSessionState`: `idle`, `starting`, `started`, `paused`, `stopping`, `stopped` |
| `videoStreamSizeStream()` | `VideoStreamSize` (`width`, `height`, `aspectRatio`) |

`paused` means the glasses paused the stream: the user tapped the
touchpad (captouch) or took the glasses off. The stream resumes on its
own when the user taps again or puts them back on. There is no
pause/resume API; `pauseStreamSession` and `resumeStreamSession` were
removed in 1.0 because they never did anything.

Folding the glasses (closing the hinges) ends the stream:
`StreamErrorCase.hingesClosed`, then `stopped`.

## Error handling

`startStreamSession` throws a `DeviceSessionError`, `StreamError` or
`DatArgumentError`. While streaming, problems arrive on
`streamErrorStream()` and `deviceSessionErrorStream()`. Every `DatError`
carries a typed `reason` (via its subclass), `code`, `category`,
`message`, `platformCase` and a suggested `recoveryAction`.

```dart
Future<int?> startPreview() async {
  try {
    return await MetaWearablesDat.startStreamSession(
      config: const StreamSessionConfig(quality: StreamQuality.high),
    );
  } on DeviceSessionError catch (e) {
    if (e.isTerminal) {
      // insufficientSDKVersion: this app build is too old for the glasses.
      showMessage('Please update this app.');
    } else {
      await recover(e);
    }
  } on StreamError catch (e) {
    await recover(e);
  }
  return null;
}

void watchStreamErrors() {
  MetaWearablesDat.streamErrorStream().listen((error) {
    if (error.isWarning) {
      // Informational, the stream keeps running
      // (for example rawPausedInBackground).
      return;
    }
    switch (error) {
      case StreamError(reason: StreamErrorCase.hingesClosed):
        showMessage('Unfold your glasses to continue.');
      case StreamError(reason: StreamErrorCase.thermalHot):
        showMessage('Your glasses are too warm. Try again later.');
      case StreamError(reason: StreamErrorCase.batteryLow):
        showMessage('Charge your glasses to stream.');
      case StreamError(reason: StreamErrorCase.permissionDenied):
        showMessage('Allow camera access in the Meta AI app.');
      default:
        showMessage(error.message);
    }
  });
}

Future<void> recover(DatError error) async {
  switch (error.recoveryAction) {
    case DatRecoveryAction.openFirmwareUpdate:
      await MetaWearablesDat.openFirmwareUpdate();
    case DatRecoveryAction.openDatGlassesAppUpdate:
      await MetaWearablesDat.openDatGlassesAppUpdate();
    case DatRecoveryAction.updateHostApp:
      showMessage('Please update this app.');
    case DatRecoveryAction.suggestUpdate:
      // Non-blocking: keep going, suggest an update occasionally.
      break;
    case DatRecoveryAction.checkMetaAiAndRetry:
      showMessage('Check your glasses in the Meta AI app, then retry.');
    case DatRecoveryAction.connectGlasses:
      showMessage('Turn on, unfold and wear your glasses, then retry.');
    case DatRecoveryAction.grantPermission:
      await MetaWearablesDat.requestPermission(Permission.camera);
    case DatRecoveryAction.none:
      showMessage(error.message);
  }
}
```

(`showMessage` stands for your own UI.)

### Common stream errors

| `StreamErrorCase` | Meaning | What to do |
| --- | --- | --- |
| `hingesClosed` | Glasses folded | Ask the user to unfold, then start a new session |
| `thermalHot` | Glasses too hot | Stop, wait, lower quality/fps on restart (see [Device state](device_state.md#thermal)) |
| `batteryLow` | Battery too low | Ask the user to charge |
| `peakPowerLimit` | Power limit reached | Lower quality/fps |
| `permissionDenied` | Camera permission revoked | `requestPermission(Permission.camera)` |
| `deviceNotConnected`, `deviceNotFound` | Glasses gone | Reconnect, retry |
| `timeout`, `stoppedBeforeStart` | Start did not complete | Retry once; check device state |
| `videoStreamingError` | Stream failed; on Android `isFatal` means it stopped | Restart the session |
| `hevcDecoderUnavailable` | Android has no HEVC decoder | Use `VideoCodec.raw` |
| `rawPausedInBackground` (warning) | iOS raw frames pause in background | Use `hvc1` for background |
| `stoppedInBackground` (warning) | iOS stopped the stream on backgrounding | Call `enableBackgroundStreaming()` before backgrounding |

Device session errors (`insufficientSDKVersion`,
`datAppOnTheGlassesUpdateRequired`, `dwaOutOfStuRange`, thermal and
battery cases) are covered in [Device state](device_state.md#update-flows).
The full list per category is in [Troubleshooting](troubleshooting.md#errors-by-category).

## Photo capture

`capturePhoto` captures a still from the running stream.

```dart
try {
  final photo = await MetaWearablesDat.capturePhoto(format: PhotoFormat.heic);
  // photo.bytes, photo.format
} on CaptureError catch (e) {
  switch (e.reason) {
    case CaptureErrorCase.notStreaming:
      // Start a stream first.
      break;
    case CaptureErrorCase.captureInProgress:
      // One capture at a time.
      break;
    default:
      debugPrint('capture failed: $e');
  }
}
```

- Formats: `PhotoFormat.jpeg` (default) and `PhotoFormat.heic`. Read
  `photo.format` for what was actually returned.
- One capture at a time; a second call fails with `captureInProgress`.
- A capture fails with `sessionStopped` or `deviceDisconnected` if the
  stream ends meanwhile.
- For a full-resolution photo (up to 4032 x 3024) there is the
  experimental [`captureHighResPhoto`](experimental.md#high-resolution-photos).
- For a cheap snapshot of the current preview frame use
  [`captureStreamFrame`](frame_processing.md#capturestreamframe).

## Background streaming

| Platform | Without `enableBackgroundStreaming()` | With it |
| --- | --- | --- |
| iOS | The stream is **stopped** when the app enters the background (`stoppedInBackground` warning, then `stopped`) | The stream keeps running. `hvc1` keeps delivering frames; `raw` frames **pause** until the app returns (`rawPausedInBackground` warning) |
| Android | No foreground service; the system may stop or kill the app while it is in the background | A `connectedDevice` foreground service with a notification keeps the process alive |

```dart
// Android 13+: request POST_NOTIFICATIONS yourself first (for example with
// the permission_handler package). Without it the service still runs but
// its notification is hidden.
await MetaWearablesDat.enableBackgroundStreaming(
  androidNotification: const BackgroundNotification(
    title: 'My Glasses App',
    text: 'Streaming from your glasses',
    channelId: 'glasses_streaming',
    channelName: 'Glasses streaming',
  ),
);

final textureId = await MetaWearablesDat.startStreamSession(
  config: const StreamSessionConfig(videoCodec: VideoCodec.hvc1),
);

// Later:
await MetaWearablesDat.stopStreamSession();
await MetaWearablesDat.disableBackgroundStreaming();
```

iOS requirements:

- `audio` in `UIBackgroundModes` (the plugin keeps an audio session
  alive) plus the required `bluetooth-central` and `external-accessory`
  modes, and `NSMicrophoneUsageDescription`.
- Call `enableBackgroundStreaming()` **before** `startStreamSession()`:
  it switches the hvc1 decoder to a software decoder that survives
  backgrounding, and only new sessions pick that up.
- Use `VideoCodec.hvc1` if frames must keep flowing.

Android requirements: the plugin merges the service and its
permissions. Request `POST_NOTIFICATIONS` on Android 13+ (diagnostics
reports `postNotificationsNotGranted` otherwise).

## Sharing the device session with display and other capabilities

One `DeviceSession` per device is shared by the camera, the
[display](display_access.md) and the [experimental](experimental.md)
capabilities.

- Starting a stream while a display session runs on the same glasses
  reuses the open session.
- `stopStreamSession()` stops the camera and closes the device session
  only when nothing else uses it. The same applies to
  `stopDisplaySession()` and the experimental `stop*` calls.
- `getSessionDevice()` returns the device of the open session, or
  `null`.
- Device-level failures (thermal, battery, update required) arrive once
  on `deviceSessionErrorStream()` and affect every capability.

## See also

- [Frame processing](frame_processing.md): `videoFramesStream`, Annex-B,
  `captureStreamFrame`.
- [Device state](device_state.md): battery, thermal, wear and hinge.
- Sample: [`samples/camera_access/`](../samples/camera_access/).
