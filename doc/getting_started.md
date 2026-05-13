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
3. Add the `MWDAT` dictionary to `ios/Runner/Info.plist`. SDK 0.6.0
   validates this dict as "all-or-nothing attestation" — every one of
   the four keys below must be **present and non-empty** or the SDK
   throws `RegistrationError.configurationInvalid` (raw 1) before Meta
   AI even opens. (Meta's getting-started page currently advertises a
   two-key minimum; this is aspirational and does not work in 0.6.0.)
   ```xml
   <key>MWDAT</key>
   <dict>
     <key>AppLinkURLScheme</key>
     <!--
       MUST be RFC 3986 compliant: only letters, digits, "+", "-",
       ".", starting with a letter. Underscores break the Meta AI
       redirect even though iOS itself accepts them; you'll see
       "Internal error" in Meta AI right after Allow if the scheme
       contains `_`. Pick something short and alphanumeric, e.g.
       `myapp` or `mywearablesapp`.
     -->
     <string>yourappscheme</string>
     <!-- "0" = Developer Mode sentinel. The SDK skips Wearables
          Developer Center attestation when MetaAppID is "0", but the
          ClientToken / TeamID keys still have to exist. You must also
          turn on Developer Mode in the Meta AI app, see step 5. -->
     <key>MetaAppID</key>
     <string>0</string>
     <!-- Any non-empty placeholder is fine in Developer Mode; the SDK
          does not call out to Meta's servers when MetaAppID is "0". -->
     <key>ClientToken</key>
     <string>developer-mode-placeholder</string>
     <!-- Apple Developer Team ID. `$(DEVELOPMENT_TEAM)` is expanded by
          Xcode at build time; verify with
          `plutil -p build/ios/iphoneos/Runner.app/Info.plist`. -->
     <key>TeamID</key>
     <string>$(DEVELOPMENT_TEAM)</string>
   </dict>
   ```
   For a published app, replace `MetaAppID = "0"` with your assigned
   AppID and `ClientToken` with the matching client token from the
   [Wearables Developer Center](https://developers.meta.com/wearables/).
   Keep secrets out of source control by reading them from an xcconfig
   variable (e.g. `<string>$(META_CLIENT_TOKEN)</string>`).
4. Add the Bluetooth / Local Network usage strings, `UIBackgroundModes`,
   `NSBonjourServices`, and `UISupportedExternalAccessoryProtocols` from
   `example/ios/Runner/Info.plist`.
5. Add the two HotspotConfiguration / wifi-info entitlements from
   `example/ios/Runner/Runner.entitlements`.
6. Register your app's URL scheme under `CFBundleURLTypes` so Meta AI's
   registration callback can deep-link back into your app.
7. Add `LSApplicationQueriesSchemes` so the SDK is allowed to ask iOS
   "can I open Meta AI?" — without this, `startRegistration()` throws
   `configurationInvalid` before Meta AI even opens:
   ```xml
   <key>LSApplicationQueriesSchemes</key>
   <array>
     <string>fb-viewapp</string>
   </array>
   ```

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

## 4. Enable Developer Mode in the Meta AI app

Until your app is approved in the Wearables Developer Center, the
registration handshake will fail unless Developer Mode is enabled
**inside the Meta AI mobile app** on the same phone you're testing on:

1. Open the Meta AI app (the same one you use to manage your glasses).
2. Tap your profile/account → **Settings** → scroll to the bottom.
3. Toggle **Developer Mode** on. (On older Meta AI builds the toggle is
   under "Advanced" instead of the root settings list.)
4. Restart your Flutter app and tap "Connect glasses" again. When Meta
   AI prompts "Allow unverified app", tap **Allow**.

Without this, `startRegistration()` opens Meta AI as expected, the
"Allow unverified app" sheet appears, but the moment you tap Allow you
get an `Internal error` callback and the registration never completes.
The empty `MetaAppID` shipped in the sample is intentional - it pairs
with Developer Mode. See [Troubleshooting](troubleshooting.md) for the
full diagnosis.

## 5. Background streaming (optional)

If your app needs to keep frames flowing while the phone is locked or
in the background, opt in with
[`MetaWearablesDat.enableBackgroundStreaming`](../lib/meta_wearables_dat_flutter.dart):

```dart
await MetaWearablesDat.enableBackgroundStreaming(
  androidNotification: const BackgroundNotification(
    title: 'My App',
    text: 'Streaming from your glasses',
    channelId: 'my_app_streaming',
    channelName: 'Streaming',
  ),
);
```

### iOS

The four `UIBackgroundModes` keys (`audio`, `bluetooth-central`,
`bluetooth-peripheral`, `external-accessory`) are already in the
example apps' `Info.plist`. Copy them across to your own app. Without
them, iOS suspends the host app within a few seconds of backgrounding
and the stream stops.

### Android

`enableBackgroundStreaming` starts a foreground service of type
`connectedDevice` with the persistent notification described by
[`BackgroundNotification`](../lib/src/models/background_notification.dart).
The plugin's manifest already declares the required permissions
(`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`,
`WAKE_LOCK`, `POST_NOTIFICATIONS`) and they merge into your app
automatically.

On API 33+ the OS won't show the notification unless
`POST_NOTIFICATIONS` is granted; the plugin runtime-requests it but
host apps that want a guaranteed UI experience should request it
explicitly during onboarding (e.g. via `permission_handler` or your
own `ActivityCompat.requestPermissions` call).

Stop the service when the user no longer needs the background path:

```dart
await MetaWearablesDat.disableBackgroundStreaming();
```

## 6. Sanity check

```dart
final v = await MetaWearablesDat.getPlatformVersion();
print('Hello from $v');
```

## Next steps

- [Registration flow](registration_flow.md)
- [Streaming](streaming.md)
- [Frame processing](frame_processing.md)
- [Mock Device Kit](mock_device.md)
- [Troubleshooting](troubleshooting.md)
