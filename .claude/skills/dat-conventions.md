---
description: Plugin coding conventions, architecture invariants, and naming rules
globs: lib/**/*.dart, ios/**/*.swift, android/**/*.kt
---

# meta_wearables_dat_flutter Conventions

> Full Meta DAT API reference:
> <https://wearables.developer.meta.com/llms.txt?full=true>

## Architecture invariants

The plugin is organized into three logical layers, mirroring Meta's
native modules:

- **Dart facade** (`lib/meta_wearables_dat_flutter.dart`) — public
  `Future<T>` / `Stream<T>` API, typed errors, models.
- **iOS bridge** (`ios/.../MetaWearablesDatPlugin.swift`,
  `MetaSessionManager.swift`, `MetaMockDeviceManager.swift`) — Swift
  thin wrapper around `MWDATCore` / `MWDATCamera` / `MWDATMockDevice`.
- **Android bridge**
  (`android/.../MetaWearablesDatPlugin.kt`, `MetaSessionManager.kt`,
  `MetaMockDeviceManager.kt`) — Kotlin thin wrapper.

Bridges must NOT contain business logic; everything user-visible
belongs in the Dart facade.

## Channel naming

| Channel | Type | Purpose |
|---------|------|---------|
| `meta_wearables_dat_flutter` | MethodChannel | All method calls |
| `meta_wearables_dat_flutter/registration_state` | EventChannel | `RegistrationState` |
| `meta_wearables_dat_flutter/active_device` | EventChannel | `Device?` |
| `meta_wearables_dat_flutter/devices` | EventChannel | `List<Device>` |
| `meta_wearables_dat_flutter/device_session_state` | EventChannel | `DeviceSessionState` |
| `meta_wearables_dat_flutter/device_session_errors` | EventChannel | `DeviceSessionError` |
| `meta_wearables_dat_flutter/stream_session_state` | EventChannel | `StreamSessionState` |
| `meta_wearables_dat_flutter/stream_session_errors` | EventChannel | `StreamSessionError` |
| `meta_wearables_dat_flutter/video_stream_size` | EventChannel | `Size` |
| `meta_wearables_dat_flutter/video_frames` | EventChannel | `VideoFrame` (opt-in) |
| `meta_wearables_dat_flutter/compatibility` | EventChannel | `DeviceCompatibilityEvent` |
| `meta_wearables_dat_flutter/mock_devices` | EventChannel | `List<MockDeviceInfo>` |

## Dart conventions

- All public APIs return `Future<T>` or `Stream<T>` — never callbacks.
- All public APIs have dartdoc comments with `///`.
- `very_good_analysis` lint rules apply; zero warnings is the bar.
- Error types: `RegistrationError`, `UnregistrationError`,
  `HandleUrlError`, `PermissionError`, `DeviceSessionError`,
  `StreamSessionError`. Each ships `is*` convenience getters.
- Models live under `lib/src/models/*.dart`. JSON round-trip tests live
  under `test/`.

## Swift conventions

- `async`/`await` for SDK operations.
- `AnyListenerToken.cancel()` to tear down `.listen {}` publishers.
- `@MainActor` for any code that touches `FlutterMethodChannel` /
  `FlutterEventSink` or UI.
- Never block the main thread with frame processing.
- Typed error mapping: catch each `*Error` enum and forward to Dart as
  `PlatformException(code: kErrorCode, message: human, details: kRaw)`.

## Kotlin conventions

- `Flow`/`StateFlow` with `collectLatest` for state streams.
- Use a dedicated `CoroutineScope` per stream + cancel in `stop*`.
- `Result` types where the SDK exposes them.
- Wrap `IOException`, `IllegalStateException` into typed
  `PlatformException` codes.

## Naming map (Meta SDK → Flutter plugin)

| Meta type | Dart equivalent |
|-----------|-----------------|
| `Wearables.shared` | `MetaWearablesDat` (singleton) |
| `RegistrationState` | `RegistrationState` enum |
| `DeviceSessionState` | `DeviceSessionState` enum |
| `StreamSessionState` | `StreamSessionState` enum |
| `StreamSession` | hidden — fronted by `startStreamSession()` |
| `StreamSessionConfig` | named args on `startStreamSession()` |
| `AutoDeviceSelector` | default selector |
| `SpecificDeviceSelector` | `deviceUUID:` arg |
| `MockDeviceKit` | `enableMockDevice() / *Mock*()` methods |

## Performance rules (non-negotiable)

- Texture path: never serialize decoded frames over MethodChannel.
- `videoFramesStream` is opt-in; gate emission on subscriber count.
- All event streams must stop emitting when Dart cancels its
  subscription.
- `stopStreamSession()` must unregister the texture (GPU memory leak).

## Imports

```dart
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
```

```swift
import MWDATCore
import MWDATCamera
#if canImport(MWDATMockDevice)
import MWDATMockDevice
#endif
```

```kotlin
import com.meta.wearable.mwdat.core.Wearables
import com.meta.wearable.mwdat.camera.StreamConfiguration
```

## Links

- [`AGENTS.md`](../../AGENTS.md) — canonical AI context
- [`doc/`](../../doc/) — long-form topic docs
- Meta iOS reference:
  <https://wearables.developer.meta.com/docs/reference/ios_swift/dat/0.6>
- Meta Android reference:
  <https://wearables.developer.meta.com/docs/reference/android_kotlin/dat/0.6>
