---
description: Test without physical glasses using Mock Device Kit 1.0 - pairMockGlasses models, device state simulation, camera feeds, permissions, experimental simulators, test server, and integration tests
globs: lib/**/*.dart, ios/**/MetaMockDeviceManager.swift, android/**/MetaMockDeviceManager.kt, example/integration_test/**
---

# Mock Device Testing (Flutter, DAT 1.0)

Backed by `MWDATMockDevice` (iOS) and `mwdat-mockdevice` (Android). Dev
and test only; disable before shipping.

## Enable

```dart
await MetaWearablesDat.enableMockDevice(
  initiallyRegistered: true,
  initialPermissionsGranted: true,
);
// ...
await MetaWearablesDat.disableMockDevice();
```

## Pair and bring online

```dart
final mock = await MetaWearablesDat.pairMockGlasses(MockGlassesModel.rayBanMeta);
await MetaWearablesDat.mockPowerOn(mock.uuid);
await MetaWearablesDat.mockUnfold(mock.uuid);
await MetaWearablesDat.mockDon(mock.uuid);
```

- `MockGlassesModel`: `rayBanMeta`, `rayBanMetaOptics`, `oakleyMetaHSTN`,
  `oakleyMetaVanguard`, `metaGlasses`, `metaRayBanDisplay`.
- The device appears in `devicesStream()` only after **powerOn +
  unfold**. Max 3 mock devices.
- `pairMockRayBanMeta()` is deprecated.
- `pairedMockDevices()`, `unpairMockDevice(uuid)`,
  `mockDevicesStream()` (`List<DeviceInfo>`, `isMock == true`).

## Device state

`mockPowerOn/Off`, `mockDon/Doff`, `mockFold/Unfold`, `mockTap`,
`mockTapAndHold`, `setMockBatteryLevel(uuid, 0..100 | null)`,
`setMockChargingState(uuid, ChargingState)`,
`setMockThermalLevel(uuid, ThermalLevel)`. Observe with
`deviceStateStream(uuid)`.

## Camera

```dart
await MetaWearablesDat.setMockCameraFeed(mock.uuid, '/path/feed.mp4'); // H.265
await MetaWearablesDat.setMockCapturedImage(mock.uuid, '/path/photo.jpg');
await MetaWearablesDat.setMockCameraFacing(mock.uuid, CameraFacing.back);
```

Experimental: `setMockCapturedPhoto`, `simulateMockCaptureFailure`.

## Permissions

```dart
await MetaWearablesDat.setMockPermission(Permission.camera, PermissionStatus.granted);
await MetaWearablesDat.setMockPermissionRequestResult(
    Permission.camera, PermissionStatus.denied);
```

Works on both platforms. `MockPermission` / `MockPermissionStatus` are
deprecated typedefs.

## Experimental simulators

- Inputs: `mockInputNav(uuid, NavDirection)`, `mockInputSelect`,
  `mockInputBack`, `mockInputCapture({pressType})`, `mockInputButton`,
  `mockInputDrag({action, x, y})`.
- Speech: `setMockSpeechSource(uuid, MockSpeechSource.injected|liveDeviceAsr)`,
  `simulateMockTranscription(uuid, text, {isFinal, confidence})`,
  `simulateMockSpeechError`, `simulateMockSpeechCompletion`.
- Motion: `setMockMotionFeed(uuid, {samples, filePath, loop})`.
- Voice: `simulateMockVoiceInvocation(uuid, {incomplete})`.

## Display test server

```dart
final port = await MetaWearablesDat.startMockTestServer(); // 9000
// Open the "Meta Ray-Ban Display Simulator" preview in Chrome.
// Android: adb forward tcp:9000 tcp:9000
await MetaWearablesDat.stopMockTestServer();
```

`sendMockDisplayClick(uuid, identifier)` returns true but may not fire
`onClick` (identifier format undocumented by Meta).

## Integration tests

`example/integration_test/plugin_test.dart` (helpers in
`mock_harness.dart`) runs the Mock Device Kit suite:

```bash
cd example && flutter test integration_test/plugin_test.dart -d <device>
```

8 tests, green on iOS Simulator (iOS 18 works) and Android emulator.
They assert that `dumpDiagnostics().resources` (textures,
deviceSessions) returns to zero after stop; new tests should do the same.

## Links

- [`doc/mock_device.md`](../../doc/mock_device.md)
- Sample UI: `samples/camera_access/lib/src/mock_kit_screen.dart`
