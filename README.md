_This is an **unofficial** Flutter plugin. It is not affiliated with, endorsed
by, sponsored by, or in any way officially connected to Meta Platforms, Inc.
"Meta", "Ray-Ban Meta", "Oakley Meta", and "Ray-Ban Display" are trademarks of
their respective owners. This plugin links Meta's official Wearables Device
Access Toolkit (DAT) SDKs as binary dependencies; it does not redistribute or
reimplement them._

# meta_wearables_dat_flutter

[![pub package](https://img.shields.io/pub/v/meta_wearables_dat_flutter.svg)](https://pub.dev/packages/meta_wearables_dat_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![Flutter](https://img.shields.io/badge/flutter-%3E%3D3.24.0-blue.svg)](https://flutter.dev)

The `meta_wearables_dat_flutter` plugin lets Flutter developers utilize
Meta's AI glasses to build hands-free wearable experiences into their
mobile applications. It bridges Meta's official iOS and Android
Wearables Device Access Toolkit (DAT) SDKs (v0.6.0) behind a single
Dart API so the same Flutter code reliably connects to Ray-Ban Meta,
Oakley Meta, and Ray-Ban Display glasses on both platforms — with
video streaming, photo capture, the Mock Device Kit, and background
streaming all included.

The Wearables Device Access Toolkit is in developer preview, and so is
this plugin. Apps built with it cannot yet ship to the public App
Store or Play Store; create an organisation and release channel in the
[Wearables Developer Center](https://wearables.developer.meta.com/) to
share with test users.

## Documentation & Community

Find Meta's full
[developer documentation](https://wearables.developer.meta.com/docs/develop/)
on the Wearables Developer Center.

Plugin-specific guides live in [`doc/`](doc/):

- [`doc/getting_started.md`](doc/getting_started.md) — pubspec, iOS
  `Info.plist`, Android `AndroidManifest.xml`, Developer Mode.
- [`doc/registration_flow.md`](doc/registration_flow.md) — registration
  deep-link wiring.
- [`doc/streaming.md`](doc/streaming.md) — texture rendering, video
  codecs, photo capture, background streaming.
- [`doc/frame_processing.md`](doc/frame_processing.md) — opt-in
  per-frame `videoFramesStream`, recording, OCR/ML pipelines.
- [`doc/mock_device.md`](doc/mock_device.md) — Mock Device Kit.
- [`doc/troubleshooting.md`](doc/troubleshooting.md) — common
  pitfalls.

For help or to suggest feature ideas, open an issue on
[GitHub](https://github.com/iSee-Labs/meta-wearables-dat-flutter/issues).

See the [changelog](CHANGELOG.md) for the latest updates.

## Compatible devices

- Ray-Ban Meta (Gen 1 and Gen 2)
- Oakley Meta (HSTN, Vanguard)
- Ray-Ban Display

A paired phone running the **Meta AI** companion app with **Developer
Mode** enabled is required during the developer preview.

## Including the SDK in your project

```yaml
dependencies:
  meta_wearables_dat_flutter: ^0.1.0
```

```bash
flutter pub get
```

### iOS

1. Enable Flutter's Swift Package Manager support once per machine:

   ```bash
   flutter config --enable-swift-package-manager
   ```

2. Set iOS deployment target to **17.0** in your `Runner.xcodeproj`.
3. Add the `MWDAT` dict and the related URL-scheme / background-mode /
   external-accessory keys to `ios/Runner/Info.plist`. The full list is
   in [`doc/getting_started.md`](doc/getting_started.md); see
   [`example/ios/Runner/Info.plist`](example/ios/Runner/Info.plist) for
   a working template.

### Android

1. Make `MainActivity` extend `FlutterFragmentActivity`:

   ```kotlin
   import io.flutter.embedding.android.FlutterFragmentActivity
   class MainActivity : FlutterFragmentActivity()
   ```

2. Set `minSdk = 31`.
3. Add Meta's GitHub Packages Maven repo with a `GITHUB_TOKEN` env
   var (or `github_token=...` in `local.properties`) holding a PAT with
   `read:packages` scope.
4. The plugin merges its own permissions (`FOREGROUND_SERVICE`,
   `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `WAKE_LOCK`,
   `POST_NOTIFICATIONS`) and `<service>` entry. Your app adds the
   `MWDAT_APPLICATION_ID` / `CLIENT_TOKEN` meta-data and the deep-link
   intent filter — see
   [`example/android/app/src/main/AndroidManifest.xml`](example/android/app/src/main/AndroidManifest.xml).

## Integration lifecycle

```dart
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

// 1. Permissions (Bluetooth/Internet on Android, no-op on iOS).
await MetaWearablesDat.requestAndroidPermissions();

// 2. Register with the Meta AI app via deep link.
await MetaWearablesDat.startRegistration(
  appId: '0',                  // "0" == Developer Mode
  urlScheme: 'yourappscheme',
);

// 3. Camera permission (Meta AI bottom sheet).
await MetaWearablesDat.requestCameraPermission();

// 4. Start streaming and render the texture.
final textureId = await MetaWearablesDat.startStreamSession();
// Texture(textureId: textureId)

// 5. Capture stills, observe state.
final photo = await MetaWearablesDat.capturePhoto();
MetaWearablesDat.streamSessionStateStream().listen(print);
```

See [`samples/camera_access/`](samples/camera_access/) for a complete
integration that mirrors Meta's official iOS and Android CameraAccess
samples.

## Developer Terms

- By using the Wearables Device Access Toolkit, you agree to Meta's
  [Meta Wearables Developer Terms](https://wearables.developer.meta.com/terms),
  including the [Acceptable Use Policy](https://wearables.developer.meta.com/acceptable-use-policy).
- By enabling Meta integrations through this plugin, Meta may collect
  information about how users' Meta devices communicate with your app.
  Meta uses this information in accordance with the
  [Meta Privacy Policy](https://www.meta.com/legal/privacy-policy/).
- You may limit Meta's access to data from users' devices by opting
  out of analytics as described below.

### Opting out of data collection

This plugin is a thin bridge — analytics are controlled by Meta's
underlying SDKs and you opt out exactly as you would in a native
project.

**iOS** — add an `Analytics.OptOut` key inside the `MWDAT` dict in
`ios/Runner/Info.plist`:

```xml
<key>MWDAT</key>
<dict>
  <key>Analytics</key>
  <dict>
    <key>OptOut</key>
    <true/>
  </dict>
  <!-- other MWDAT keys ... -->
</dict>
```

**Android** — add the matching `meta-data` entry inside
`android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
  android:name="com.meta.wearable.mwdat.ANALYTICS_OPT_OUT"
  android:value="true" />
```

Default behavior: if the key is missing or `false`, analytics are
enabled. Set it to `true` to disable data collection.

## AI-Assisted Development

This repository ships config for three AI coding assistants, all
generated from the same canonical knowledge in [`AGENTS.md`](AGENTS.md):

| Tool | Config | How it loads |
|------|--------|--------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `.claude/skills/*.md` | Auto-discovered when you open the project |
| [GitHub Copilot](https://github.com/features/copilot) | `.github/copilot-instructions.md` | Auto-loaded by Copilot in VS Code |
| [Cursor](https://cursor.sh/) | `.cursor/rules/*.mdc` | Auto-loaded with glob-based triggers |

### Quick setup

Install config for your preferred tool:

```bash
./install-skills.sh claude    # Claude Code only
./install-skills.sh copilot   # GitHub Copilot only
./install-skills.sh cursor    # Cursor only
./install-skills.sh agents    # AGENTS.md only
./install-skills.sh all       # All tools
```

Or install everything remotely with a single command:

```bash
curl -sL https://raw.githubusercontent.com/iSee-Labs/meta-wearables-dat-flutter/main/install-skills.sh | bash
```

If you cloned this repository, the config is already included — no
setup needed.

### What's included

- **Getting started** — pubspec wiring, `Info.plist`,
  `AndroidManifest.xml`, Developer Mode.
- **Camera streaming** — texture path, video codecs, photo capture,
  `videoFramesStream`.
- **Mock device testing** — `MockDeviceKit` from Dart.
- **Session lifecycle** — `DeviceSession` vs `StreamSession`,
  pause/resume.
- **Permissions & registration** — deep-link callbacks, camera permission flow.
- **Debugging** — registration errors, no eligible device, Maven 401,
  SPM not enabled.
- **Sample app guide** — building a complete Flutter DAT app.

For Meta's full API reference, point your AI tool at the
[llms.txt endpoint](https://wearables.developer.meta.com/llms.txt?full=true).

## License

[MIT](LICENSE) © 2026 iSee Labs.

## Acknowledgments

Built on top of Meta's official open-source SDKs:

- [`meta-wearables-dat-ios`](https://github.com/facebook/meta-wearables-dat-ios)
- [`meta-wearables-dat-android`](https://github.com/facebook/meta-wearables-dat-android)

Architecture inspiration (texture bridge, per-frame stream) drawn from
the community
[`flutter_meta_wearables_dat`](https://github.com/rodcone/flutter_meta_wearables_dat)
plugin. See [`NOTICE`](NOTICE) for full attribution.
