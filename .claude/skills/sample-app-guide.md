---
description: Build a complete Flutter DAT 1.0 app modelled on samples/camera_access and samples/display_access - registration, streaming, photo and frame capture, recording, devices, mock-device debug menu, display tutorials
globs: example/**, samples/camera_access/**, samples/display_access/**, samples/glasses_companion/**
---

# Sample App Guide (Flutter, DAT 1.0)

References:

- [`samples/camera_access/`](../../samples/camera_access/) — registration,
  streaming, capture, recording, devices, Mock Device Kit menu.
- [`samples/display_access/`](../../samples/display_access/) — display
  sessions and step-by-step tutorial views.
- [`samples/glasses_companion/`](../../samples/glasses_companion/) — DAT 1.0
  features in one app: Meta-AI-initiated registration, diagnostics findings,
  device picker with live `deviceStateStream`, update deep links, Mock Device
  Kit controls (battery, thermal, charging, don, fold), hvc1 preview and
  high-res photo, a display card with `DisplayButtonGroup`, and the
  experimental inputs / motion / speech / voice modules.
- [`example/`](../../example/) — minimal end-to-end app; also hosts
  `integration_test/` and the Swift `RunnerTests`.

## Layout

```
samples/camera_access/lib/
├── main.dart
└── src/
    ├── app.dart              # registration + active device, shared via InheritedWidget
    ├── stream_screen.dart    # Texture, photo, captureStreamFrame, recording, errors
    ├── devices_screen.dart   # devicesStream + compatibilityStream
    ├── settings_sheet.dart   # quality / fps / codec / background
    └── mock_kit_screen.dart  # Mock Device Kit debug menu

samples/display_access/lib/
├── main.dart
└── src/
    ├── app.dart              # registration, display session lifecycle
    └── tutorials.dart        # DisplayView builders
```

Both samples use only the plugin (camera_access adds `path_provider`,
`share_plus`). Do not add dependencies to the plugin itself.

## App shell

```dart
class _AppState extends State<App> {
  RegistrationState _registration = RegistrationState.unavailable;
  DeviceInfo? _activeDevice;
  StreamSubscription<RegistrationState>? _regSub;
  StreamSubscription<DeviceInfo?>? _deviceSub;

  @override
  void initState() {
    super.initState();
    _regSub = MetaWearablesDat.registrationStateStream().listen(
        (s) { if (mounted) setState(() => _registration = s); });
    _deviceSub = MetaWearablesDat.activeDeviceStream().listen(
        (d) { if (mounted) setState(() => _activeDevice = d); });
  }

  @override
  void dispose() {
    _regSub?.cancel();
    _deviceSub?.cancel();
    super.dispose();
  }
}
```

Register with `requestAndroidPermissions()` then `startRegistration()`;
request `Permission.camera` via `requestPermission` before streaming.

## Streaming

```dart
final id = await MetaWearablesDat.startStreamSession(
  deviceUUID: devices.isNotEmpty ? devices.first.uuid : null,
  config: StreamSessionConfig(
    quality: settings.quality,
    frameRate: StreamFrameRate.values.firstWhere((r) => r.value == settings.fps),
    videoCodec: settings.codec,
  ),
);
// Texture(textureId: id)
```

Listen to `streamSessionStateStream()`, `streamErrorStream()`,
`deviceSessionErrorStream()` and `videoStreamSizeStream()`. Act on
`error.recoveryAction` (e.g. `openFirmwareUpdate()`,
`openDatGlassesAppUpdate()`). Always `stopStreamSession()` in `dispose`.

## Capture

```dart
final photo = await MetaWearablesDat.capturePhoto();          // PhotoResult
final frame = await MetaWearablesDat.captureStreamFrame(id,   // FrameData?
    format: FrameFormat.png);
```

## Recording

```dart
_framesSub = MetaWearablesDat.videoFramesStream().listen((frame) {
  _sink?.add(frame.bytes);
});
// stop: await _framesSub?.cancel(); await _sink?.close();
```

With `VideoCodec.hvc1` the bytes are Annex-B HEVC (first frame has
`isCodecConfig`); with `raw` use `frame.planes` / `pixelFormat`. Muxing to
MP4 is the app's job.

## Mock Device Kit menu

```dart
await MetaWearablesDat.enableMockDevice();
final mock = await MetaWearablesDat.pairMockGlasses(MockGlassesModel.rayBanMeta);
await MetaWearablesDat.mockPowerOn(mock.uuid);
await MetaWearablesDat.mockUnfold(mock.uuid);
await MetaWearablesDat.mockDon(mock.uuid);
```

One button per action; list devices with `mockDevicesStream()`.

## Display sample

```dart
await MetaWearablesDat.startDisplaySession();
MetaWearablesDat.displayStateStream().listen(onState); // Back gesture -> stopped
await MetaWearablesDat.sendDisplayView(tutorialStep(i));
await MetaWearablesDat.stopDisplaySession();
```

## Companion sample

- `lib/src/selection.dart`: one `ValueNotifier<String?>` holds the picked
  device; `null` means automatic selection.
- `lib/src/mock_setup.dart`: enable kit, `pairMockGlasses(model)`, power on,
  unfold, don, then `setMockCameraFeed` with the bundled H.265 asset.
- Experimental calls live in `lab_tab.dart` and `camera_tab.dart` behind
  `// ignore_for_file: experimental_member_use` with a reason comment.
- Treat `StreamSessionState.stopped` as "texture released": drop the texture
  id when the device ends the stream.

## Build checks

```bash
cd samples/camera_access && flutter analyze --fatal-infos
cd samples/display_access && flutter analyze --fatal-infos
cd samples/glasses_companion && flutter analyze --fatal-infos
```

CI builds all three samples for iOS simulator and Android debug.
