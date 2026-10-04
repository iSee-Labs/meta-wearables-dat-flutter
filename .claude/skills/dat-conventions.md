---
description: Plugin coding conventions, architecture invariants, channel surface, wire contract v2, error model, and naming map (DAT 1.0)
globs: lib/**/*.dart, ios/**/*.swift, android/**/*.kt, tool/*.dart
---

# meta_wearables_dat_flutter Conventions (1.0)

> Canonical context: [`AGENTS.md`](../../AGENTS.md).
> Meta DAT reference: <https://wearables.developer.meta.com/llms.txt?full=true>

## Architecture invariants

- **Dart facade** `lib/meta_wearables_dat_flutter.dart` — static
  `MetaWearablesDat`, sealed `DatError`, models in `lib/src/models/**`.
  `lib/experimental.dart` re-exports experimental models.
- **Channel names** live only in `lib/src/channels.dart`
  (`DatChannels.methods` = 67, `DatChannels.events` = 34). Both native
  bridges must register exactly these; `tool/check_channel_parity.dart`
  enforces it.
- **iOS** `ios/meta_wearables_dat_flutter/Sources/meta_wearables_dat_flutter/`
  and **Android** `android/src/main/kotlin/com/iseelabs/meta_wearables_dat_flutter/`
  use the same type names: `MetaWearablesDatPlugin`, `WireCodec`,
  `DeviceSessionHub`, `MetaSessionManager`, `MetaDisplayManager`,
  `DisplayNode`, `MetaMockDeviceManager`, `DeviceStateObserver`,
  `RegistrationBridge`, `ResourceLedger`, `EventSinkHandler`,
  `StreamSessionArgs`.
- One shared `DeviceSession` per device (`DeviceSessionHub`
  acquire/release by owner).
- Bridges hold no business logic beyond SDK mapping.

## Wire contract v2

- Event channels: `meta_wearables_dat_flutter/<snake_name>`.
- State channels carry enum names as strings and replay the last value
  to new listeners.
- Method errors: `PlatformException(code: CATEGORY, details: {case,
  description, platformCase, platform})`.
- Event errors: `{code: case, category, message, platformCase, platform}`.
- Canonical case names = iOS Swift case names; Android maps its
  SCREAMING_CASE into them and keeps the raw value in `platformCase`.

## Error model

```dart
try {
  await MetaWearablesDat.startStreamSession();
} on DeviceSessionError catch (e) {
  if (e.reason == DeviceSessionErrorCase.noEligibleDevice) { /* ... */ }
  if (e.recoveryAction == DatRecoveryAction.openFirmwareUpdate) {
    await MetaWearablesDat.openFirmwareUpdate();
  }
}
```

- `category` = `DatErrorCodes.*` (e.g. `STREAM_ERROR`); `code` =
  `reason.name`.
- Subclasses: `RegistrationError`, `UnregistrationError`,
  `HandleUrlError`, `RegistrationRequestError`, `PermissionError`,
  `NavigationError`, `DeviceSessionError`, `StreamError`, `CaptureError`,
  `PhotoError`, `DisplayError`, `InputsError`, `MotionError`,
  `SpeechError`, `VoiceInvocationError`, `MockDeviceKitError`,
  `DatArgumentError`, `DatPluginError`.
- Old `is*` getters are `@Deprecated` shims; use `reason`.

## Dart conventions

- `very_good_analysis`; `flutter analyze --fatal-infos` clean.
- `///` dartdoc on every public symbol; `@experimental` on experimental
  ones.
- Public APIs return `Future<T>` / `Stream<T>`.
- Public streams with teardown use a `StreamController` whose `onCancel`
  does not await (never `async*` with awaited cleanup).
- Models decode with `fromWire` / `fromMap`; tests under `test/`.

## Swift conventions

- `async`/`await`; `AnyListenerToken.cancel()`; `@MainActor` for
  channel/UI code; never block main with frame work.
- Map errors through `WireCodec`.
- Swift language mode 5; SPM only.

## Kotlin conventions

- `Flow`/`StateFlow` + `collectLatest`; one scope per capability,
  cancelled in `stop*`.
- `StateFlow`s start at `STOPPED`: do not treat the initial value as
  terminal.
- Display builders: named arguments only. Never call `display.stop()`;
  use `session.removeDisplay()`.
- SDK packages are `com.meta.wearable.dat.*` (Maven coordinates are
  `com.meta.wearable:mwdat-*`).

## Naming map (Meta SDK → plugin)

| Meta | Dart |
|------|------|
| `Wearables.shared` / `Wearables` | `MetaWearablesDat` (static) |
| `RegistrationState` | `RegistrationState` |
| `DeviceSession` / `DeviceSessionState` | shared session / `DeviceSessionState` |
| `Stream` / `StreamSessionState` | `startStreamSession()` / `StreamSessionState` |
| `StreamConfiguration` / `StreamSessionConfig` | `StreamSessionConfig` |
| `AutoDeviceSelector` / `SpecificDeviceSelector` | default / `deviceUUID:` |
| `Display` | `startDisplaySession()` / `sendDisplayView()` |
| `FlexBox`/`Text`/`Image`/`Button`/`ButtonGroup`/`Icon`/`VideoPlayer` | `FlexBox`/`DisplayText`/`DisplayImage`/`DisplayButton`/`DisplayButtonGroup`/`DisplayIcon`/`VideoPlayer` |
| `IconName` (snake_case raw) | `DisplayIconName` (camelCase) |
| `MockDeviceKit` | `enableMockDevice()` / `*Mock*()` |

## Performance rules (non-negotiable)

- Texture path never serializes decoded frames over MethodChannel.
- `videoFramesStream` opt-in, subscriber-gated.
- Sinks set in `onListen`, nulled in `onCancel`.
- `stopStreamSession()` unregisters the texture; `ResourceLedger`
  returns to zero.

## Imports

```dart
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
import 'package:meta_wearables_dat_flutter/experimental.dart'; // optional
```

```swift
import MWDATCore
import MWDATCamera
import MWDATDisplay
import MWDATMockDevice
```

```kotlin
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.camera.Stream
```

## Links

- [`AGENTS.md`](../../AGENTS.md)
- [`doc/`](../../doc/)
- Meta docs: <https://wearables.developer.meta.com/docs/develop/>
