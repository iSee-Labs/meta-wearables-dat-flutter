# `camera_access` (Flutter)

A polished Flutter clone of Meta's official iOS and Android **Camera Access**
samples, built on `meta_wearables_dat_flutter`.

This sample is intentionally **not** the plugin's `example/` app. The
example is the bare smoke test the plugin ships to satisfy `pub.dev`. This
sample is the reference implementation: registration, streaming, photo /
frame capture, and Mock Device Kit playback are all wired up across three
screens with Material 3 styling.

## Setup

1. Install Flutter `>=3.44.0` (Swift Package Manager is the default) and
   Xcode 26.4 or newer. The iOS deployment target is 17.2.
2. Android needs no extra setup: Meta's SDK resolves from Maven Central.
3. Open `ios/Runner.xcodeproj` and set your team and bundle id.
4. Update `ios/Runner/Info.plist`'s `MWDAT` dictionary with your
   `MetaAppID`, `ClientToken`, and `TeamID` from the Wearables Developer
   Center, and the matching meta-data in
   `android/app/src/main/AndroidManifest.xml`. Builds made with plugin 1.0
   need a new app version in the Developer Center. (Default values are
   placeholders for hardware-less testing.)
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
- Raw and HEVC (`hvc1`) codecs are both selectable in Settings; audio capture is not shown.
