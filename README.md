> **Unofficial.** This plugin is not affiliated with, endorsed by, sponsored
> by, or officially connected to Meta Platforms, Inc. "Meta", "Ray-Ban Meta",
> "Oakley Meta", and "Meta Ray-Ban Display" are trademarks of their respective
> owners.

# Meta Wearables Device Access Toolkit for Flutter

[![pub package](https://img.shields.io/pub/v/meta_wearables_dat_flutter?logo=dart&logoColor=white&color=brightgreen)](https://pub.dev/packages/meta_wearables_dat_flutter)
[![Docs](https://img.shields.io/badge/API_Reference-latest-blue?logo=flutter)](https://pub.dev/documentation/meta_wearables_dat_flutter/latest/)
[![CI](https://github.com/iSee-Labs/meta-wearables-dat-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/iSee-Labs/meta-wearables-dat-flutter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

The Meta Wearables Device Access Toolkit (DAT) enables developers to utilize
Meta's AI glasses to build hands-free wearable experiences into their mobile
applications. This plugin brings the toolkit to Flutter: it links Meta's
official [iOS](https://github.com/facebook/meta-wearables-dat-ios) and
[Android](https://github.com/facebook/meta-wearables-dat-android) SDKs and
exposes one Dart API for registration, device state, video and audio
streaming, photo capture, and the Display on Meta Ray-Ban Display glasses.

`meta_wearables_dat_flutter` **1.0.0** targets DAT **1.0.0** on both
platforms. The plugin's `major.minor` tracks Meta's; the patch is ours.

The Wearables Device Access Toolkit is in developer preview. You can build
and test on supported AI glasses in Developer Mode and share your integration
with test users through release channels in the Wearables Developer Center.
Meta does not yet support publishing DAT apps to the App Store or Google Play.

## Documentation & Community

Find Meta's full [developer documentation](https://wearables.developer.meta.com/docs/develop/)
on the [Wearables Developer Center](https://wearables.developer.meta.com/).
Create an account to register your organization, set up a project and
release channel, and share your integration with test users.

Plugin guides live in [`doc/`](doc/):

| Guide | Topic |
|-------|-------|
| [Getting started](doc/getting_started.md) | Install, `Info.plist`, `AndroidManifest.xml`, Developer Mode |
| [Registration](doc/registration_flow.md) | App-initiated and Meta AI-initiated registration, permissions |
| [Streaming](doc/streaming.md) | Texture preview, raw and HEVC codecs, photos, background streaming |
| [Frame processing](doc/frame_processing.md) | `videoFramesStream`, pixel formats, costs |
| [Device state](doc/device_state.md) | Battery, wear, hinge, thermal, compatibility, update flows |
| [Display](doc/display_access.md) | Component DSL and callbacks for Meta Ray-Ban Display |
| [Experimental](doc/experimental.md) | Inputs, Motion, Speech, voice invocations, high-res photo, audio |
| [Mock Device Kit](doc/mock_device.md) | Testing without glasses |
| [Troubleshooting](doc/troubleshooting.md) | Diagnostics findings, common errors, known issues |
| [Production checklist](doc/production_checklist.md) | Before you distribute |
| [Migration 0.7 to 1.0](doc/migration_0.7_to_1.0.md) | Upgrading from 0.7.x |

For help, discussion about best practices or to suggest feature ideas visit
the [discussions forum](https://github.com/iSee-Labs/meta-wearables-dat-flutter/discussions).
Report bugs in the [issue tracker](https://github.com/iSee-Labs/meta-wearables-dat-flutter/issues).

See the [changelog](CHANGELOG.md) for the latest updates.

## Including the plugin in your project

```yaml
dependencies:
  meta_wearables_dat_flutter: ^1.0.0
```

| Requirement | Minimum |
|-------------|---------|
| Flutter | 3.44 (Dart 3.8); Swift Package Manager is the default |
| iOS | 17.2, Xcode 26.4. Meta's SDK resolves through Swift Package Manager only |
| Android | `minSdk 31`; `MainActivity` extends `FlutterFragmentActivity`. Meta's SDK resolves from Maven Central, no token needed |
| Meta AI app | V290, with Developer Mode on (**Settings > App Info**, tap the version five times) |
| Glasses firmware | V128 |

The SDK requires a few entries in your app's `Info.plist` (the `MWDAT`
dictionary, URL scheme, background modes and usage descriptions) and
`AndroidManifest.xml` (`APPLICATION_ID`, `CLIENT_TOKEN`, the callback intent
filter). [Getting started](doc/getting_started.md) lists them with copy-paste
examples, and `MetaWearablesDat.dumpDiagnostics()` reports anything missing.

### Quick start

```dart
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

await MetaWearablesDat.requestAndroidPermissions(); // no-op on iOS
await MetaWearablesDat.startRegistration();         // opens the Meta AI app
await MetaWearablesDat.requestPermission(Permission.camera);

final textureId = await MetaWearablesDat.startStreamSession(
  config: const StreamSessionConfig(
    quality: StreamQuality.high,
    videoCodec: VideoCodec.hvc1,
  ),
);
// In your widget tree:
Texture(textureId: textureId);

final photo = await MetaWearablesDat.capturePhoto();
await MetaWearablesDat.stopStreamSession();
```

Every failure is a typed, sealed `DatError` with a `category`, a `code`, a
`reason` enum and a suggested `recoveryAction`. See
[Streaming](doc/streaming.md) and [Troubleshooting](doc/troubleshooting.md).

## Capabilities

- **Registration & permissions** — App registration with Meta AI, Meta AI-initiated registration requests, camera and microphone permissions
- **Devices** — Paired devices with live battery, charging, wear, hinge, thermal, link and compatibility state; firmware and glasses-app update deep links
- **Camera streaming** — Decoded video into a Flutter `Texture` (raw or HEVC, on both platforms), opt-in frame stream, in-stream photo capture, background streaming
- **Audio streaming** — Synchronized PCM audio through the camera stream (experimental; unavailable for production publishing)
- **Camera capture** — Standalone high-resolution photos with progress and typed errors (experimental; unavailable for production publishing)
- **Display** — Declarative UI on Meta Ray-Ban Display glasses with tap, click and playback callbacks
- **Inputs** — Navigation, button, capture and drag interactions from glasses and the Meta Neural Band (experimental)
- **Motion** — Accelerometer, gyroscope, magnetometer and orientation samples (experimental)
- **Speech** — On-device speech recognition with partial and final results (experimental)
- **Voice invocations** — Launch or activate the app from "Hey Meta" and acknowledge each action (experimental)
- **Mock Device Kit** — Simulated glasses, camera feed, permissions, display preview and all experimental simulators, so everything above runs on the iOS Simulator and Android emulator
- **Diagnostics** — Configuration findings for `Info.plist` and the manifest, and a ledger of held native resources

Experimental APIs are annotated `@experimental`, excluded from semantic
versioning, and can be dropped from Android builds with
`mwdat.experimental=false`. Details in [Experimental](doc/experimental.md).

## Developer Terms

- By using the Wearables Device Access Toolkit, you agree to Meta's
  [Wearables Developer Terms](https://wearables.developer.meta.com/terms),
  including the [Acceptable Use Policy](https://wearables.developer.meta.com/acceptable-use-policy).
- By enabling Meta integrations, including through this plugin, Meta may
  collect information about how users' Meta devices communicate with your
  app. Meta uses this information in accordance with its
  [Privacy Policy](https://www.meta.com/legal/privacy-policy/).
- You may limit Meta's access to data from users' devices by following the
  instructions below. The plugin reports both settings in
  `dumpDiagnostics()` as `analyticsOptOut` and `crashReportingOptOut`.

### Opting out of data collection

**iOS**: add an `Analytics` dictionary with `OptOut` set to `YES` under the
`MWDAT` key in `ios/Runner/Info.plist`.

```xml
<key>MWDAT</key>
<dict>
    <key>Analytics</key>
    <dict>
        <key>OptOut</key>
        <true/>
    </dict>
</dict>
```

**Android**: add this `<meta-data>` element inside `<application>` in
`android/app/src/main/AndroidManifest.xml`.

```xml
<meta-data
    android:name="com.meta.wearable.mwdat.ANALYTICS_OPT_OUT"
    android:value="true"
    />
```

**Default behavior:** if the key is missing or `false`, analytics are
enabled. Set it to `true` to disable data collection.

### Crash reporting

The toolkit can capture crashes originating from SDK code, store them locally
and chain with any existing crash handler your app installs. Crash reporting
is **enabled by default**.

To opt out, add a `CrashReporting` dictionary with `OptOut` set to `YES`
under the `MWDAT` key on iOS, or this element on Android:

```xml
<meta-data
    android:name="com.meta.wearable.mwdat.CRASH_REPORTING_OPT_OUT"
    android:value="true"
    />
```

## AI-Assisted Development

This repository ships its plugin knowledge base as file-based artifacts for
the common AI coding tools:

| Tool | Artifact | Setup |
|------|----------|-------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `.claude/skills/*.md` | `./install-skills.sh claude` |
| [GitHub Copilot](https://github.com/features/copilot) | `.github/copilot-instructions.md` | Auto-loaded by Copilot in VS Code |
| [Cursor](https://cursor.sh/) | `.cursor/rules/*.mdc` | Auto-loaded with glob-based triggers |
| AGENTS.md-compatible tools | `AGENTS.md` | Portable fallback for agents that read `AGENTS.md` |
| MCP-compatible editors | `https://mcp.developer.meta.com/wearables` | Meta's hosted DAT docs server; connect as a remote HTTP MCP server, no authentication required |

Install the artifacts into your own project with the helper script:

```bash
./install-skills.sh claude    # .claude/skills/*.md
./install-skills.sh copilot   # .github/copilot-instructions.md
./install-skills.sh cursor    # .cursor/rules/*.mdc
./install-skills.sh agents    # AGENTS.md
./install-skills.sh all       # everything above
```

Or run it remotely:

```bash
curl -sL https://raw.githubusercontent.com/iSee-Labs/meta-wearables-dat-flutter/main/install-skills.sh | bash
```

### What's included

- **Getting started** — Plugin setup, `Info.plist` and manifest configuration, Developer Mode
- **Permissions & registration** — Both registration flows and device permissions
- **Session lifecycle** — The shared device session, stream states, device availability
- **Camera streaming** — Texture preview, codecs, frame processing, photo capture
- **Display access** — Building views with the Display DSL and handling callbacks
- **Device state** — Battery, thermal and wear handling, update flows
- **Experimental modules** — Inputs, Motion, Speech, voice invocations and the Android opt-out
- **MockDevice testing** — Driving the Mock Device Kit and writing integration tests
- **Debugging** — Diagnostics findings, common errors, known issues
- **Production release** — Checklist for Beta release channels
- **Sample app guide** — The three sample apps and how they are structured
- **DAT conventions** — Wire contract, error model and coding rules of this plugin

For Meta's own SDK knowledge, install the `mwdat-ios` and `mwdat-android`
plugins that ship in Meta's SDK repositories, or point your tool at the
[llms.txt endpoint](https://wearables.developer.meta.com/llms.txt?full=true).

## Samples

| Sample | Shows |
|--------|-------|
| [`samples/camera_access`](samples/camera_access) | Flutter port of Meta's Camera Access sample: registration, streaming, photo and frame capture, Mock Device Kit menu |
| [`samples/display_access`](samples/display_access) | Flutter port of Meta's Display Access sample: tutorial screens on Meta Ray-Ban Display with button groups and video |
| [`samples/glasses_companion`](samples/glasses_companion) | DAT 1.0 features in one app: live device state, update deep links, diagnostics, HEVC preview, high-res photo, a display card, mock controls and the experimental modules |

## Compatibility

| Plugin | Meta DAT (iOS and Android) | Notes |
|--------|----------------------------|-------|
| 1.0.x | 1.0.0 | Swift Package Manager only, Maven Central, iOS 17.2 |
| 0.7.x | 0.7.0 | CocoaPods, GitHub Packages |

1.0.0 is verified against Meta's Mock Device Kit on the iOS Simulator and
Android emulator plus unit tests on every layer. Hardware findings are
welcome as issues. One known Meta SDK issue affects iOS 17.2 to 18.x: calling
`objc_copyClassList` (XCTest and some analytics SDKs do) aborts inside
`MWDATCore`. See [Troubleshooting](doc/troubleshooting.md#known-issues).

## License

[MIT](LICENSE). Copyright 2026 iSee Labs. Maintained by Talha Ordukaya.

Meta's SDKs are linked as dependencies, not redistributed, and remain under
Meta's license terms. See [`NOTICE`](NOTICE).
