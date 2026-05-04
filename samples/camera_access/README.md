# `camera_access` (Flutter)

A polished Flutter clone of Meta's official iOS and Android **Camera Access**
samples, built on `meta_wearables_dat_flutter`.

This sample is intentionally **not** the plugin's `example/` app. The
example is the bare smoke test the plugin ships to satisfy `pub.dev`. This
sample is the reference implementation: registration, streaming, photo /
frame capture, and Mock Device Kit playback are all wired up across three
screens with Material 3 styling.

## Setup

1. Install Flutter `>=3.24.0` and ensure SPM is enabled:
   ```bash
   flutter config --enable-swift-package-manager
   ```
2. Place a GitHub PAT with `read:packages` scope into `local.properties`
   (Android) under `github_token=...`, or export `GITHUB_TOKEN` in your
   shell.
3. Open `ios/Runner.xcodeproj` and set your team and bundle id.
4. Update `ios/Runner/Info.plist`'s `MWDAT` dictionary with your
   `MetaAppID`, `ClientToken`, and `TeamID` from the Wearables Developer
   Center. (Default values are placeholders for hardware-less testing.)
5. Run:
   ```bash
   cd samples/camera_access
   flutter run
   ```

## Tour

- **Home** — registration status, BT / Internet permission, camera
  permission, and shortcuts to the other screens.
- **Live stream** — `startStreamSession` + `Texture(textureId: id)`,
  `capturePhoto`, and `captureStreamFrame`. The captured image is shown in
  a bottom sheet so you can verify it visually.
- **Mock Device Kit** — pair a mock Ray-Ban Meta, power it on, don it,
  and toggle the camera feed without any glasses on the desk.

## Differences from Meta's official samples

- Pure Dart UI (no SwiftUI / Compose).
- One unified codebase across iOS and Android.
- No audio, no HEVC video codec — both deferred to v0.2 of the plugin.
