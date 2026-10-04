# Mock Device Kit

Mock Device Kit simulates glasses so you can develop and test
registration, permissions, streaming, display and the experimental
capabilities on an iOS Simulator, an Android emulator or a phone without
glasses. It wraps `MWDATMockDevice` (iOS) and `mwdat-mockdevice`
(Android). Disable it before you ship.

## Quick start

```dart
await MetaWearablesDat.enableMockDevice(
  initiallyRegistered: true,       // skip the Meta AI registration flow
  initialPermissionsGranted: true, // camera and microphone granted
);

final glasses = await MetaWearablesDat.pairMockGlasses(); // rayBanMeta by default
await MetaWearablesDat.mockPowerOn(glasses.uuid);
await MetaWearablesDat.mockUnfold(glasses.uuid);
await MetaWearablesDat.mockDon(glasses.uuid);

// The glasses now appear in getDevices() / devicesStream().
```

A mock device appears in `getDevices()` and `devicesStream()` only after
**`mockPowerOn` and `mockUnfold`**. Streams also need it worn
(`mockDon`). Wait for the device to show up before you start a session
(the integration harness polls `getDevices()`).

Tear down:

```dart
await MetaWearablesDat.stopStreamSession();
await MetaWearablesDat.unpairMockDevice(glasses.uuid);
await MetaWearablesDat.disableMockDevice();
```

`disableMockDevice()` also stops any running session.
`isMockDeviceEnabled()` tells you the current state.

## Models

`pairMockGlasses([MockGlassesModel model])` returns a `DeviceInfo` with
`isMock == true`. You can pair up to **three** mock devices at a time.

| `MockGlassesModel` | Notes |
| --- | --- |
| `rayBanMeta` | Default |
| `rayBanMetaOptics` | |
| `oakleyMetaHSTN` | |
| `oakleyMetaVanguard` | |
| `metaGlasses` | |
| `metaRayBanDisplay` | `supportsDisplay == true`; use for [display](display_access.md) and Inputs |

`pairMockRayBanMeta()` still works but is deprecated; use
`pairMockGlasses(MockGlassesModel.rayBanMeta)`.

`pairedMockDevices()` returns the paired mock devices and
`mockDevicesStream()` emits the full list on every change.

## Device state

| Call | Effect |
| --- | --- |
| `mockPowerOn(uuid)` / `mockPowerOff(uuid)` | Power |
| `mockUnfold(uuid)` / `mockFold(uuid)` | Hinges. Folding ends running sessions (`StreamErrorCase.hingesClosed`) |
| `mockDon(uuid)` / `mockDoff(uuid)` | Worn or not |
| `mockTap(uuid)` | Touchpad tap: pauses or resumes the stream |
| `mockTapAndHold(uuid)` | Touchpad tap-and-hold |
| `setMockBatteryLevel(uuid, level)` | 0-100, or `null` for unknown. Out-of-range values throw `DatArgumentError` |
| `setMockChargingState(uuid, ChargingState.charging)` | Charging state |
| `setMockThermalLevel(uuid, ThermalLevel.severe)` | Thermal level |

Changes show up on [`deviceStateStream(uuid)`](device_state.md):

```dart
final hot = MetaWearablesDat.deviceStateStream(glasses.uuid)
    .firstWhere((d) => d.thermalLevel == ThermalLevel.severe);
await MetaWearablesDat.setMockThermalLevel(glasses.uuid, ThermalLevel.severe);
assert((await hot).thermalLevel.isThrottling);
```

## Camera feed and photos

The mock camera is empty until you give it a source:

| Call | Source |
| --- | --- |
| `setMockCameraFeed(uuid, filePath)` | An **H.265 (HEVC)** video file, for example an `.mp4` with an HEVC track |
| `setMockCameraFacing(uuid, CameraFacing.front)` | The phone camera (`front` or `back`); needs your app's own camera permission (`NSCameraUsageDescription` on iOS) |
| `setMockCapturedImage(uuid, filePath)` | The image `capturePhoto()` returns |
| `setMockCapturedPhoto(uuid, filePath)` | The image experimental `captureHighResPhoto()` returns |
| `simulateMockCaptureFailure(uuid)` | Makes the next `captureHighResPhoto()` fail (experimental) |

Paths must be files on the device. To use bundled assets, copy them to a
temporary file first:

```dart
import 'dart:io';

import 'package:flutter/services.dart';

Future<String> assetToFile(String asset) async {
  final data = await rootBundle.load(asset);
  final file = File('${Directory.systemTemp.path}/${asset.split('/').last}');
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  return file.path;
}

await MetaWearablesDat.setMockCameraFeed(
  glasses.uuid,
  await assetToFile('assets/mock/mock_feed_h265.mp4'),
);
```

The example app ships `example/assets/mock/mock_feed_h265.mp4`,
`mock_photo.jpg` and `mock_photo.png`.

## Permissions

```dart
await MetaWearablesDat.setMockPermission(
  Permission.camera,
  PermissionStatus.denied,
);
// checkPermissionStatus(Permission.camera) now returns denied.

await MetaWearablesDat.setMockPermissionRequestResult(
  Permission.camera,
  PermissionStatus.granted,
);
// The next requestPermission(Permission.camera) returns granted.
```

## Input, speech, motion and voice simulators

These drive the [experimental capabilities](experimental.md) and are
themselves `@experimental`.

| Call | Simulates |
| --- | --- |
| `mockInputNav(uuid, NavDirection.left, source: InputSource.captouch)` | Navigation |
| `mockInputSelect(uuid)` / `mockInputBack(uuid)` | Select / Back |
| `mockInputCapture(uuid, pressType: CapturePressType.hold)` | Capture button |
| `mockInputButton(uuid)` | Action button |
| `mockInputDrag(uuid, action: DragAction.move, x:, y:, dx:, dy:)` | Meta Neural Band drag |
| `setMockSpeechSource(uuid, MockSpeechSource.injected)` | Use injected text (`liveDeviceAsr` uses the device recogniser) |
| `simulateMockTranscription(uuid, 'text', isFinal: true, confidence: 1)` | A transcription |
| `simulateMockSpeechError(uuid, errorCode:, message:)` | A speech error |
| `simulateMockSpeechCompletion(uuid)` | End of the speech session |
| `setMockMotionFeed(uuid, samples: [...], filePath:, loop: true)` | Motion samples, from a list or a CSV file |
| `simulateMockVoiceInvocation(uuid, incomplete: false)` | "Hey Meta, open <app>" |

Timing notes from the integration tests:

- The speech mock accepts injected transcriptions only once its
  recogniser is listening, which can trail `SpeechState.started`
  slightly. Retry the injection until a transcription arrives.
- The voice channel connects asynchronously after
  `startVoiceInvocations()`; `simulateMockVoiceInvocation` returns
  `null` until a client is connected. Retry it.

## Display preview (test server)

`startMockTestServer({int port = 9000})` serves a preview of the mock
display for the Chrome **Meta Ray-Ban Display Simulator** extension at
`http://127.0.0.1:<port>/`. It works on the iOS Simulator only
(`MockDeviceKitErrorCase.testServerUnavailable` elsewhere); on Android
run `adb forward tcp:9000 tcp:9000` first. Stop it with
`stopMockTestServer()`. `sendMockDisplayClick(uuid, identifier)` clicks
a component; see [Display access](display_access.md#previewing-without-glasses).

## Errors

Mock calls throw `MockDeviceKitError` (category `MOCK_ERROR`):

| `MockDeviceKitErrorCase` | Fix |
| --- | --- |
| `notEnabled` | Call `enableMockDevice()` first |
| `deviceNotFound` | The uuid is not a paired mock device |
| `wrongDeviceKind` | The mock device is not a pair of glasses |
| `testServerUnavailable` | The test server could not start (iOS: simulator only) |

## Writing integration tests

The plugin's own end-to-end tests run against Meta's real DAT 1.0 SDK
driven by Mock Device Kit. Use them as a template:

- [`example/integration_test/mock_harness.dart`](../example/integration_test/mock_harness.dart):
  `enable()`, `bringOnline(model)` (pair, power on, unfold, don, wait
  for `getDevices()`), `materialise(asset)` and a `teardown()` that
  stops everything, unpairs, disables the kit and asserts that every
  `dumpDiagnostics().resources` counter returned to zero.
- [`example/integration_test/plugin_test.dart`](../example/integration_test/plugin_test.dart):
  diagnostics, device state, mock permissions, raw stream plus photo
  plus resource release, hvc1 frames, fold-stops-stream, display, and
  the experimental capabilities.

Run them on a simulator or emulator:

```bash
cd example
flutter test integration_test/plugin_test.dart -d <device-id>
```

Tips:

- Disable and re-enable the kit at the start of each test so every
  test starts from the same state (the harness's `enable()` does this).
- Use `stream.firstWhere(...).timeout(...)` for state assertions.
  `deviceStateStream` is safe with `first` / `firstWhere`.
- Native XCTest on iOS 17/18 simulators crashes at launch (see
  [Known issues](troubleshooting.md#known-issues)); Flutter integration
  tests are not affected.

## Production builds

Never call `enableMockDevice()` in a release build. Guard it with
`kDebugMode` or a build flavour. `dumpDiagnostics().resources['mockDevices']`
should be `0` in production.
