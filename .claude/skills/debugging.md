---
description: Diagnose common issues with dumpDiagnostics findings - registration failures, no eligible device, texture not rendering, SPM/Xcode errors, experimental modules not linked, known 1.0 issues
globs: lib/**/*.dart, ios/**, android/**, example/**
---

# Debugging meta_wearables_dat_flutter (1.0)

Most issues are configuration. Start with `dumpDiagnostics()`.

## Quick triage

```
Not working?
├── dumpDiagnostics().errors non-empty? → fix each finding (below)
├── registrationStateStream() == registered? → else see Registration
├── Developer Mode on in Meta AI app?
├── activeDeviceStream() non-null? → else see No eligible device
├── deviceSessionErrorStream() / streamErrorStream() emitting? → switch on reason
└── Texture black? → stale textureId, or stream stopped
```

## dumpDiagnostics

```dart
final d = await MetaWearablesDat.dumpDiagnostics();
for (final f in d.findings) {
  debugPrint('${f.severity.name} ${f.id}: ${f.message} -> ${f.fix}');
}
debugPrint('sdk ${d.sdkVersion} plugin ${d.pluginVersion}');
debugPrint('resources ${d.resources} idle=${d.isIdle}');
debugPrint('experimental ${d.experimentalModulesLinked}');
```

Same shape on both platforms. `resources` (textures, listeners,
deviceSessions, cameras, displays, decoders, capabilities, mockDevices)
must be all zero when idle; a non-zero count after stop is a leak.

Finding ids (iOS `InfoPlistValidator`, Android `ManifestDiagnostics`
reports equivalents): `mwdatMissing`, `appLinkUrlSchemeMissing`,
`appLinkUrlSchemeSuffix` (must end with `://`),
`appLinkUrlSchemeInvalid`, `appLinkUrlSchemeNotRegistered` (scheme not in
`CFBundleURLTypes`), `clientTokenMissing`, `teamIdMissing`,
`developerModeCredentials`, `externalAccessoryProtocol`,
`backgroundMode.<mode>`, `bluetoothUsageMissing`,
`localNetworkUsageMissing`, `microphoneUsageMissing`, `bonjourServices`,
`damEnabledIgnored` (`DAMEnabled` / `DAM_ENABLED` are obsolete in 1.0).

## Errors

Every failure is a `DatError` with `category`, `code`, `reason`,
`platformCase`, `recoveryAction`. Use `recoveryAction`:

| `DatRecoveryAction` | Do |
|---|---|
| `openFirmwareUpdate` | `MetaWearablesDat.openFirmwareUpdate()` |
| `openDatGlassesAppUpdate` | `MetaWearablesDat.openDatGlassesAppUpdate()` |
| `updateHostApp` | ship a build with a newer plugin/SDK |
| `checkMetaAiAndRetry` | install/update Meta AI, retry |
| `connectGlasses` | ask the user to connect/wear glasses |
| `grantPermission` | `requestPermission(...)` |

`DeviceSessionError.isTerminal` (`insufficientSDKVersion`) means no
recovery in this build; `isWarning` (`dwaOutOfStuRange`) is
non-blocking.

## Registration

- "Internal error" after Allow in Meta AI: Developer Mode off. Meta AI →
  Settings → App Info → tap version 5 times, then enable Developer Mode.
- `RegistrationErrorCase.configurationInvalid`: check findings above.
- `RegistrationErrorCase.metaAINotInstalled`: install/update Meta AI
  (V290+).
- Callback never returns: iOS scheme not in `CFBundleURLTypes`; Android
  `MainActivity` not a `FlutterFragmentActivity` or intent filter missing.
- Production app id but no new app version created for 1.0 in Wearables
  Developer Center.

## Streaming

- `DeviceSessionErrorCase.noEligibleDevice`: glasses not connected/worn.
  Check Meta AI shows Connected; doff/don; or pass `deviceUUID`.
- Stuck in `waitingForDevice`: device disconnected, `deviceKinds` too
  narrow, battery low, hinges closed (`StreamErrorCase.hingesClosed`).
- `thermalHot` / `ThermalLevel.isThrottling`: let glasses cool.
- Black texture: stale `textureId` after stop/start, or raw frames paused
  in iOS background (`rawPausedInBackground`; use `hvc1`).

## Build issues

| Symptom | Fix |
|---|---|
| iOS: `requires minimum platform version 17.2 ... target supports 15.0 (FlutterGeneratedPluginSwiftPackage)` | Set app iOS deployment target to 17.2, run `flutter build ios --config-only` once |
| iOS: Swift module compiled with newer compiler | Use Xcode 26.4+ |
| iOS: plugin not resolved / CocoaPods errors | Flutter 3.44+ (SPM default); this plugin is SPM-only |
| Android: unresolved `mwdat-*` | Ensure `mavenCentral()`; no token needed. Remove old GitHub Packages repo blocks |
| Android: `PermissionErrorCase.missingFragmentActivity` | `MainActivity : FlutterFragmentActivity()` |
| `DatPluginError` `EXPERIMENTAL_NOT_LINKED` | App built with `mwdat.experimental=false`; remove it or stop calling experimental APIs |

## Known issues (1.0)

| Issue | Workaround |
|---|---|
| Abort in MWDATCore on iOS 18 when anything calls `objc_copyClassList` (XCTest, some SDKs): MWDATCore weakly links iOS 26-only Network/WiFiAware types | Run Swift tests on an iOS 26+ simulator; make sure no app dependency enumerates all classes on iOS < 26 |
| Android SDK `display.stop()` before `removeDisplay` can NPE | Plugin uses `removeDisplay()` only; no action |
| `sendMockDisplayClick` identifier format undocumented | Returns true but may not fire `onClick` |
| Raw frames pause in iOS background | Use `VideoCodec.hvc1` |

## Compatibility

| Plugin | Meta DAT | Min iOS | Min Android | Distribution |
|---|---|---|---|---|
| 1.0.x | 1.0.0 | 17.2 (SPM, Xcode 26.4+) | API 31, Maven Central | Developer Mode, Beta channel |
| 0.7.x | 0.7.0 | 17.0 | API 31, GitHub Packages | Developer Mode |

## Links

- [`doc/troubleshooting.md`](../../doc/troubleshooting.md)
- [`doc/migration_0.7_to_1.0.md`](../../doc/migration_0.7_to_1.0.md)
- Meta known issues: <https://wearables.developer.meta.com/docs/knownissues>
