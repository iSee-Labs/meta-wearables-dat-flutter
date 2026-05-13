---
description: Test the plugin without physical Meta glasses using the Mock Device Kit
globs: lib/**/*.dart, ios/**/MetaMockDeviceManager.swift, android/**/MetaMockDeviceManager.kt
---

# Mock Device Testing (Flutter)

Guide for testing `meta_wearables_dat_flutter` integrations without
physical Meta glasses.

## Overview

The Mock Device Kit simulates Meta glasses behavior so you can develop
without hardware. Backed by `MWDATMockDevice` on iOS and the equivalent
Android module.

## Enabling the Mock Kit

```dart
await MetaWearablesDat.enableMockDevice(
  initiallyRegistered: true,
  initialPermissionsGranted: true,
);
final enabled = await MetaWearablesDat.isMockDeviceEnabled();
```

Tear down at the end:

```dart
await MetaWearablesDat.disableMockDevice();
```

## Pairing a Ray-Ban Meta

```dart
final mock = await MetaWearablesDat.pairMockRaybanMeta();
print('Mock device uuid: ${mock.uuid}');

final paired = await MetaWearablesDat.pairedMockDevices();
```

## Simulating glasses lifecycle

```dart
await MetaWearablesDat.mockPowerOn(mock.uuid);
await MetaWearablesDat.mockUnfold(mock.uuid);
await MetaWearablesDat.mockDon(mock.uuid);

// later
await MetaWearablesDat.mockDoff(mock.uuid);
await MetaWearablesDat.mockFold(mock.uuid);
await MetaWearablesDat.mockPowerOff(mock.uuid);
```

## Configuring the mock camera feed

```dart
// Pass a local .mov / .mp4 path (h.265 / hevc supported on iOS)
await MetaWearablesDat.setMockCameraFeed(mock.uuid, '/path/to/video.mov');

// Clear:
await MetaWearablesDat.setMockCameraFeed(mock.uuid, null);
```

For photo capture:

```dart
await MetaWearablesDat.setMockCapturedImage(mock.uuid, '/path/to/image.jpg');
```

## Driving permission UX

```dart
await MetaWearablesDat.setMockPermission(
  MockPermission.camera,
  MockPermissionStatus.granted,
);
// What the next requestPermission() call returns:
await MetaWearablesDat.setMockPermissionRequestResult(
  MockPermission.camera,
  MockPermissionStatus.denied,
);
```

On Android the SDK currently does not expose this API — the plugin
logs a structured warning and resolves to `granted` so test harnesses
don't crash.

## Observing mock devices

```dart
MetaWearablesDat.mockDevicesStream().listen((devices) {
  // List<MockDeviceInfo> with linkState/donState/foldState
});
```

## Sample integration

`samples/camera_access/lib/src/mock_kit_screen.dart` wires every Mock
Kit method to a button. Use it as a reference.

## Supported media formats

| Type  | Formats |
|-------|---------|
| Video | h.265 (HEVC), .mov / .mp4 container |
| Image | JPEG, PNG |

## Links

- [`doc/mock_device.md`](../../doc/mock_device.md)
- Meta Mock Device Kit:
  <https://wearables.developer.meta.com/docs/mock-device-kit>
