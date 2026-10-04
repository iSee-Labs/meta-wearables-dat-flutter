# Device state

DAT 1.0 reports live state for each pair of glasses: connection,
battery, charging, wear, hinges and thermal level, plus version
compatibility. Use it to tell users what to do before a session fails,
and to back off before the glasses overheat.

## `DeviceInfo`

`getDevices()`, `getDevice(uuid)`, `getSessionDevice()`,
`devicesStream()`, `activeDeviceStream()` and `deviceStateStream(uuid)`
all return `DeviceInfo` snapshots.

| Field | Type | Meaning |
| --- | --- | --- |
| `uuid` | `String` | SDK device id; pass it as `deviceUUID:` |
| `name` | `String` | Display name (falls back to the id) |
| `kind` | `DeviceKind` | Family: `rayBanMeta`, `rayBanDisplay`, `oakleyMeta`, `metaGlasses`, `unknown` |
| `type` | `DeviceType` | Exact model: `rayBanMeta`, `rayBanMetaOptics`, `oakleyMetaHSTN`, `oakleyMetaVanguard`, `metaRayBanDisplay`, `metaGlasses`, `unknown` |
| `linkState` | `LinkState` | `connected`, `connecting`, `disconnected`, `unknown`. `isConnected` is a shortcut |
| `compatibility` | `DeviceCompatibility` | `compatible`, `deviceUpdateRequired`, `sdkUpdateRequired`, `unknown` |
| `batteryLevel` | `int?` | 0-100, `null` when unknown |
| `chargingState` | `ChargingState` | `charging`, `notCharging`, `unknown` |
| `donState` | `DonState` | `donned` (worn), `doffed`, `unknown` |
| `hingeState` | `HingeState` | `open`, `closed` (folded), `unknown` |
| `thermalLevel` | `ThermalLevel` | `none` up to `shutdown`, see [Thermal](#thermal) |
| `supportsDisplay` | `bool` | Meta Ray-Ban Display |
| `isMock` | `bool` | Mock Device Kit device |

Fields the SDK does not report on a platform or device read as
`unknown` (or `null` for the battery).

## Streams

| API | Emits |
| --- | --- |
| `devicesStream()` | The full list of paired devices on every change, including battery or wear changes |
| `deviceStateStream(uuid)` | The current snapshot of one device first, then every change |
| `activeDeviceStream()` | The device the SDK would pick automatically, or `null` |
| `compatibilityStream()` | `DeviceCompatibilityEvent(deviceUuid, compatibility)` per device |

`deviceStateStream` is safe to use with `first`, `firstWhere` and
`take`; cancelling it never blocks.

```dart
StreamSubscription<DeviceInfo> watchGlasses(String uuid) {
  return MetaWearablesDat.deviceStateStream(uuid).listen((device) {
    if (!device.isConnected) return showBanner('Glasses disconnected');
    if (device.hingeState == HingeState.closed) {
      return showBanner('Unfold your glasses');
    }
    if (device.donState == DonState.doffed) {
      return showBanner('Put your glasses on to stream');
    }
    final battery = device.batteryLevel;
    if (battery != null &&
        battery < 15 &&
        device.chargingState != ChargingState.charging) {
      showBanner('Glasses battery low ($battery%)');
    }
  });
}
```

(`showBanner` stands for your own UI.)

## Wear and hinges

- Taking the glasses off (`doffed`) or tapping the touchpad pauses the
  stream (`StreamSessionState.paused`); it resumes on its own.
- Folding the glasses (`HingeState.closed`) ends the stream with
  `StreamErrorCase.hingesClosed`. Start a new session after the user
  unfolds them.

## Thermal

`ThermalLevel` escalates `none`, `light`, `moderate`, `severe`,
`critical`, `emergency`, `shutdown` (`unknown` when not reported).

| Level | Helper | Recommended action |
| --- | --- | --- |
| `none`, `light` | | Nothing |
| `moderate`, `severe` | `isThrottling == true` | Reduce the workload: lower `StreamFrameRate` and `StreamQuality`, stop optional capabilities, stop per-frame processing |
| `critical`, `emergency`, `shutdown` | `isCritical == true` | Stop non-essential work now and tell the user the glasses need to cool down |

The SDK also ends sessions on its own: `DeviceSessionErrorCase.thermalCritical`,
`thermalEmergency` and `peakPowerShutdown`, or `StreamErrorCase.thermalHot`
and `peakPowerLimit` for the stream. To lower the workload you must
restart the stream with a smaller config; it cannot be changed while
running.

```dart
StreamSessionConfig configFor(DeviceInfo device) {
  if (device.thermalLevel.isThrottling) {
    return const StreamSessionConfig(
      quality: StreamQuality.low,
      frameRate: StreamFrameRate.fps15,
    );
  }
  return const StreamSessionConfig(quality: StreamQuality.high);
}
```

## Battery

- `DeviceSessionErrorCase.batteryCritical` and
  `StreamErrorCase.batteryLow` end sessions. Ask the user to charge.
- `chargingState` tells you whether a warning makes sense.

## Compatibility

`DeviceInfo.compatibility` and `compatibilityStream()` report whether
this app's SDK and the glasses can work together:

| `DeviceCompatibility` | Action |
| --- | --- |
| `compatible` | Nothing |
| `deviceUpdateRequired` | The glasses firmware is too old: `MetaWearablesDat.openFirmwareUpdate()` |
| `sdkUpdateRequired` | This app build is too old: ship an update of your app |
| `unknown` | Not reported yet |

## Update flows

Device session errors carry a `recoveryAction` that follows Meta's
guidance for DAT version errors:

| Error | Severity | `recoveryAction` | What to do |
| --- | --- | --- | --- |
| `DeviceSessionErrorCase.datAppOnTheGlassesUpdateRequired` | Blocking | `openDatGlassesAppUpdate` | `MetaWearablesDat.openDatGlassesAppUpdate()`, then retry |
| `DeviceCompatibility.deviceUpdateRequired` | Blocking | (use `openFirmwareUpdate`) | `MetaWearablesDat.openFirmwareUpdate()`, then retry |
| `DeviceSessionErrorCase.insufficientSDKVersion` | **Terminal** (`isTerminal`) | `updateHostApp` | This build cannot work with the glasses; ask the user to update your app. Do not retry |
| `DeviceSessionErrorCase.dwaOutOfStuRange` | **Warning** (`isWarning`) | `suggestUpdate` | The session keeps running. Suggest an update occasionally |
| `DeviceSessionErrorCase.dwaUnavailable` | Blocking | `checkMetaAiAndRetry` | Ask the user to check the glasses in Meta AI, then retry |
| `noEligibleDevice`, `startTimeout`, `deviceDisconnected` | Blocking | `connectGlasses` | Pair, power on, unfold and wear the glasses, then retry |
| `thermalCritical`, `thermalEmergency`, `peakPowerShutdown`, `batteryCritical` | Blocking | `none` | Wait for the glasses to cool down or charge |

```dart
MetaWearablesDat.deviceSessionErrorStream().listen((error) async {
  if (error.isWarning) return; // dwaOutOfStuRange: keep going
  switch (error.recoveryAction) {
    case DatRecoveryAction.openDatGlassesAppUpdate:
      try {
        await MetaWearablesDat.openDatGlassesAppUpdate();
      } on NavigationError catch (e) {
        showBanner('Open the Meta AI app to update your glasses (${e.code}).');
      }
    case DatRecoveryAction.openFirmwareUpdate:
      await MetaWearablesDat.openFirmwareUpdate();
    case DatRecoveryAction.updateHostApp:
      showBanner('Update this app to keep using your glasses.');
    default:
      showBanner(error.message);
  }
});
```

`openFirmwareUpdate()` and `openDatGlassesAppUpdate()` open the
corresponding screen in the Meta AI app. They throw a `NavigationError`
(`metaAINotInstalled`, `notRegistered`, `noActivity` on Android) when
that is not possible.

## Simulating state

The [Mock Device Kit](mock_device.md#device-state) sets battery,
charging, thermal level, wear and hinge state, so you can test every
branch above without glasses.
