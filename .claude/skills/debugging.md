---
description: Diagnose common issues - registration failures, no eligible device, texture not rendering, Maven 401, Xcode SPM errors
globs: lib/**/*.dart, ios/**, android/**
---

# Debugging meta_wearables_dat_flutter

Use this when something doesn't work. Most issues are config; the
plugin itself rarely throws at runtime once registration is solid.

## Quick triage

```
Connection / streaming not working?
│
├── flutter analyze clean? → fix lints first
│
├── registrationStateStream() emits registered? → if no, see Registration
│
├── Developer Mode enabled in Meta AI app? → toggle on
│
├── activeDeviceStream() emits a non-null device? → if no, see No eligible device
│
├── streamSessionStateStream() emits streaming? → if no, see Stream stuck
│
└── Texture widget shows black? → check textureId reuse + dispose
```

## Use the built-in diagnostics

```dart
final diag = await MetaWearablesDat.dumpDiagnostics();
debugPrint(jsonEncode(diag));
```

Returns the SDK version, `Info.plist` validation results, current
registration state, paired devices, and per-flag pre-flight checks.

## Registration

### "Internal error" after tapping Allow in Meta AI

Developer Mode is OFF in the Meta AI app.

Fix: Meta AI → Settings → Developer Mode → ON.

### `RegistrationError.configurationInvalid` with raw value 1

Your `Info.plist` `MWDAT` dict is missing a key or the URL scheme has
an underscore.

Fix: ensure all four keys (`AppLinkURLScheme`, `MetaAppID`, `ClientToken`,
`TeamID`) are present and the scheme is RFC 3986 compliant.

### `RegistrationError.metaAiNotInstalled`

Meta AI app missing or out of date.

Fix: install/update from the App Store/Play Store.

### Registration deep link never returns

- iOS: `CFBundleURLTypes` not declared, or `SceneDelegate` not
  forwarding URLs to the plugin.
- Android: `MainActivity` doesn't extend `FlutterFragmentActivity`, or
  the intent filter for your scheme is missing.

## Streaming

### "No eligible device available"

The SDK auto-selector found no connected/donned glasses.

Fix sequence:

1. Open Meta AI app, confirm your glasses appear and show "Connected".
2. Doff and re-don the glasses.
3. Open `samples/camera_access`, tap "Diagnostics", confirm the active
   device UUID is non-null. If it is null but `getDevices()` returns
   entries, force a specific device:

   ```dart
   final devices = await MetaWearablesDat.getDevices();
   await MetaWearablesDat.startStreamSession(deviceUUID: devices.first.uuid);
   ```

### Stream stuck in `waitingForDevice`

- Device disconnected mid-session — restart Bluetooth.
- Wrong `deviceKinds` filter — broaden or omit.
- Battery in glasses is low.

### Texture is black

- Texture widget rebuilt with a stale `textureId` — store it once and
  hold it.
- `stopStreamSession()` was called and the texture handle wasn't
  refreshed.

## Build issues

### iOS: `Missing MWDATCore`

SPM support not enabled.

Fix: `flutter config --enable-swift-package-manager` then
`flutter clean && cd ios && rm -rf Pods Podfile.lock && cd ..`.

### iOS: deployment target mismatch

Plugin requires iOS 17.0. Bump
`IPHONEOS_DEPLOYMENT_TARGET = 17.0` in your `.xcodeproj`.

### Android: Maven 401

`GITHUB_TOKEN` env var missing or lacks `read:packages` scope.

Fix: create a PAT with `read:packages` scope; export `GITHUB_TOKEN`,
or add `github_token=...` to `android/local.properties`.

### Android: `MISSING_FRAGMENT_ACTIVITY`

`MainActivity` extends `FlutterActivity` instead of
`FlutterFragmentActivity`.

## Compatibility matrix

| Plugin | Meta DAT SDK | Min iOS | Min Android |
|--------|--------------|---------|-------------|
| 0.2.x  | 0.6.0        | 17.0    | API 31      |
| 0.1.x  | 0.6.0        | 17.0    | API 31      |

## Known issues

| Issue | Workaround |
|-------|-----------|
| Streams started while doffed pause when donned | Tap side of glasses to resume |
| `DeviceStateSession` unreliable with camera stream | Avoid using it concurrently |
| Android: HEVC `hvc1` has no preview path | Use `VideoCodec.raw` for preview, `hvc1` for recording |
| iOS: Ray-Ban Display has no audio feedback on pause/resume | Will be fixed by Meta in future release |

## Adding debug logging

```dart
import 'package:flutter/foundation.dart';

MetaWearablesDat.streamSessionStateStream().listen(
  (state) => debugPrint('stream state: $state'),
);
MetaWearablesDat.streamSessionErrorStream().listen(
  (err) => debugPrint('stream error: $err'),
);
```

## Links

- [`doc/troubleshooting.md`](../../doc/troubleshooting.md)
- Meta known issues:
  <https://wearables.developer.meta.com/docs/knownissues>
