# Troubleshooting

Start with `MetaWearablesDat.dumpDiagnostics()`. Most setup problems
show up as a finding with a fix before anything fails at runtime (see
[Getting started](getting_started.md#6-first-run-check-the-configuration)).

- [Diagnostics findings](#diagnostics-findings)
- [iOS build](#ios-build)
- [Android build](#android-build)
- [Registration](#registration)
- [Permissions](#permissions)
- [Streaming](#streaming)
- [Display](#display)
- [Mock Device Kit](#mock-device-kit)
- [Errors by category](#errors-by-category)
- [Known issues](#known-issues)
- [Reporting a bug](#reporting-a-bug)

## Diagnostics findings

`DatDiagnostics.findings` lists `DatFinding`s with `id`, `severity`
(`error`, `warning`, `info`), `message` and `fix`. `errors` returns only
the `error` ones. A release build should have no `error` or `warning`
findings.

### iOS (Info.plist)

| Finding id | Severity | Fix |
| --- | --- | --- |
| `mwdatMissing` | error | Add the `MWDAT` dictionary with `AppLinkURLScheme`, `MetaAppID`, `ClientToken`, `TeamID` |
| `appLinkUrlSchemeMissing` | error | Set `MWDAT > AppLinkURLScheme`, for example `myapp://` |
| `appLinkUrlSchemeSuffix` | error | Append `://`. If you preprocess Info.plist, `//` is stripped unless you use `-traditional-cpp` |
| `appLinkUrlSchemeInvalid` | error | Use only letters, digits, `+`, `-`, `.`, starting with a letter. No underscores |
| `appLinkUrlSchemeNotRegistered` | error | Add the scheme (without `://`) to `CFBundleURLTypes > CFBundleURLSchemes` |
| `clientTokenMissing` | error | `MetaAppID` is set: copy the client token from Wearables Developer Center |
| `teamIdMissing` | error | `MetaAppID` is set: set `TeamID`, for example `$(DEVELOPMENT_TEAM)` |
| `developerModeCredentials` | info | `MetaAppID` is empty, `0` or an unexpanded variable: registration only works in Developer Mode. Set real credentials for release channels |
| `damEnabledIgnored` | info | Remove `MWDAT > DAMEnabled` (obsolete) |
| `backgroundMode.bluetooth-central` | error | Add `bluetooth-central` to `UIBackgroundModes` |
| `backgroundMode.external-accessory` | error | Add `external-accessory` to `UIBackgroundModes` |
| `backgroundMode.bluetooth-peripheral` | warning | Add `bluetooth-peripheral` to `UIBackgroundModes` |
| `backgroundMode.processing` | warning | Add `processing` to `UIBackgroundModes` |
| `externalAccessoryProtocol` | error | Add `com.meta.ar.wearable` to `UISupportedExternalAccessoryProtocols` |
| `bluetoothUsageMissing` | error | Add `NSBluetoothAlwaysUsageDescription` |
| `localNetworkUsageMissing` | error | Add a non-empty `NSLocalNetworkUsageDescription` |
| `bonjourServices` | warning | Add `_bonjour._tcp` to `NSBonjourServices` |
| `microphoneUsageMissing` | warning | `UIBackgroundModes` has `audio` but `NSMicrophoneUsageDescription` is missing: add it |

The diagnostics `raw` map also contains `config` (the `MWDAT` dict and
URL schemes the app actually shipped with), `analyticsOptOut`,
`crashReportingOptOut` and `backgroundStreamingEnabled`.

### Android (AndroidManifest.xml and runtime)

| Finding id | Severity | Fix |
| --- | --- | --- |
| `applicationIdMissing` | error | Add the `com.meta.wearable.mwdat.APPLICATION_ID` meta-data |
| `developerModeCredentials` | info | `APPLICATION_ID` is empty or `0`: Developer Mode only |
| `clientTokenMissing` | error | Set `com.meta.wearable.mwdat.CLIENT_TOKEN` when `APPLICATION_ID` is real |
| `damEnabledIgnored` | info | Remove the `com.meta.wearable.mwdat.DAM_ENABLED` meta-data (obsolete) |
| `permission.BLUETOOTH` | error | Add `<uses-permission android:name="android.permission.BLUETOOTH"/>` |
| `permission.BLUETOOTH_CONNECT` | error | Add `<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>` |
| `permission.INTERNET` | error | Add `<uses-permission android:name="android.permission.INTERNET"/>` |
| `bluetoothConnectNotGranted` | warning | Call `MetaWearablesDat.requestAndroidPermissions()` |
| `postNotificationsNotGranted` | info | Android 13+: request `POST_NOTIFICATIONS` before `enableBackgroundStreaming()` |
| `activityNotComponentActivity` | error | Make `MainActivity` extend `FlutterFragmentActivity` |

## iOS build

**"The package product 'meta-wearables-dat-flutter-product' requires
minimum platform version 17.2 for the iOS platform, but this target
supports 15.0 (in target 'FlutterGeneratedPluginSwiftPackage')"**

Happens when you build with Xcode directly after `flutter pub get`. Set
the app's iOS deployment target to 17.2 (Runner target and, if present,
`platform :ios, '17.2'` in the `Podfile`), then regenerate the plugin
package once:

```bash
flutter build ios --config-only
```

Any `flutter build ios` or `flutter run` also regenerates it.

**"Module compiled with Swift 6.3.3 cannot be imported by the Swift
6.x compiler"** (or a similar Swift version error from `MWDATCore`)

Meta's binaries are built with Swift 6.3.3. Install **Xcode 26.4 or
newer** and select it with `sudo xcode-select -s /Applications/Xcode.app`.

**`MWDATCore is missing. meta_wearables_dat_flutter needs Flutter >= 3.44
with Swift Package Manager enabled ...`, or "No such module 'MWDATCore'"**

The plugin was resolved through CocoaPods. It is Swift Package Manager
only:

1. `flutter config --enable-swift-package-manager`
2. `flutter clean && flutter pub get`
3. `flutter build ios --config-only`

If your `Podfile` only existed for Flutter plugins, Flutter can migrate
you off CocoaPods entirely; otherwise keep the `Podfile` for your other
pods. This plugin never appears in `Podfile.lock`.

**Package resolution fails for `facebook/meta-wearables-dat-ios`**

The package is pinned to exactly `1.0.0`. If another package pins a
different version, the resolution conflicts; align on 1.0.0. Clearing
Xcode's package cache (`File > Packages > Reset Package Caches`) helps
after a network failure.

## Android build

**`Could not resolve com.meta.wearable:mwdat-core:1.0.0`, HTTP 401 from
`maven.pkg.github.com`**

Leftover 0.x configuration. DAT 1.0 is on Maven Central. Remove from
`settings.gradle(.kts)` / `build.gradle(.kts)` the GitHub Packages
repository for `facebook/meta-wearables-dat-android` and its
`credentials { ... }`, and delete `github_token` from
`local.properties`. Gradle treats a 401 from a declared repository as a
failure, so the leftover breaks the build even though the artifact is
on Maven Central.

**Manifest merger: `uses-sdk:minSdkVersion ... cannot be smaller than
version 31`**

Set `minSdk = 31` in `android/app/build.gradle(.kts)`.

**AAR metadata: dependency requires `compileSdk` 36**

Set `compileSdk = 36` (or higher).

**Unsupported class file / JVM target errors**

Use JDK 17 and set `sourceCompatibility`, `targetCompatibility` and
`jvmTarget` to 17.

**Experimental calls fail with `EXPERIMENTAL_NOT_LINKED`**

Your app's `android/gradle.properties` has `mwdat.experimental=false`.
Remove it, or stop calling Inputs, Motion and Speech. See
[Experimental APIs](experimental.md#android-opting-out-of-the-experimental-modules).

## Registration

**Meta AI shows "Internal error" before or right after you tap Allow**

1. Developer Mode is off in the Meta AI app on this phone. Meta AI >
   Settings > App Info, tap the version 5 times, turn Developer Mode on.
   No rebuild needed.
2. The callback scheme is not a valid RFC 3986 scheme (for example it
   contains `_`). Rename it in `MWDAT > AppLinkURLScheme`,
   `CFBundleURLTypes` and the Android `<data android:scheme>`. Finding:
   `appLinkUrlSchemeInvalid`.
3. Older SDKs sometimes failed the same way when analytics could not be
   uploaded with Developer Mode credentials; opting out
   (`MWDAT > Analytics > OptOut`, Android `ANALYTICS_OPT_OUT`) avoided
   it.

**Meta AI approves but never returns to your app**

`AppLinkURLScheme` does not end with `://` (finding
`appLinkUrlSchemeSuffix`), or its scheme is not registered in
`CFBundleURLTypes` (finding `appLinkUrlSchemeNotRegistered`) or in the
Android intent filter. Meta AI builds the callback by appending the
query string to `AppLinkURLScheme`, so a missing `://` yields an invalid
URL that iOS drops silently.

**Your app reopens, but the state stays `registering` (iOS)**

The app uses a scene-based lifecycle and the scene delegate does not
forward the URL. Add the `MetaWearablesDatHandleURL` forwarding from
[Getting started](getting_started.md#34-forward-the-meta-ai-callback-scene-based-apps).

**Your app reopens, but the state stays `registering` (Android)**

`MainActivity` lacks `android:launchMode="singleTop"` or the `VIEW`
intent filter with your scheme.

**Android: registration fails with HTTP 401 from `api2.ar.meta.com`**

Developer Mode is off in Meta AI, or `APPLICATION_ID` / `CLIENT_TOKEN`
are placeholders other than `0` outside Developer Mode. Use `0`/`0` in
Developer Mode, real values from the Developer Center otherwise.

**`registrationStateStream()` stays `unavailable` on Android**

`BLUETOOTH_CONNECT` was not granted, so the SDK is not initialised.
Call `requestAndroidPermissions()` and check that it returns `true`.

**`RegistrationErrorCase.configurationInvalid`**

Run `dumpDiagnostics()` and fix every `error` finding. Also check
`LSApplicationQueriesSchemes` contains `fb-viewapp` (iOS) and that
`TeamID` expanded to your team (inspect `raw['config']`).

**Registration works in Developer Mode but not for testers**

Testers need the build from the Beta release channel, and the build
must carry the app id and client token of the **DAT 1.0 app version**
you created in the Wearables Developer Center.

**`RegistrationRequestErrorCase.alreadyHandled`**

A Meta-AI-initiated request was answered twice or after it expired
(five minutes). See [Registration](registration_flow.md#meta-ai-initiated-registration).

## Permissions

**`PermissionErrorCase.missingFragmentActivity` (Android)**

`MainActivity` extends `FlutterActivity`. Change it to
`FlutterFragmentActivity`.

**`PermissionErrorCase.noDevice` / `noDeviceWithConnection`**

Permissions are requested through the glasses' Meta AI connection.
Pair, power on and connect the glasses first.

**`requestPermission` returns `denied` without a prompt**

The user denied it earlier in Meta AI. Explain why you need it and let
them change it in the Meta AI app.

## Streaming

**`DeviceSessionErrorCase.noEligibleDevice`**

No connected glasses match. Check with `getDevices()` that the glasses
are `connected`, unfolded (`HingeState.open`) and worn
(`DonState.donned`), and that `deviceKinds` (if set) includes them. The
0.7-era fix of adding `DAM_ENABLED` no longer applies; remove that key.

**The texture stays black**

- The glasses are not worn, or the stream is `paused` (touchpad tap).
  Watch `streamSessionStateStream()`.
- Camera permission is not granted.
- Mock device without a feed: call `setMockCameraFeed` or
  `setMockCameraFacing`.
- Android with `hvc1` and no HEVC decoder: `hevcDecoderUnavailable`.
  Use `raw`.

**The stream stops when the app goes to the background (iOS)**

Expected without background streaming: the plugin stops the stream and
reports `stoppedInBackground`. Call `enableBackgroundStreaming()` before
`startStreamSession()` and declare the `audio` background mode.

**Frames stop in the background but resume in the foreground (iOS)**

You stream `raw`. Raw frames pause in the background
(`rawPausedInBackground`). Use `VideoCodec.hvc1`.

**hvc1 preview freezes after backgrounding (iOS)**

Background streaming was enabled after the stream started, so the
hardware decoder was used. Enable it first, or restart the stream.

**No notification while streaming in the background (Android 13+)**

`POST_NOTIFICATIONS` is not granted. The service still runs, but the
notification is hidden. Request it before `enableBackgroundStreaming()`.

**The stream ends with `hingesClosed`, `thermalHot`, `batteryLow` or
`peakPowerLimit`**

Glasses-side conditions. See [Device state](device_state.md) for how to
react and lower the workload.

**`insufficientSDKVersion`, `datAppOnTheGlassesUpdateRequired`,
`dwaOutOfStuRange`**

Version mismatch between your app and the glasses. See
[Device state: update flows](device_state.md#update-flows).

**Resource counters are not zero after `stopStreamSession()`**

Something still uses the device session (display or an experimental
capability), or a listener is still subscribed. Stop every capability
and cancel your subscriptions, then check `dumpDiagnostics().isIdle`.
If it stays non-zero, report a bug with the diagnostics output.

## Display

**`startDisplaySession` fails**

The glasses are not Meta Ray-Ban Display (`supportsDisplay == false`),
or `datAppOnTheGlassesUpdateRequired` (call `openDatGlassesAppUpdate()`).

**The view disappears**

- The user made the Back gesture: the display session ended
  (`displayStateStream()` emits `stopped`). Start a new session.
- The display dims after about 20 s and sleeps after about 25 s without
  interaction.

**Callbacks do not fire**

Only callbacks of the view currently on the glasses fire; every
`sendDisplayView` replaces them. For mock clicks see
[Known issues](#known-issues).

**`sendDisplayView` returns warnings**

Unsupported values were substituted (for example the deprecated
`spaceBetween` alignment). Check `DisplayNode.validate()` while
developing.

**Video does not play**

`VideoPlayer` must be the root, the URL must be https MP4, at most
400 px per side and 70,000 px in total.

## Mock Device Kit

**The mock device never appears in `getDevices()`**

Call `mockPowerOn` and `mockUnfold` after pairing; streaming also needs
`mockDon`.

**`MockDeviceKitErrorCase.notEnabled`**

Call `enableMockDevice()` first.

**`startMockTestServer` fails with `testServerUnavailable` (iOS)**

The test server runs on the iOS Simulator only.

**The Chrome simulator cannot connect (Android)**

Run `adb forward tcp:9000 tcp:9000` (or your port).

**`pairMockGlasses` fails after a few devices**

At most three mock devices can be paired. Unpair one with
`unpairMockDevice`.

## Errors by category

Every failure is a subclass of the sealed `DatError`. `category` is the
value below; `code` is the specific case (iOS Swift case names, shared
by both platforms); `platformCase` is the raw native name.

| `category` | Class | Typical codes | Typical fix |
| --- | --- | --- | --- |
| `REGISTRATION_ERROR` | `RegistrationError` | `metaAINotInstalled`, `configurationInvalid`, `networkUnavailable`, `alreadyRegistered` | Install Meta AI; fix diagnostics; retry online |
| `UNREGISTRATION_ERROR` | `UnregistrationError` | `alreadyUnregistered` | Ignore |
| `HANDLE_URL_ERROR` | `HandleUrlError` | `invalidUrl` | Pass the full callback URL |
| `REGISTRATION_REQUEST_ERROR` | `RegistrationRequestError` | `alreadyHandled`, `registrationFailed` | Answer once, within five minutes |
| `PERMISSION_ERROR` | `PermissionError` | `noDevice`, `requestInProgress`, `missingFragmentActivity` | Connect glasses; wait; `FlutterFragmentActivity` |
| `NAVIGATION_ERROR` | `NavigationError` | `metaAINotInstalled`, `notRegistered` | Install Meta AI; register |
| `DEVICE_SESSION_ERROR` | `DeviceSessionError` | `noEligibleDevice`, `insufficientSDKVersion`, `datAppOnTheGlassesUpdateRequired`, `thermalCritical`, `batteryCritical` | Follow `recoveryAction` ([Device state](device_state.md#update-flows)) |
| `STREAM_ERROR` | `StreamError` | `hingesClosed`, `thermalHot`, `permissionDenied`, `hevcDecoderUnavailable` | See [Streaming](streaming.md#common-stream-errors) |
| `CAPTURE_ERROR` | `CaptureError` | `notStreaming`, `captureInProgress`, `timeout` | Start a stream; one capture at a time |
| `DISPLAY_ERROR` | `DisplayError` | `notStarted`, `renderingFailed`, `videoPlaybackFailed` | See [Display access](display_access.md#errors) |
| `PHOTO_ERROR` | `PhotoError` (experimental) | `notReady`, `busy`, `deviceHealthCritical` | Wait; retry |
| `INPUTS_ERROR` | `InputsError` (experimental) | `permissionDenied` | Get Inputs approved in Developer Center |
| `MOTION_ERROR` | `MotionError` (experimental) | `sensorUnavailable` | |
| `SPEECH_ERROR` | `SpeechError` (experimental) | `alreadyListening`, `unavailable` | Grant `Permission.microphone` |
| `VOICE_INVOCATION_ERROR` | `VoiceInvocationError` (experimental) | `channelNotConnected`, `alreadyResponded` | Respond once |
| `MOCK_ERROR` | `MockDeviceKitError` | `notEnabled`, `deviceNotFound` | `enableMockDevice()`; check the uuid |
| `INVALID_ARGUMENT` | `DatArgumentError` | `invalidArgument` | Fix the argument (fps, battery level, display tree) |
| `PLUGIN_ERROR`, `NOT_SUPPORTED`, `EXPERIMENTAL_NOT_LINKED` | `DatPluginError` | `wearablesNotConfigured`, `wearablesNotInitialized`, `notLinked` | Fix diagnostics; `requestAndroidPermissions()`; link experimental modules |

Pattern-match on the subclass and its `reason`:

```dart
String describe(DatError error) => switch (error) {
  StreamError(reason: StreamErrorCase.hingesClosed) => 'Unfold your glasses.',
  DeviceSessionError(isTerminal: true) => 'Please update this app.',
  PermissionError(reason: PermissionErrorCase.missingFragmentActivity) =>
    'MainActivity must extend FlutterFragmentActivity.',
  _ => error.message,
};
```

Upgrading from 0.7: `DatError.code` used to hold the category; it now
holds the specific case, and the category moved to `category`. The old
`is*` getters still work (they always returned `false` in 0.7) but are
deprecated. See the [migration guide](migration_0.7_to_1.0.md).

## Known issues

1. **Enumerating all Objective-C classes crashes on iOS 18 (Meta SDK
   issue).** `MWDATCore` 1.0.0 weakly links Swift types that exist only on
   iOS 26, such as `Network.NetworkConnection` and the `WiFiAware`
   framework. Normal SDK code checks availability before using them. But
   `objc_copyClassList` initializes every class's metadata, and on iOS 17.2
   to 18.x the app aborts:

   ```text
   Failed to look up symbolic reference ... in .../MWDATCore
   ```

   The crash stack shows `objc_copyClassList` > `realizeAllClasses` >
   `swift_getSingletonMetadata` > `MWDATCore`. It was reproduced on the
   iOS 18.0 and 18.5 simulators, both from XCTest (which enumerates classes
   to find tests) and from app code calling `objc_copyClassList` at launch.
   iOS 26.5 and 27 are not affected.

   What to do:
   - Run XCTest bundles (for example `RunnerTests`) on an iOS 26+
     simulator.
   - Before shipping to iOS 18 users, check that no SDK in your app calls
     `objc_copyClassList` or `objc_getClassList`. Some analytics,
     crash-reporting and dependency-injection libraries do. Test a release
     build on an iOS 18 device.
   - Plugin use itself is unaffected; the Flutter integration tests pass
     on iOS 18.

   A ready-to-file report for Meta is in
   [`meta_issue_objc_copyClassList.md`](meta_issue_objc_copyClassList.md).
2. **Android display stop.** Calling the SDK's `display.stop()` before
   `removeDisplay` can throw a `NullPointerException` inside Meta's SDK.
   The plugin detaches with `removeDisplay()` only. No action needed.
3. **`sendMockDisplayClick` identifiers.** Meta does not document the
   identifier format. The call returns `true` but may not fire your
   `onClick` callback.
4. **Raw frames pause in the iOS background.** Use `VideoCodec.hvc1`
   for background streaming.
5. **Building with Xcode right after `flutter pub get`** fails with the
   "requires minimum platform version 17.2" error. See
   [iOS build](#ios-build).

## Reporting a bug

Open an issue at
<https://github.com/iSee-Labs/meta-wearables-dat-flutter/issues> with:

- `flutter doctor -v`
- The `DatDiagnostics.raw` map from `dumpDiagnostics()` (remove your
  client token)
- The full `DatError` (`toString()`, `platformCase`, `platform`)
- Glasses model, firmware version and Meta AI app version
- Whether it reproduces with the [Mock Device Kit](mock_device.md)
