---
description: Plugin setup for 1.0 - toolchain floors, pubspec, iOS Info.plist (SPM only), Android manifest (Maven Central), Developer Mode, and first connection to Meta glasses
globs: pubspec.yaml, ios/**/Info.plist, android/**/AndroidManifest.xml, android/**/gradle.properties, **/main.dart
---

# Getting Started with meta_wearables_dat_flutter 1.0

## Prerequisites

- Flutter **>= 3.44.0** (Swift Package Manager is the default), Dart
  `^3.8.0`.
- Xcode **26.4+**, iOS deployment target **17.2+**.
- Android `minSdk 31`, `compileSdk 36`, JVM 17.
- Meta AI app **V290+**, glasses firmware **V128+**.
- Ray-Ban Meta / Oakley Meta / Meta Ray-Ban Display glasses, or Mock
  Device Kit.
- Developer Mode: Meta AI app → Settings → App Info → tap the version
  5 times, then enable Developer Mode.

## Step 1: Add the plugin

```yaml
dependencies:
  meta_wearables_dat_flutter: ^1.0.0
```

## Step 2: iOS

1. SPM only. CocoaPods is not supported for this plugin; an app can keep a
   Podfile for other pods, but this plugin resolves via SPM.
2. Set `IPHONEOS_DEPLOYMENT_TARGET = 17.2`, then run
   `flutter build ios --config-only` once so the generated plugin package
   picks it up.
3. `Info.plist`:

```xml
<key>MWDAT</key>
<dict>
  <key>AppLinkURLScheme</key>
  <string>yourappscheme://</string>
  <key>MetaAppID</key>
  <string>$(META_APP_ID)</string>
  <key>ClientToken</key>
  <string>$(CLIENT_TOKEN)</string>
  <key>TeamID</key>
  <string>$(DEVELOPMENT_TEAM)</string>
</dict>
```

- `AppLinkURLScheme` MUST end with `://` and its scheme MUST be listed in
  `CFBundleURLTypes`. Developer Mode may omit app id/token
  (finding `developerModeCredentials`).
- Also: `LSApplicationQueriesSchemes` ∋ `fb-viewapp`;
  `UISupportedExternalAccessoryProtocols` ∋ `com.meta.ar.wearable`;
  `UIBackgroundModes` ⊇ `bluetooth-central`, `external-accessory`
  (recommended `bluetooth-peripheral`, `processing`);
  `NSBluetoothAlwaysUsageDescription`, `NSLocalNetworkUsageDescription`,
  `NSBonjourServices`, `NSMicrophoneUsageDescription` (speech/audio).
- `DAMEnabled` is obsolete; remove it.

Template: [`example/ios/Runner/Info.plist`](../../example/ios/Runner/Info.plist).
The plugin registers as an application delegate and handles the callback
URL itself.

## Step 3: Android

1. `MainActivity` extends `FlutterFragmentActivity`:

   ```kotlin
   class MainActivity : FlutterFragmentActivity()
   ```

2. SDK artifacts come from **Maven Central**. No GitHub Packages, no
   `GITHUB_TOKEN`; delete old token/repo config.
3. Manifest `<application>` meta-data:
   `com.meta.wearable.mwdat.APPLICATION_ID` and
   `com.meta.wearable.mwdat.CLIENT_TOKEN`; plus the deep-link intent
   filter for your scheme. `DAM_ENABLED` is obsolete.
4. Optional: `mwdat.experimental=false` in `android/gradle.properties`
   drops the experimental Inputs/Motion/Speech AARs.

Template: [`example/android/`](../../example/android/).

## Step 4: Verify configuration

```dart
final d = await MetaWearablesDat.dumpDiagnostics();
for (final f in d.errors) debugPrint('${f.id}: ${f.fix}');
```

## Step 5: Register

```dart
await MetaWearablesDat.requestAndroidPermissions();
await MetaWearablesDat.startRegistration(); // reads Info.plist / manifest
MetaWearablesDat.registrationStateStream().listen((s) {
  // unavailable | available | registering | registered | unregistering
});
```

## Step 6: Stream

```dart
final status = await MetaWearablesDat.requestPermission(Permission.camera);
if (status == PermissionStatus.granted) {
  final textureId = await MetaWearablesDat.startStreamSession();
  // Texture(textureId: textureId)
}
```

## Production / Beta

Create a new app version for 1.0 builds in Wearables Developer Center.
See [production-release.md](production-release.md).

## Next steps

- [Registration & permissions](permissions-registration.md)
- [Camera streaming](camera-streaming.md)
- [Session lifecycle](session-lifecycle.md)
- [Device state](device-state.md)
- [Display access](display-access.md)
- [Experimental modules](experimental-modules.md)
- [Mock device testing](mockdevice-testing.md)
- [Debugging](debugging.md)
- [Sample app guide](sample-app-guide.md)
