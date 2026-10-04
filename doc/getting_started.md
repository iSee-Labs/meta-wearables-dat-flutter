# Getting started

> **Unofficial.** `meta_wearables_dat_flutter` is not affiliated with,
> endorsed by, or sponsored by Meta Platforms, Inc. It wraps Meta's
> official iOS and Android Wearables Device Access Toolkit (DAT) SDKs.
> "Meta", "Ray-Ban Meta" and "Oakley Meta" are trademarks of their
> respective owners.

This guide takes a Flutter app from zero to a registered app that can
talk to Meta AI glasses. Plugin 1.0.0 targets **Meta DAT 1.0.0**.

Upgrading from 0.7.x? Read the [migration guide](migration_0.7_to_1.0.md)
and the 1.0.0 entry in [`CHANGELOG.md`](../CHANGELOG.md) first: the
error model, iOS package manager, Android repository and several method
signatures changed.

## 1. Prerequisites

### Toolchain

| Requirement | Value |
| --- | --- |
| Flutter | 3.44.0 or newer (Dart `^3.8.0`) |
| iOS package manager | **Swift Package Manager only** (CocoaPods is not supported for this plugin) |
| Xcode | **26.4 or newer** (Meta's binaries are built with Swift 6.3.3) |
| iOS deployment target | **17.2** |
| Android `minSdk` | 31 (Android 12) |
| Android `compileSdk` | 36 |
| Android toolchain | JDK 17, Kotlin 2.2.21 and AGP 8.11.1 are what the plugin builds with |
| Android repository | **Maven Central** (`com.meta.wearable:mwdat-*:1.0.0`). No GitHub Packages, no `GITHUB_TOKEN`, no personal access token |
| Android host activity | `MainActivity` must extend `FlutterFragmentActivity` |

### Meta side

| Requirement | Value |
| --- | --- |
| Meta AI app | V290 or newer |
| Glasses firmware | V128 or newer |
| Supported glasses | Ray-Ban Meta, Ray-Ban Meta Optics, Oakley Meta HSTN, Oakley Meta Vanguard, Meta Ray-Ban Display |
| Wearables Developer Center | An app, and a **new app version for your DAT 1.0 builds** (versions created for 0.x builds do not carry over) |

### Enable Developer Mode in the Meta AI app

Until your app is distributed through a Wearables Developer Center
release channel, registration only works with Developer Mode on, on the
phone you test with:

1. Open the Meta AI app.
2. Go to **Settings > App Info**.
3. Tap the app version **5 times**. Developer Mode is now available.
4. Turn Developer Mode on, then restart your Flutter app.

There is no way to turn this on from code. Most "registration silently
fails" reports come from skipping this step (see
[Troubleshooting](troubleshooting.md#registration)).

## 2. Install

```yaml
dependencies:
  meta_wearables_dat_flutter: ^1.0.0 # release candidates: 1.0.0-rc.1
```

```dart
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
```

Everything, including the experimental APIs, is exported from that one
library. See [Experimental APIs](experimental.md) before using anything
marked `@experimental`.

## 3. iOS setup

### 3.1 Swift Package Manager

Swift Package Manager is Flutter's default since 3.44. If you turned it
off earlier, turn it back on:

```bash
flutter config --enable-swift-package-manager
```

The plugin resolves `facebook/meta-wearables-dat-ios` at exactly
`1.0.0` and links `MWDATCore`, `MWDATCamera`, `MWDATDisplay`,
`MWDATMockDevice`, `MWDATInputs`, `MWDATMotion` and `MWDATSpeech`. Your
app can keep a `Podfile` for other pods, but this plugin is never
resolved through CocoaPods.

### 3.2 Deployment target

Set the iOS deployment target of the Runner target to **17.2** (Xcode >
Runner > General > Minimum Deployments) and, if you have one, in
`ios/Podfile` (`platform :ios, '17.2'`). Then regenerate the Flutter
plugin package once:

```bash
flutter build ios --config-only
```

Skipping this causes the "requires minimum platform version 17.2"
error described in [Troubleshooting](troubleshooting.md#ios-build).

### 3.3 Info.plist

Add the following to `ios/Runner/Info.plist`. Replace `myglassesapp`
with your own scheme. `dumpDiagnostics()` validates every key here at
runtime (see [step 6](#6-first-run-check-the-configuration)).

```xml
<!-- Meta Wearables Device Access Toolkit -->
<key>MWDAT</key>
<dict>
  <!-- Must end with "://". Its scheme must also be in CFBundleURLTypes.
       Letters, digits, "+", "-", "." only, starting with a letter (no underscores). -->
  <key>AppLinkURLScheme</key>
  <string>myglassesapp://</string>
  <!-- "0" = Developer Mode. For release channels use the values from
       Wearables Developer Center. -->
  <key>MetaAppID</key>
  <string>0</string>
  <key>ClientToken</key>
  <string>developer-mode-placeholder</string>
  <key>TeamID</key>
  <string>$(DEVELOPMENT_TEAM)</string>
  <!-- Optional opt-outs (reported as analyticsOptOut / crashReportingOptOut
       by dumpDiagnostics). -->
  <key>Analytics</key>
  <dict>
    <key>OptOut</key>
    <true/>
  </dict>
</dict>

<!-- The Meta AI callback comes back on this scheme (without "://"). -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myglassesapp</string>
    </array>
  </dict>
</array>

<!-- Lets the SDK check that the Meta AI app is installed. -->
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
  <!-- Required: the DAT SDK checks these two at runtime. -->
  <string>bluetooth-central</string>
  <string>external-accessory</string>
  <!-- Recommended (declared by Meta's samples). -->
  <string>bluetooth-peripheral</string>
  <string>processing</string>
  <!-- Only if you call enableBackgroundStreaming(): the plugin keeps an
       audio session alive in the background. -->
  <string>audio</string>
</array>

<key>NSBluetoothAlwaysUsageDescription</key>
<string>Connects to your Meta AI glasses.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Finds and connects to your glasses over Wi-Fi.</string>
<key>NSBonjourServices</key>
<array>
  <string>_bonjour._tcp</string>
</array>
<!-- Needed with the "audio" background mode, Speech, or in-stream audio. -->
<key>NSMicrophoneUsageDescription</key>
<string>Uses the microphone of your glasses.</string>
```

Notes:

- `DAMEnabled` is obsolete in DAT 1.0. Remove it if you carried it over
  (finding `damEnabledIgnored`).
- In Developer Mode `MetaAppID` can be `0`; `dumpDiagnostics()` then
  reports the informational finding `developerModeCredentials`. Once
  `MetaAppID` is a real id, `ClientToken` and `TeamID` must both be set.
- `$(DEVELOPMENT_TEAM)` is expanded by Xcode from the signing settings.
  Set your team under Runner > Signing & Capabilities.
- The example app also adds the
  `com.apple.developer.networking.HotspotConfiguration` and
  `com.apple.developer.networking.wifi-info` entitlements, as Meta's
  CameraAccess sample does. See
  [`example/ios/Runner/Runner.entitlements`](../example/ios/Runner/Runner.entitlements).

### 3.4 Forward the Meta AI callback (scene-based apps)

Flutter apps created with recent templates use a `UIScene` lifecycle
(`UIApplicationSceneManifest` in `Info.plist` plus
`ios/Runner/SceneDelegate.swift`). iOS then delivers the Meta AI
callback URL to the scene delegate, which plugins cannot hook into.
Forward it to the plugin by posting the `MetaWearablesDatHandleURL`
notification:

```swift
import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    forward(connectionOptions.urlContexts)
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    forward(URLContexts)
  }

  private func forward(_ contexts: Set<UIOpenURLContext>) {
    for context in contexts {
      NotificationCenter.default.post(
        name: Notification.Name("MetaWearablesDatHandleURL"),
        object: nil,
        userInfo: ["url": context.url]
      )
    }
  }
}
```

Apps with the classic `AppDelegate` lifecycle (no scene manifest) skip
this step: the plugin is registered as an application delegate and
receives the URL automatically. Reference:
[`example/ios/Runner/SceneDelegate.swift`](../example/ios/Runner/SceneDelegate.swift).

## 4. Android setup

### 4.1 `MainActivity`

```kotlin
package com.example.myglassesapp

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

Meta's permission flow needs a `ComponentActivity`. With a plain
`FlutterActivity`, `requestPermission` fails with
`PermissionErrorCase.missingFragmentActivity` and diagnostics report
`activityNotComponentActivity`.

### 4.2 `android/app/build.gradle.kts`

```kotlin
android {
    compileSdk = flutter.compileSdkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    defaultConfig {
        minSdk = 31
    }
}
```

Meta's artifacts come from Maven Central, which Flutter projects
already list. **Remove** any GitHub Packages repository
(`maven.pkg.github.com/facebook/meta-wearables-dat-android`),
`credentials { ... }` block, `github_token` entry in `local.properties`
and `GITHUB_TOKEN` setup left over from 0.x.

### 4.3 `AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Required by the DAT SDK. -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:label="My Glasses App"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <!-- "0" / "0" = Developer Mode. For release channels use the
             application id and client token from Wearables Developer Center. -->
        <meta-data
            android:name="com.meta.wearable.mwdat.APPLICATION_ID"
            android:value="0" />
        <meta-data
            android:name="com.meta.wearable.mwdat.CLIENT_TOKEN"
            android:value="0" />
        <!-- Optional opt-outs. -->
        <meta-data
            android:name="com.meta.wearable.mwdat.ANALYTICS_OPT_OUT"
            android:value="true" />

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
            <!-- Meta AI registration callback. The plugin forwards it to
                 the SDK from onAttachedToActivity / onNewIntent. -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.BROWSABLE" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:scheme="myglassesapp" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

Notes:

- `com.meta.wearable.mwdat.DAM_ENABLED` is obsolete in DAT 1.0. Remove
  it (finding `damEnabledIgnored`). The 0.7 advice to add it no longer
  applies.
- The plugin's own manifest merges `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `WAKE_LOCK`,
  `POST_NOTIFICATIONS` and the background-streaming `<service>` into
  your app. You do not declare them.
- To keep production credentials out of source control, use a manifest
  placeholder such as `android:value="${mwdat_application_id}"` and set
  it from `manifestPlaceholders` in Gradle.
- To drop the experimental Inputs, Motion and Speech modules from your
  APK, see [Experimental APIs](experimental.md#android-opting-out-of-the-experimental-modules).

## 5. Wearables Developer Center

Developer Mode is enough for local development. To hand builds to
testers:

1. Create (or open) your app in the Wearables Developer Center.
2. Create a **new app version for your DAT 1.0 build**.
3. Copy the app id and client token into `MWDAT` (iOS) and the
   `APPLICATION_ID` / `CLIENT_TOKEN` meta-data (Android). Set `TeamID`
   on iOS.
4. Distribute through the invite-only **Beta release channel**.

Meta's iOS guide still states that publishing DAT apps to the App Store
is not currently supported. Apps that use any
[experimental API](experimental.md) cannot ship to production release
channels. See the [production checklist](production_checklist.md).

## 6. First run: check the configuration

Call `dumpDiagnostics()` once at startup in debug builds. It validates
Info.plist or AndroidManifest.xml against what DAT 1.0 needs, and
reports versions, devices and the native resources the plugin holds.

```dart
import 'package:flutter/foundation.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

Future<void> checkDatSetup() async {
  final diagnostics = await MetaWearablesDat.dumpDiagnostics();
  debugPrint(
    'DAT ${diagnostics.sdkVersion}, plugin ${diagnostics.pluginVersion} '
    'on ${diagnostics.platform}, registration: '
    '${diagnostics.registrationState.name}',
  );
  for (final finding in diagnostics.findings) {
    debugPrint('$finding\n  fix: ${finding.fix}');
  }
  assert(
    diagnostics.errors.isEmpty,
    'Fix the DAT configuration errors above before continuing.',
  );
}
```

Every finding id and its fix is listed in
[Troubleshooting](troubleshooting.md#diagnostics-findings).

## 7. Register and stream

```dart
// 1. Android: BLUETOOTH_CONNECT runtime permission (returns true on iOS).
await MetaWearablesDat.requestAndroidPermissions();

// 2. Register with the Meta AI app (opens Meta AI).
MetaWearablesDat.registrationStateStream().listen((state) {
  debugPrint('registration: ${state.name}');
});
await MetaWearablesDat.startRegistration();

// 3. Once registered, ask for camera access (shown in Meta AI).
final camera = await MetaWearablesDat.requestPermission(Permission.camera);

// 4. Stream into a Texture widget.
if (camera.isGranted) {
  final textureId = await MetaWearablesDat.startStreamSession();
  // Texture(textureId: textureId)
}

// 5. Release everything.
await MetaWearablesDat.stopStreamSession();
```

## No glasses yet?

Enable the [Mock Device Kit](mock_device.md) to develop and run
integration tests against simulated glasses on a simulator or emulator.

## Next steps

- [Registration flow](registration_flow.md)
- [Streaming](streaming.md)
- [Frame processing](frame_processing.md)
- [Device state](device_state.md)
- [Display access](display_access.md)
- [Mock Device Kit](mock_device.md)
- [Experimental APIs](experimental.md)
- [Production checklist](production_checklist.md)
- [Troubleshooting](troubleshooting.md)

Sample apps: [`samples/camera_access/`](../samples/camera_access/) and
[`samples/display_access/`](../samples/display_access/).
