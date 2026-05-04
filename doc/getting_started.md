# Getting started

> **Unofficial.** `meta_wearables_dat_flutter` is not endorsed by Meta. It
> wraps Meta's official iOS and Android DAT SDKs (Apache-2.0). See `NOTICE`
> for attribution.

## 1. Install the plugin

```yaml
dependencies:
  meta_wearables_dat_flutter: ^0.1.0
```

## 2. iOS setup

1. Enable Swift Package Manager once per machine:
   ```bash
   flutter config --enable-swift-package-manager
   ```
2. Open `ios/Runner.xcworkspace` and set your **Team** and **Bundle ID**
   under "Signing & Capabilities".
3. Add the `MWDAT` dictionary to `ios/Runner/Info.plist`:
   ```xml
   <key>MWDAT</key>
   <dict>
     <key>AppLinkURLScheme</key>
     <string>your_url_scheme</string>
     <key>MetaAppID</key>
     <string>0</string><!-- "0" works for Developer Mode -->
     <key>ClientToken</key>
     <string></string>
     <key>TeamID</key>
     <string>YOUR_APPLE_TEAM_ID</string>
   </dict>
   ```
4. Add the Bluetooth / Local Network usage strings, `UIBackgroundModes`,
   `NSBonjourServices`, and `UISupportedExternalAccessoryProtocols` from
   `example/ios/Runner/Info.plist`.
5. Add the two HotspotConfiguration / wifi-info entitlements from
   `example/ios/Runner/Runner.entitlements`.
6. Register your app's URL scheme under `CFBundleURLTypes` so Meta AI's
   registration callback can deep-link back into your app.

Minimum iOS version: **17.0**.

## 3. Android setup

1. Make `MainActivity` extend `FlutterFragmentActivity`:
   ```kotlin
   import io.flutter.embedding.android.FlutterFragmentActivity

   class MainActivity : FlutterFragmentActivity()
   ```
   `FlutterFragmentActivity` is a `ComponentActivity`, which the camera
   permission contract requires.
2. Declare permissions and the deep-link intent-filter in
   `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.BLUETOOTH" />
   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
   <uses-permission android:name="android.permission.INTERNET" />

   <application ...>
     <meta-data
       android:name="com.meta.wearable.mwdat.APPLICATION_ID"
       android:value="0" /><!-- "0" = Developer Mode -->
     <meta-data
       android:name="com.meta.wearable.mwdat.CLIENT_TOKEN"
       android:value="" />

     <activity android:name=".MainActivity"
       android:launchMode="singleTop" ...>
       <intent-filter>
         <action android:name="android.intent.action.VIEW" />
         <category android:name="android.intent.category.BROWSABLE" />
         <category android:name="android.intent.category.DEFAULT" />
         <data android:scheme="your_url_scheme" />
       </intent-filter>
     </activity>
   </application>
   ```
3. Add Meta's GitHub Packages Maven to your app's `settings.gradle.kts`
   (`dependencyResolutionManagement.repositories`) — see
   `example/android/settings.gradle.kts` for the exact snippet. A GitHub
   PAT with `read:packages` scope is required (set `GITHUB_TOKEN` or
   `github_token=...` in `local.properties`).

Minimum Android: **`minSdk = 31`** (Android 12).

## 4. Sanity check

```dart
final v = await MetaWearablesDat.getPlatformVersion();
print('Hello from $v');
```

## Next steps

- [Registration flow](registration_flow.md)
- [Streaming](streaming.md)
- [Mock Device Kit](mock_device.md)
