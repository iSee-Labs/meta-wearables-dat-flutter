# Migrating from 0.7.x to 1.0.0

Plugin 1.0.0 moves from Meta DAT 0.7.0 to Meta DAT 1.0.0. The upgrade has
three parts: toolchain and platform configuration, the Wearables Developer
Center, and Dart code. Most renamed APIs keep a deprecated shim, so you can
upgrade first and clean up deprecations afterwards. Removed APIs and the
error model need changes before your app compiles or behaves correctly.

## 1. Update the toolchain

| | 0.7.x | 1.0.0 |
|---|---|---|
| Flutter | 3.32.0+ (Dart ^3.5.0) | **3.44.0+** (Dart ^3.8.0) |
| Xcode | not pinned | **26.4+** (Meta's binaries are built with Swift 6.3) |
| iOS deployment target | 17.0 | **17.2** |
| iOS dependency manager | CocoaPods or SPM | **Swift Package Manager only** |
| Android `compileSdk` (plugin module) | 35 | 36 (your app can keep `flutter.compileSdkVersion`) |
| Android `minSdk` | 31 | 31 |
| Android SDK source | GitHub Packages (token) | **Maven Central** (no token) |
| Meta AI app | not pinned | V290+ |
| Glasses firmware | not pinned | V128+ |

```yaml
dependencies:
  meta_wearables_dat_flutter: ^1.0.0
```

## 2. iOS

1. Set the Runner target's minimum deployment to **iOS 17.2** in Xcode. If
   you still have a `Podfile`, set `platform :ios, '17.2'` there too.
2. Make sure Swift Package Manager is on. It is the default in Flutter 3.44;
   if you turned it off, run:

   ```bash
   flutter config --enable-swift-package-manager
   ```

   Your app can keep a `Podfile` for other plugins, but this plugin resolves
   only through SPM.
3. Run `flutter build ios --config-only` (or `flutter run`) once so Flutter
   regenerates the plugin package with your deployment target. Skipping this
   can produce "requires minimum platform version 17.2 for the iOS platform,
   but this target supports 15.0" when you build from Xcode.
4. Update `Info.plist`:
   - Remove `DAMEnabled` from the `MWDAT` dict. It is obsolete in DAT 1.0.
   - Check that `MWDAT > AppLinkURLScheme` ends with `://` and that its
     scheme (without `://`) is in `CFBundleURLTypes`.
   - `UIBackgroundModes` must contain `bluetooth-central` and
     `external-accessory`. `bluetooth-peripheral` and `processing` are
     recommended. Keep `audio` if you call `enableBackgroundStreaming()`.
   - Add `NSMicrophoneUsageDescription` if you declare the `audio`
     background mode or use experimental Speech.
5. Keep your `SceneDelegate` URL forwarding if you have one; it is unchanged.

`MetaWearablesDat.dumpDiagnostics()` reports anything still missing (see
step 6).

## 3. Android

1. Delete the GitHub Packages repository from `android/settings.gradle.kts`
   (and from `android/build.gradle.kts` if you added it there):

   ```kotlin
   // Delete this whole block.
   maven {
       url = uri("https://maven.pkg.github.com/facebook/meta-wearables-dat-android")
       credentials { ... }
   }
   ```

   Make sure `mavenCentral()` is in the repository list (it is in Flutter's
   default template).
2. Delete `github_token=...` from `android/local.properties`, and stop
   exporting `GITHUB_TOKEN` for this build. Remove any CI secret you used
   only for this.
3. Remove the `com.meta.wearable.mwdat.DAM_ENABLED` `<meta-data>` entry from
   `AndroidManifest.xml`. Keep `APPLICATION_ID` and `CLIENT_TOKEN`.
4. `MainActivity` must still extend `FlutterFragmentActivity`.
5. Optional: to leave Meta's experimental AARs (`mwdat-inputs`,
   `mwdat-motion`, `mwdat-speech`) out of your APK, add to
   `android/gradle.properties`:

   ```properties
   mwdat.experimental=false
   ```

## 4. Wearables Developer Center

Create a **new app version** in the
[Wearables Developer Center](https://wearables.developer.meta.com/) for builds
made with DAT 1.0. Distribute through Developer Mode or the Beta release
channel; Meta does not yet support publishing DAT apps to the App Store.

## 5. Update Dart code

### Renamed or replaced APIs

| 0.7.x | 1.0.0 |
|---|---|
| `startStreamSession(fps: 30, quality: StreamQuality.high, videoCodec: VideoCodec.hvc1, deviceKinds: {...})` | `startStreamSession(config: const StreamSessionConfig(frameRate: StreamFrameRate.fps30, quality: StreamQuality.high, videoCodec: VideoCodec.hvc1, deviceKinds: {...}))` (old named arguments are deprecated) |
| `startStreamSession()` default 30 fps | Default is now `StreamFrameRate.fps24`. Pass `fps30` explicitly to keep 30 fps. |
| `streamSessionErrorStream()` (`Stream<Object>`) | `streamErrorStream()` (`Stream<StreamError>`) |
| `deviceSessionErrorStream()` (`Stream<Object>`) | `deviceSessionErrorStream()` (`Stream<DeviceSessionError>`) |
| `requestCameraPermission()` (`bool`) | `requestPermission(Permission.camera)` (`PermissionStatus`; use `.isGranted`) |
| `getCameraPermissionStatus()` (`bool`) | `checkPermissionStatus(Permission.camera)` (`PermissionStatus`) |
| `pairMockRayBanMeta()` (`String` uuid) | `pairMockGlasses(MockGlassesModel.rayBanMeta)` (`DeviceInfo`; use `.uuid`) |
| `setMockPermission(MockPermission.camera, MockPermissionStatus.granted)` | `setMockPermission(Permission.camera, PermissionStatus.granted)` |
| `setMockCameraFeed(uuid, String? path)` / `setMockCapturedImage(uuid, String? path)` | `path` is now non-null |
| `stopStreamSession(deviceUUID: id)` | `stopStreamSession()` |
| `capturePhoto(deviceUUID: id, format: f)` | `capturePhoto(format: f)` |
| `sendDisplayView(view)` (`Future<void>`) | `sendDisplayView(view)` returns `Future<List<String>>` of substitution warnings |
| `dumpDiagnostics()` (`Map<String, Object?>`) | `dumpDiagnostics()` returns `DatDiagnostics`; the map is `diagnostics.raw` |
| `DeviceSessionError.isDatAppUpdateRequired` | `reason == DeviceSessionErrorCase.datAppOnTheGlassesUpdateRequired`, then `openDatGlassesAppUpdate()` |
| `state.value` (int) on state enums | `state.name`; parse with `fromWire` (`fromInt` is deprecated) |
| `FlexBox(cornerRadius: ...)` | Deprecated and ignored; the Display SDK has no container radius |

### Removed APIs

| 0.7.x | 1.0.0 |
|---|---|
| `pauseStreamSession()` / `resumeStreamSession()` | Removed. They never did anything. The device pauses the stream (touchpad tap, glasses taken off); watch `streamSessionStateStream()` for `paused`. |
| `sessionStateStream()` | `streamSessionStateStream()` |
| `sessionErrorStream()` | `streamErrorStream()` |
| `SessionState` | `StreamSessionState` |
| `startRegistration(appId: ..., urlScheme: ...)` | `startRegistration()`. Values are read from Info.plist and AndroidManifest. |
| `DatErrorCodes.hingesClosed`, `DatErrorCodes.noEligibleDevice`, and other sub-code constants | The `*ErrorCase` enums, for example `StreamErrorCase.hingesClosed`. Category constants such as `DatErrorCodes.stream` remain. |
| Constructing `DatError(code: ..., message: ...)` | `DatError` is sealed. Tests can construct concrete subclasses, for example `StreamError(reason: StreamErrorCase.timeout, message: '...')`. |

### Error handling

In 0.7, `DatError.code` held the category (for example `SESSION_ERROR`) and
the `is*` getters compared it against sub-codes, so they always returned
`false`. In 1.0:

- `category` holds the category (for example `STREAM_ERROR`).
- `code` holds the specific case name (for example `hingesClosed`).
- Each concrete class has a typed `reason` enum.
- `recoveryAction` suggests what to do next.
- `SessionError` is now `StreamError`, and its category is `STREAM_ERROR`
  instead of `SESSION_ERROR`. `SessionError` remains as a typedef.

Before:

```dart
try {
  await MetaWearablesDat.startStreamSession(fps: 30);
} on SessionError catch (e) {
  if (e.isHingesClosed) showMessage('Open the glasses.');
} on DatError catch (e) {
  if (e.code == 'SESSION_ERROR') showMessage(e.message);
}
```

After:

```dart
try {
  await MetaWearablesDat.startStreamSession(
    config: const StreamSessionConfig(frameRate: StreamFrameRate.fps30),
  );
} on DatError catch (e) {
  switch (e) {
    case StreamError(reason: StreamErrorCase.hingesClosed):
      showMessage('Open the glasses.');
    case DeviceSessionError(
      reason: DeviceSessionErrorCase.datAppOnTheGlassesUpdateRequired,
    ):
      await MetaWearablesDat.openDatGlassesAppUpdate();
    case StreamError():
      showMessage(e.message);
    default:
      showMessage('${e.category}/${e.code}: ${e.message}');
  }
}
```

| 0.7.x check | 1.0.0 check |
|---|---|
| `e.code == 'SESSION_ERROR'` | `e is StreamError` or `e.category == DatErrorCodes.stream` |
| `e.code == 'DEVICE_SESSION_ERROR'` | `e is DeviceSessionError` |
| `e.isHingesClosed` | `e.reason == StreamErrorCase.hingesClosed` |
| `e.isThermalCritical` | `e.reason == StreamErrorCase.thermalHot` |
| `e.isNoEligibleDevice` | `e.reason == DeviceSessionErrorCase.noEligibleDevice` |
| `e.isMetaAiNotInstalled` | `e.reason == RegistrationErrorCase.metaAINotInstalled` |
| `e.isMissingFragmentActivity` | `e.reason == PermissionErrorCase.missingFragmentActivity` |
| `e.details` (`Object?`) | `e.details` (`Map<String, Object?>`), plus `e.platformCase` and `e.platform` |

The `is*` getters still exist as deprecated shims and now return the right
value.

### Mock Device Kit

```dart
// 0.7.x
final uuid = await MetaWearablesDat.pairMockRayBanMeta();

// 1.0.0
final glasses =
    await MetaWearablesDat.pairMockGlasses(MockGlassesModel.rayBanMeta);
final uuid = glasses.uuid;
```

A mock device appears in `devicesStream()` only after `mockPowerOn(uuid)` and
`mockUnfold(uuid)`.

## 6. Verify

1. `flutter analyze` and fix deprecation warnings.
2. Run the app in Developer Mode and print the diagnostics:

   ```dart
   final diagnostics = await MetaWearablesDat.dumpDiagnostics();
   for (final finding in diagnostics.findings) {
     debugPrint('$finding\n  fix: ${finding.fix}');
   }
   ```

   Fix every finding in `diagnostics.errors`. A `damEnabledIgnored` finding
   means a `DAMEnabled` / `DAM_ENABLED` entry is still present.
3. Register, request the camera permission, start and stop a stream. After
   `stopStreamSession()`, `diagnostics.isIdle` should be `true`.

## New in 1.0 (optional)

- `registrationRequestStream()` for registrations started from the Meta AI
  app.
- `deviceStateStream(uuid)` and the new `DeviceInfo` fields (battery,
  charging, wear, hinge, thermal, link state).
- `hvc1` texture preview on Android.
- Display: `DisplayButtonGroup`, `DisplayImage.bytes`, `clearDisplay()`,
  `displayErrorStream()`.
- Experimental Inputs, Motion, Speech, voice invocations, high-resolution
  photo, and in-stream audio. These cannot ship to production release
  channels; see [`experimental.md`](experimental.md).

See the [changelog](../CHANGELOG.md) for the full list.
