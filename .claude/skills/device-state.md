---
description: Device discovery and live device state in DAT 1.0 - DeviceInfo fields, deviceStateStream, battery/charging/wear/hinge/thermal/link, compatibility, and active device selection
globs: lib/src/models/device_info.dart, lib/src/models/device_compatibility.dart, lib/meta_wearables_dat_flutter.dart, ios/**/DeviceStateObserver.swift, android/**/DeviceStateObserver.kt
---

# Device State (Flutter, DAT 1.0)

## APIs

| Call | Returns |
|---|---|
| `getDevices()` | `Future<List<DeviceInfo>>` |
| `getDevice(uuid)` | `Future<DeviceInfo?>` |
| `getSessionDevice()` | device of the current shared session, or `null` |
| `devicesStream()` | full list on every change (incl. battery/wear) |
| `deviceStateStream(uuid)` | current snapshot first, then live changes |
| `activeDeviceStream()` | device the SDK would auto-select, or `null` |
| `compatibilityStream()` | `DeviceCompatibilityEvent` per device |

Channels: `devices`, `device_state`, `active_device`, `compatibility`.

## DeviceInfo

| Field | Type / values |
|---|---|
| `uuid`, `name` | `String` |
| `kind` | `DeviceKind`: `rayBanMeta`, `rayBanDisplay`, `oakleyMeta`, `metaGlasses`, `unknown` |
| `type` | `DeviceType`: `rayBanMeta`, `rayBanMetaOptics`, `oakleyMetaHSTN`, `oakleyMetaVanguard`, `metaRayBanDisplay`, `metaGlasses`, `unknown` |
| `linkState` | `disconnected`, `connecting`, `connected`, `unknown` (`isConnected`) |
| `compatibility` | `DeviceCompatibility`: `compatible`, `deviceUpdateRequired`, `sdkUpdateRequired`, `unknown` |
| `batteryLevel` | `int?` 0..100 |
| `chargingState` | `charging`, `notCharging`, `unknown` |
| `donState` | `donned`, `doffed`, `unknown` |
| `hingeState` | `open`, `closed`, `unknown` |
| `thermalLevel` | `unknown`, `none`, `light`, `moderate`, `severe`, `critical`, `emergency`, `shutdown` (`isThrottling` >= moderate, `isCritical` >= critical) |
| `supportsDisplay` | `bool` |
| `isMock` | `bool` |

## Usage

```dart
final sub = MetaWearablesDat.deviceStateStream(uuid).listen((d) {
  if (d.hingeState == HingeState.closed) showOpenHinges();
  if (d.thermalLevel.isThrottling) lowerQuality();
});

final first = await MetaWearablesDat.deviceStateStream(uuid).first; // safe
```

`deviceStateStream` buffers live updates that arrive before the snapshot,
so the snapshot never overwrites newer data. It is a plain
`StreamController` (not `async*`) so `first` / `firstWhere` complete
promptly; keep it that way.

## Compatibility

`deviceUpdateRequired` → `openFirmwareUpdate()`; `sdkUpdateRequired` →
ship a newer app build (`DatRecoveryAction.updateHostApp`).

## Mock

`setMockBatteryLevel`, `setMockChargingState`, `setMockThermalLevel`,
`mockDon/Doff`, `mockFold/Unfold`, `mockPowerOn/Off` drive every field.
A mock appears in `devicesStream()` only after power-on and unfold.

## Links

- [`doc/device_state.md`](../../doc/device_state.md)
- [session-lifecycle.md](session-lifecycle.md)
- [mockdevice-testing.md](mockdevice-testing.md)
