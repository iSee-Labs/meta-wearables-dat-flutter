> **Unofficial.** This plugin is not affiliated with, endorsed by, sponsored
> by, or officially connected to Meta Platforms, Inc. "Meta", "Ray-Ban Meta",
> "Oakley Meta", and "Ray-Ban Display" are trademarks of their respective
> owners.

# meta_wearables_dat_flutter

[![pub package](https://img.shields.io/pub/v/meta_wearables_dat_flutter.svg)](https://pub.dev/packages/meta_wearables_dat_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![Flutter](https://img.shields.io/badge/flutter-%3E%3D3.44.0-blue.svg)](https://flutter.dev)

A Flutter plugin for Meta's Wearables Device Access Toolkit (DAT) on iOS and
Android. It links Meta's official native SDKs and exposes one Dart API for
Ray-Ban Meta, Oakley Meta, and Meta Ray-Ban Display glasses: registration,
permissions, device state, camera streaming into a Flutter `Texture`, photo
capture, on-glasses Display UI, the Mock Device Kit, and Meta's experimental
modules.

It is a bridge, not a reimplementation. Meta's SDKs are closed-source
binaries that this plugin depends on.

## Status

| | |
|---|---|
| Plugin version | **1.0.0** |
| Meta DAT version | **1.0.0** (Meta's first stable, supported release) |
| Distribution | Developer Mode and the invite-only **Beta release channel** in the [Wearables Developer Center](https://wearables.developer.meta.com/). Meta does not yet support publishing DAT apps to the App Store. |
| Developer Center | Create a **new app version** for builds made with DAT 1.0. |
| Verification | 1.0.0 is verified against Meta's Mock Device Kit on the iOS Simulator and Android emulator, plus unit tests on every layer. The real-glasses matrix in [`doc/release_checklist.md`](doc/release_checklist.md) is still open; report hardware findings as issues. |

## Features

| Feature | iOS | Android | Notes |
|---|:-:|:-:|---|
| Registration (app-initiated) | Yes | Yes | `startRegistration()`; the plugin hands the callback URL to the SDK |
| Registration started from Meta AI | Yes | Yes | `registrationRequestStream()` |
| Permissions (camera, microphone) | Yes | Yes | `requestPermission(Permission.camera)` |
| Device list and live state | Yes | Yes | Battery, charging, wear, hinge, thermal, link, compatibility |
| Camera preview, raw codec, Flutter texture | Yes | Yes | No frames over the method channel |
| Camera preview, `hvc1` codec, Flutter texture | Yes | Yes | VideoToolbox on iOS, MediaCodec on Android |
| Opt-in per-frame stream | Yes | Yes | `videoFramesStream()`, gated on listeners |
| Photo capture (JPEG, HEIC) | Yes | Yes | `capturePhoto()` |
| Background streaming | Yes | Yes | Audio session on iOS, foreground service on Android |
| Display (Meta Ray-Ban Display) | Yes | Yes | Declarative component DSL with callbacks |
| Diagnostics | Yes | Yes | Info.plist / manifest findings, resource ledger |
| Mock Device Kit | Yes | Yes | Simulated glasses, camera feed, permissions, display |
| Experimental modules | Yes | Yes | Inputs, Motion, Speech, voice invocations, high-res photo, in-stream audio |

## Requirements

| | Minimum |
|---|---|
| Flutter | 3.44.0 (Dart 3.8) |
| iOS | 17.2, **Swift Package Manager only** (CocoaPods is not supported for this plugin) |
| Xcode | 26.4 (Meta's binaries are built with Swift 6.3) |
| Android | `minSdk 31`, `MainActivity` extends `FlutterFragmentActivity` |
| Android SDK source | Maven Central (no GitHub token) |
| Meta AI app | V290 |
| Glasses firmware | V128 |

Turn on Developer Mode in the Meta AI app: **Settings > App Info**, tap the
version number five times.

## Install

```yaml
dependencies:
  meta_wearables_dat_flutter: ^1.0.0
```

```bash
flutter pub get
```

## iOS setup

1. Set the deployment target to **17.2** in Xcode (Runner target > General >
   Minimum Deployments).
2. Swift Package Manager is Flutter's default since 3.44. If you turned it
   off, run `flutter config --enable-swift-package-manager`.
3. Add the keys below to `ios/Runner/Info.plist`. Replace `myapp` with your
   own scheme (letters, digits, `+`, `-`, `.`; no underscores).

```xml
<key>MWDAT</key>
<dict>
  <!-- Must end with "://". Meta AI appends the callback query to it. -->
  <key>AppLinkURLScheme</key>
  <string>myapp://</string>
  <!-- "0" in Developer Mode; your app id from the Developer Center otherwise. -->
  <key>MetaAppID</key>
  <string>0</string>
  <key>ClientToken</key>
  <string>developer-mode-placeholder</string>
  <key>TeamID</key>
  <string>$(DEVELOPMENT_TEAM)</string>
</dict>

<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp</string>
    </array>
  </dict>
</array>

<key>LSApplicationQueriesSchemes</key>
<array>
  <string>fb-viewapp</string>
</array>

<key>UISupportedExternalAccessoryProtocols</key>
<array>
  <string>com.meta.ar.wearable</string>
</array>

<key>UIBackgroundModes</key>
<array>
  <string>bluetooth-central</string>    <!-- required -->
  <string>external-accessory</string>   <!-- required -->
  <string>bluetooth-peripheral</string> <!-- recommended -->
  <string>processing</string>           <!-- recommended -->
  <string>audio</string>                <!-- for enableBackgroundStreaming() -->
</array>

<key>NSBluetoothAlwaysUsageDescription</key>
<string>Connects to your glasses.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Finds and connects to your glasses over Wi-Fi.</string>
<key>NSBonjourServices</key>
<array>
  <string>_bonjour._tcp</string>
</array>
<!-- Needed when you declare the audio background mode or use Speech. -->
<key>NSMicrophoneUsageDescription</key>
<string>Uses the glasses microphone.</string>
```

`DAMEnabled` is obsolete in DAT 1.0; remove it. Apps that use a scene-based
lifecycle (`SceneDelegate`) must forward incoming URLs to the plugin; see
[`doc/registration_flow.md`](doc/registration_flow.md). Run
`MetaWearablesDat.dumpDiagnostics()` to check the result.

## Android setup

1. Make `MainActivity` extend `FlutterFragmentActivity`:

   ```kotlin
   import io.flutter.embedding.android.FlutterFragmentActivity

   class MainActivity : FlutterFragmentActivity()
   ```

2. Set `minSdk = 31` in `android/app/build.gradle.kts`.
3. Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.INTERNET" />

<application ...>
  <!-- "0" in Developer Mode; Developer Center values otherwise. -->
  <meta-data
      android:name="com.meta.wearable.mwdat.APPLICATION_ID"
      android:value="0" />
  <meta-data
      android:name="com.meta.wearable.mwdat.CLIENT_TOKEN"
      android:value="0" />

  <activity android:name=".MainActivity" android:launchMode="singleTop" ...>
    <!-- Registration callback from the Meta AI app. -->
    <intent-filter>
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.BROWSABLE" />
      <category android:name="android.intent.category.DEFAULT" />
      <data android:scheme="myapp" />
    </intent-filter>
  </activity>
</application>
```

Meta's Android SDK now resolves from Maven Central. You do not need a GitHub
token, a GitHub Packages repository, or `DAM_ENABLED`. The plugin merges the
foreground-service permissions and the background-streaming service into
your manifest.

## Quick start

```dart
import 'package:flutter/widgets.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

Future<int?> startCamera() async {
  // Android: BLUETOOTH_CONNECT and SDK initialisation. iOS: returns true.
  await MetaWearablesDat.requestAndroidPermissions();

  // Register once. The Meta AI app opens and calls back into your app.
  if (await MetaWearablesDat.getRegistrationState() !=
      RegistrationState.registered) {
    await MetaWearablesDat.startRegistration();
    await MetaWearablesDat.registrationStateStream()
        .firstWhere((s) => s == RegistrationState.registered);
  }

  // Camera permission is granted in the Meta AI app.
  final status = await MetaWearablesDat.requestPermission(Permission.camera);
  if (!status.isGranted) return null;

  // Returns a texture id for Texture(textureId: ...).
  return MetaWearablesDat.startStreamSession(
    config: const StreamSessionConfig(
      quality: StreamQuality.high, // 720 x 1280
      frameRate: StreamFrameRate.fps24,
      videoCodec: VideoCodec.raw,
    ),
  );
}

Widget preview(int textureId) => AspectRatio(
  aspectRatio: 9 / 16,
  child: Texture(textureId: textureId),
);
```

Watch devices and their state:

```dart
MetaWearablesDat.devicesStream().listen((devices) {
  for (final d in devices) {
    debugPrint('${d.name}: ${d.linkState.name}, battery ${d.batteryLevel}, '
        '${d.donState.name}, thermal ${d.thermalLevel.name}');
  }
});

// One device; emits the current snapshot first, then changes.
MetaWearablesDat.deviceStateStream(uuid).listen((device) { /* ... */ });
```

Accept registrations started from the Meta AI app:

```dart
MetaWearablesDat.registrationRequestStream().listen((request) {
  request.continueRegistration(); // or request.cancel(); expires after 5 min
});
```

Capture a photo and stop:

```dart
final photo = await MetaWearablesDat.capturePhoto(format: PhotoFormat.jpeg);
// photo.bytes, photo.format (the actual encoding)

await MetaWearablesDat.stopStreamSession(); // also releases the texture
```

More: [`doc/streaming.md`](doc/streaming.md),
[`doc/frame_processing.md`](doc/frame_processing.md),
[`doc/device_state.md`](doc/device_state.md).

## Display (Meta Ray-Ban Display)

```dart
await MetaWearablesDat.startDisplaySession();

final warnings = await MetaWearablesDat.sendDisplayView(
  FlexBox(
    spacing: 12,
    padding: 24,
    children: [
      const DisplayText('Hello from Flutter', style: DisplayTextStyle.heading),
      const DisplayIcon(DisplayIconName.checkmark),
      DisplayButtonGroup(
        buttons: [
          DisplayButton(
            label: 'Done',
            onClick: MetaWearablesDat.stopDisplaySession,
          ),
        ],
      ),
    ],
  ),
);
// warnings lists values the SDK substituted; they are not fatal.

MetaWearablesDat.displayStateStream().listen((state) => debugPrint(state.name));
```

The canvas is 600 x 600. Every `sendDisplayView` replaces the whole view.
The Back gesture on the glasses ends the display session. `VideoPlayer` plays
HTTPS MP4 and must be the root view. Use `DisplayNode.validate()` to check a
tree before sending it. Camera, display, and experimental capabilities share
one device session. See [`doc/display_access.md`](doc/display_access.md).

## Error handling

Every failure is a subclass of the sealed `DatError`. Each error has a
`category` (for example `STREAM_ERROR`), a `code` (the case name, for example
`hingesClosed`), a typed `reason` on the concrete subclasses, a `message`, and
a `recoveryAction`.

```dart
try {
  await MetaWearablesDat.startStreamSession();
} on DatError catch (error) {
  final text = switch (error) {
    DeviceSessionError(reason: DeviceSessionErrorCase.noEligibleDevice) =>
      'Connect and wear your glasses.',
    StreamError(reason: StreamErrorCase.hingesClosed) => 'Open the glasses.',
    StreamError(reason: StreamErrorCase.thermalHot) => 'The glasses are hot.',
    PermissionError() => 'Allow camera access in the Meta AI app.',
    _ => '${error.category}/${error.code}: ${error.message}',
  };
  debugPrint(text);

  switch (error.recoveryAction) {
    case DatRecoveryAction.openFirmwareUpdate:
      await MetaWearablesDat.openFirmwareUpdate();
    case DatRecoveryAction.openDatGlassesAppUpdate:
      await MetaWearablesDat.openDatGlassesAppUpdate();
    default:
      break;
  }
}
```

Asynchronous errors arrive on `registrationErrorStream()`,
`deviceSessionErrorStream()`, `streamErrorStream()`, and
`displayErrorStream()`.

## Diagnostics

```dart
final diagnostics = await MetaWearablesDat.dumpDiagnostics();
debugPrint('${diagnostics.platform} plugin ${diagnostics.pluginVersion}, '
    'DAT ${diagnostics.sdkVersion}');
for (final finding in diagnostics.findings) {
  debugPrint('$finding\n  fix: ${finding.fix}');
}
```

`findings` lists configuration problems with a stable `id`, a `severity`, and
a `fix`. Examples: `appLinkUrlSchemeSuffix` (scheme does not end with `://`),
`appLinkUrlSchemeNotRegistered`, `externalAccessoryProtocol`,
`backgroundMode.external-accessory`, `damEnabledIgnored`, and
`developerModeCredentials` (informational). `diagnostics.errors` returns only
the blocking ones. `resources` counts native textures, listeners, and
sessions; `diagnostics.isIdle` is `true` when everything is released.

## Experimental APIs

Meta marks some DAT 1.0 modules as experimental. The plugin exposes them with
`@experimental` and excludes them from semantic versioning.

> **Warning:** apps that use experimental APIs can be built and tested in
> Developer Mode and Beta release channels, but **cannot ship to production
> release channels**.

| Capability | API |
|---|---|
| Inputs (touchpad, buttons, Meta Neural Band) | `startInputs`, `inputEventsStream`, `stopInputs` |
| Motion (head motion samples) | `startMotion(samplingRate:)`, `motionSamplesStream`, `stopMotion` |
| Speech (on-device transcription) | `startSpeech`, `transcriptionStream`, `stopSpeech` |
| Voice invocations ("Hey Meta") | `startVoiceInvocations`, `voiceInvocationsStream`, `stopVoiceInvocations` |
| High-resolution photo | `captureHighResPhoto(resolution:, quality:)`, `photoTransferProgressStream` |
| In-stream audio | `StreamSessionConfig(audio: AudioStreamConfig())`, `audioFramesStream` |

```dart
await MetaWearablesDat.startInputs();
MetaWearablesDat.inputEventsStream().listen((event) {
  if (event is NavInputEvent) debugPrint('nav ${event.direction.name}');
});
```

The main library exports the experimental types too.
`package:meta_wearables_dat_flutter/experimental.dart` exports only the
experimental types, so you can use it as a marker for experimental usage
(the analyzer reports it as unnecessary next to the main import).

On Android you can drop the experimental AARs with this line in your app's
`android/gradle.properties`:

```properties
mwdat.experimental=false
```

Experimental calls then throw a `DatPluginError` with category
`EXPERIMENTAL_NOT_LINKED` (`isExperimentalNotLinked` is `true`). iOS always
links the experimental modules. See [`doc/experimental.md`](doc/experimental.md).

## Testing with the Mock Device Kit

```dart
await MetaWearablesDat.enableMockDevice();
final glasses =
    await MetaWearablesDat.pairMockGlasses(MockGlassesModel.rayBanMeta);

// A mock device appears in devicesStream() after power on and unfold.
await MetaWearablesDat.mockPowerOn(glasses.uuid);
await MetaWearablesDat.mockUnfold(glasses.uuid);
await MetaWearablesDat.mockDon(glasses.uuid);

await MetaWearablesDat.setMockCameraFeed(glasses.uuid, h265VideoPath);
await MetaWearablesDat.setMockPermission(
  Permission.camera,
  PermissionStatus.granted,
);

final textureId =
    await MetaWearablesDat.startStreamSession(deviceUUID: glasses.uuid);
// ...
await MetaWearablesDat.stopStreamSession();
await MetaWearablesDat.disableMockDevice();
```

You can also simulate battery, charging, thermal level, touchpad taps, and
capture failures, and preview the display with `startMockTestServer()`. Up to
three mock devices can be paired. Disable the Mock Device Kit before you ship.
See [`doc/mock_device.md`](doc/mock_device.md).

## Known issues

- **Enumerating all Objective-C classes crashes on iOS 18 (Meta SDK
  issue).** `MWDATCore` 1.0.0 weakly links types that exist only on iOS 26
  (from the `Network` and `WiFiAware` frameworks). Any call to
  `objc_copyClassList` on iOS 17.2 to 18.x forces those classes to
  initialize and aborts the app with "Failed to look up symbolic reference".
  Normal plugin use is unaffected; the integration tests pass on iOS 18.
  Confirmed on iOS 18.0 and 18.5 simulators, not on iOS 26.5 or 27.
  Before shipping to iOS 18 users, check that no SDK in your app
  enumerates every class (some analytics, crash-reporting and
  dependency-injection libraries do), and run XCTest bundles on an iOS 26+
  simulator.
- **Raw frames pause in the iOS background.** Use `VideoCodec.hvc1` and
  `enableBackgroundStreaming()` to keep streaming.
- **`sendMockDisplayClick`** returns `true`, but Meta has not documented the
  identifier format, so it may not fire `onClick`.
- **Xcode build after `flutter pub get`** can fail with "requires minimum
  platform version 17.2 ... but this target supports 15.0". Set the app's iOS
  deployment target to 17.2 and run `flutter build ios --config-only` once.

More in [`doc/troubleshooting.md`](doc/troubleshooting.md).

## Samples

| Sample | Shows |
|---|---|
| [`samples/camera_access`](samples/camera_access) | Flutter port of Meta's Camera Access sample: registration, streaming, photo and frame capture, Mock Device Kit menu. |
| [`samples/display_access`](samples/display_access) | Flutter port of Meta's Display Access sample: tutorial screens on Ray-Ban Display with button groups and video. |
| [`samples/glasses_companion`](samples/glasses_companion) | DAT 1.0 features in one app: live device state, update deep links, diagnostics findings, hvc1 preview, high-res photo, a display card, mock controls and the experimental modules. |

## Documentation

| Guide | Topic |
|---|---|
| [`getting_started.md`](doc/getting_started.md) | Install, Info.plist, manifest, Developer Mode |
| [`registration_flow.md`](doc/registration_flow.md) | Registration, callback URLs, Meta-AI-initiated requests |
| [`streaming.md`](doc/streaming.md) | Texture preview, codecs, photos, background streaming |
| [`frame_processing.md`](doc/frame_processing.md) | `videoFramesStream`, pixel formats, costs |
| [`display_access.md`](doc/display_access.md) | Display DSL and callbacks |
| [`device_state.md`](doc/device_state.md) | Battery, wear, hinge, thermal, compatibility |
| [`mock_device.md`](doc/mock_device.md) | Mock Device Kit |
| [`experimental.md`](doc/experimental.md) | Inputs, Motion, Speech, voice invocations |
| [`troubleshooting.md`](doc/troubleshooting.md) | Common problems |
| [`production_checklist.md`](doc/production_checklist.md) | Before you distribute |
| [`release_checklist.md`](doc/release_checklist.md) | Releasing this plugin |
| [`migration_0.7_to_1.0.md`](doc/migration_0.7_to_1.0.md) | Upgrading from 0.7.x |

Meta's documentation: <https://wearables.developer.meta.com/docs/develop/>.
Changes: [`CHANGELOG.md`](CHANGELOG.md).

## Compatibility

The plugin's major.minor version tracks Meta's DAT version. The patch number
is the plugin's own.

| Plugin | Meta DAT (iOS and Android) |
|---|---|
| 1.0.x | 1.0.0 |
| 0.7.x | 0.7.0 |

Upgrading from 0.7.x: [`doc/migration_0.7_to_1.0.md`](doc/migration_0.7_to_1.0.md).

## Developer terms and data collection

By using the Wearables Device Access Toolkit you agree to the
[Meta Wearables Developer Terms](https://wearables.developer.meta.com/terms)
and the [Acceptable Use Policy](https://wearables.developer.meta.com/acceptable-use-policy).
Meta may collect information about how users' devices communicate with your
app. To opt out of analytics, add `Analytics > OptOut = true` inside the
`MWDAT` dict on iOS, and
`<meta-data android:name="com.meta.wearable.mwdat.ANALYTICS_OPT_OUT" android:value="true" />`
on Android.

## License and maintainer

[MIT](LICENSE). Copyright 2026 iSee Labs. Maintained by Talha Ordukaya.
Issues: <https://github.com/iSee-Labs/meta-wearables-dat-flutter/issues>.

Meta's SDKs ([iOS](https://github.com/facebook/meta-wearables-dat-ios),
[Android](https://github.com/facebook/meta-wearables-dat-android)) are linked
as dependencies, not redistributed, and remain under Meta's license terms.
See [`NOTICE`](NOTICE).

"Meta", "Ray-Ban Meta", "Oakley Meta", and "Ray-Ban Display" are trademarks
of Meta Platforms, Inc. and/or its affiliates. This project is not affiliated
with Meta.
