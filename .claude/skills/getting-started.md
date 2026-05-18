---
description: Plugin setup, Flutter pubspec wiring, iOS Info.plist, Android manifest, and first connection to Meta glasses
globs: pubspec.yaml, ios/**/Info.plist, android/**/AndroidManifest.xml, **/main.dart
---

# Getting Started with meta_wearables_dat_flutter

Guide for setting up the Flutter bridge to the Meta Wearables Device
Access Toolkit (DAT) SDK in a Flutter app.

## Prerequisites

- Flutter `>= 3.24`, Dart `>= 3.0`.
- Xcode `15.0+`, iOS `17.0+` deployment target.
- Android Studio, Android `12+` (`minSdk = 31`).
- Meta AI companion app installed on the test device.
- Ray-Ban Meta glasses or Meta Ray-Ban Display glasses (or use
  Mock Device Kit for development).
- Developer Mode enabled in the Meta AI app
  (`Settings > Your glasses > Developer Mode`).

## Step 1: Add the plugin

```yaml
dependencies:
  meta_wearables_dat_flutter: ^0.2.0
```

```bash
flutter pub get
```

## Step 2: iOS configuration

1. One-time per machine:

   ```bash
   flutter config --enable-swift-package-manager
   ```

2. Open `ios/Runner.xcworkspace` and set your **Team** and **Bundle ID**
   under `Signing & Capabilities`.
3. Add the `MWDAT` dict to `ios/Runner/Info.plist`. Every key listed
   below is required by SDK 0.6.0 — missing any one throws
   `RegistrationError.configurationInvalid`.

```xml
<key>MWDAT</key>
<dict>
  <key>AppLinkURLScheme</key>
  <string>yourappscheme://</string>
  <key>MetaAppID</key>
  <string>0</string>
  <key>ClientToken</key>
  <string>developer-mode-placeholder</string>
  <key>TeamID</key>
  <string>$(DEVELOPMENT_TEAM)</string>
</dict>
```

`MetaAppID = "0"` is the developer-mode sentinel. The
`AppLinkURLScheme` value MUST end with `://` — Meta AI literally
concatenates it with the registration query string, so without the
separator the callback URL is malformed and iOS silently drops it.
The scheme itself must be RFC 3986 compliant (no underscores).

4. Add the standard Meta keys: `CFBundleURLTypes`,
   `LSApplicationQueriesSchemes` (with `fb-viewapp`),
   `UISupportedExternalAccessoryProtocols` (with `com.meta.ar.wearable`),
   `NSBluetoothAlwaysUsageDescription`,
   `NSLocalNetworkUsageDescription`, `NSBonjourServices`,
   `UIBackgroundModes` (`audio`, `bluetooth-central`,
   `bluetooth-peripheral`, `external-accessory`).

See [`example/ios/Runner/Info.plist`](../../example/ios/Runner/Info.plist)
for a working template.

## Step 3: Android configuration

1. Make `MainActivity` extend `FlutterFragmentActivity`:

   ```kotlin
   import io.flutter.embedding.android.FlutterFragmentActivity
   class MainActivity : FlutterFragmentActivity()
   ```

2. Add the deep-link intent filter and Maven config — see
   [`example/android/`](../../example/android/) for a working template.
3. Set a `GITHUB_TOKEN` env var (or `github_token=...` in
   `local.properties`) with `read:packages` scope.

## Step 4: Enable Developer Mode

Inside the Meta AI app on the same phone: `Settings → Developer Mode`.
This is required until your app is approved in the Wearables Developer
Center.

## Step 5: Initialize the plugin

The plugin self-initializes; just import and use:

```dart
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}
```

## Step 6: Register your app

```dart
await MetaWearablesDat.requestAndroidPermissions();
await MetaWearablesDat.startRegistration(
  appId: '0',                  // 0 == developer mode
  urlScheme: 'yourappscheme',
);
```

Observe registration state:

```dart
MetaWearablesDat.registrationStateStream().listen((state) {
  // RegistrationState.registered | registering | unregistered
});
```

## Step 7: Start streaming

```dart
await MetaWearablesDat.requestCameraPermission();
final textureId = await MetaWearablesDat.startStreamSession();
return Texture(textureId: textureId);
```

## Next steps

- [Registration & permissions](permissions-registration.md)
- [Camera streaming](camera-streaming.md)
- [Session lifecycle](session-lifecycle.md)
- [Mock device testing](mockdevice-testing.md)
- [Debugging](debugging.md)
- [Sample app guide](sample-app-guide.md)
