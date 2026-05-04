_This is an **unofficial** Flutter plugin. It is not affiliated with, endorsed
by, sponsored by, or in any way officially connected to Meta Platforms, Inc.
"Meta", "Ray-Ban Meta", "Oakley Meta", and "Ray-Ban Display" are trademarks of
their respective owners. This plugin links Meta's official Wearables Device
Access Toolkit (DAT) SDKs as binary dependencies; it does not redistribute or
reimplement them._

# meta_wearables_dat_flutter

A unified Flutter plugin for Meta's official iOS and Android Wearables Device
Access Toolkit (DAT) — connect, register, and stream from Ray-Ban Meta, Oakley
Meta, and Ray-Ban Display glasses from a single Dart API.

[![pub package](https://img.shields.io/pub/v/meta_wearables_dat_flutter.svg)](https://pub.dev/packages/meta_wearables_dat_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![Flutter](https://img.shields.io/badge/flutter-%3E%3D3.24.0-blue.svg)](https://flutter.dev)

> **Developer preview.** Meta's DAT SDKs are themselves in developer preview;
> apps built with this plugin cannot yet ship to the public App Store or Play
> Store. See [Meta's developer terms](https://wearables.developer.meta.com/terms).

## Compatible devices

- Ray-Ban Meta (Gen 1 and Gen 2)
- Oakley Meta (HSTN, Vanguard)
- Ray-Ban Display

A paired phone running the **Meta AI** app with **Developer Mode** enabled is
required (see [`doc/getting_started.md`](doc/getting_started.md)).

## Setup

Detailed setup lives in [`doc/getting_started.md`](doc/getting_started.md).
Quick links:

- [iOS setup (Swift Package Manager, `Info.plist`)](doc/getting_started.md)
- [Android setup (`FlutterFragmentActivity`, GitHub Packages Maven, `AndroidManifest.xml`)](doc/getting_started.md)
- [Registration deep-link wiring](doc/registration_flow.md)
- [Streaming and texture rendering](doc/streaming.md)
- [Frame snapshots for OCR / ML](doc/frame_processing.md)
- [Mock Device Kit (develop without hardware)](doc/mock_device.md)
- [Troubleshooting](doc/troubleshooting.md)

## Integration lifecycle

```dart
// 1. Permissions (Bluetooth/Internet on Android, no-op on iOS).
await MetaWearablesDat.requestAndroidPermissions();

// 2. Register with the Meta AI app via deep link.
await MetaWearablesDat.startRegistration(
  appId: 'YOUR_APP_ID',
  urlScheme: 'your_app_scheme',
);
// In your app's deep-link handler:
//   MetaWearablesDat.handleUrl(uri.toString());

// 3. Camera permission (Meta AI bottom sheet).
await MetaWearablesDat.requestCameraPermission();

// 4. Start streaming and render the texture.
final textureId = await MetaWearablesDat.startStreamSession();
// Texture(textureId: textureId)

// 5. Capture stills.
final photo = await MetaWearablesDat.capturePhoto();
```

See the [`samples/camera_access/`](samples/camera_access/) app for a complete
working integration that mirrors Meta's official iOS and Android Camera Access
samples.

## Troubleshooting

The most common pitfalls are summarised in
[`doc/troubleshooting.md`](doc/troubleshooting.md):

- "Registration deep link never returns" — URL scheme or
  `FlutterFragmentActivity` misconfiguration.
- `MISSING_FRAGMENT_ACTIVITY` — your `MainActivity` does not extend
  `FlutterFragmentActivity`.
- Maven `401` on Android build — `GITHUB_TOKEN` env var missing or lacks the
  `read:packages` scope.
- Cryptic Xcode errors about `MWDATCore` — Swift Package Manager support is not
  enabled (`flutter config --enable-swift-package-manager`).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) and our
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE) © 2026 iSee Labs.

## Acknowledgments

Built on top of Meta's official open-source SDKs:

- [`meta-wearables-dat-ios`](https://github.com/facebook/meta-wearables-dat-ios)
- [`meta-wearables-dat-android`](https://github.com/facebook/meta-wearables-dat-android)

Architecture inspiration (texture bridge, `captureStreamFrame`) drawn from the
community
[`flutter_meta_wearables_dat`](https://github.com/rodcone/flutter_meta_wearables_dat)
plugin. See [`NOTICE`](NOTICE) for full attribution.
