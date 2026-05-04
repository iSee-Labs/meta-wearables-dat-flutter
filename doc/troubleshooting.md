# Troubleshooting

Common pitfalls and how to recognise them.

## Build / setup

- **iOS: "Missing MWDATCore" / "Missing MWDATCamera"** — Swift Package
  Manager support for Flutter plugins is not enabled. Run
  `flutter config --enable-swift-package-manager` once and rebuild.
  Xcode 15.4+ is required.
- **Android: `Could not find com.meta.wearable:mwdat-core...`** —
  GitHub Packages credentials are missing. Add a PAT with
  `read:packages` scope to `local.properties`:
  ```
  github_token=ghp_...
  ```
  or export `GITHUB_TOKEN`. Make sure your app's
  `settings.gradle.kts` includes the GitHub Packages repository in
  `dependencyResolutionManagement.repositories`.
- **`pluginClass: MetaWearablesDatPlugin not found`** when running the
  example — ensure the plugin native folder (`ios/`, `android/`)
  contains the corresponding source file. Re-run
  `flutter pub get`.

## Runtime — registration

- **`registrationStateStream` stays `unavailable`** on Android — the
  user denied `BLUETOOTH_CONNECT`, or `Wearables.initialize` ran
  before the permission was granted. Call `requestAndroidPermissions`
  and verify `granted == true` before any registration call.
- **iOS `startRegistration` throws `REGISTRATION_ERROR`** — check that
  the `MWDAT` dictionary in `Info.plist` is filled in and that
  `AppLinkURLScheme` matches the URL scheme registered in
  `CFBundleURLTypes`.
- **Deep link does nothing** — your `MainActivity` is missing
  `launchMode="singleTop"`, or `AppLinks` isn't subscribed before
  `startRegistration` returns.

## Runtime — camera permission

- **`MISSING_FRAGMENT_ACTIVITY` on Android** — your `MainActivity`
  extends `FlutterActivity` instead of `FlutterFragmentActivity`. Meta's
  `RequestPermissionContract` requires a `ComponentActivity`.

## Runtime — streaming

- **Texture renders black** — most likely no frames are arriving.
  Common causes:
  - Glasses are not donned (worn). The Meta SDK gates streams behind
    "device on face" detection. For mock devices, call
    `mockDon(uuid)` first.
  - `requestCameraPermission` was never granted.
  - On Android, `setMockCameraFeed` / `setMockCameraFacing` was not
    called for a mock device.
- **`SessionError` with `permissionDenied`** — the user revoked
  camera permission while the session was running. Call
  `requestCameraPermission` again to recover.
- **High CPU on Android during streaming** — expected for v0.1.0.
  The I420 -> ARGB conversion runs on the CPU. v0.2 ships GPU-side
  rendering.

## File an issue

If you hit something not listed here, open an issue at
<https://github.com/iseelabs/meta_wearables_dat_flutter/issues>
including:

- `flutter doctor -v`
- The full stack trace and any `DatError.code` you observed.
- Whether the bug reproduces against a mock device.
