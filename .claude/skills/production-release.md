---
description: Shipping with DAT 1.0 - app distribution via Developer Mode and the Beta release channel, experimental restrictions, pre-release checklist for consumer apps, and the plugin's own release process (versions, check_versions, CHANGELOG, release.yml to pub.dev)
globs: pubspec.yaml, CHANGELOG.md, ios/meta_wearables_dat_flutter/Package.swift, ios/*.podspec, android/build.gradle, tool/check_versions.dart, .github/workflows/release.yml
---

# Production Release (DAT 1.0)

Two different things: shipping an **app** that uses the plugin, and
releasing the **plugin** itself.

## A. Shipping an app

### Distribution reality

- Meta's iOS guide still says App Store publishing is not supported.
- Distribute via **Developer Mode** (internal) and the invite-only
  **Beta release channel** in Wearables Developer Center.
- The plugin is "Beta-channel ready now, store-ready later".
- Apps using any `@experimental` API (Inputs, Motion, Speech, voice
  invocations, high-res photo, in-stream audio) cannot ship to production
  release channels.

### Checklist

- [ ] Create a **new app version for 1.0 builds** in Wearables Developer
      Center; use its app id and client token.
- [ ] iOS `MWDAT`: real `MetaAppID`, `ClientToken`, `TeamID`;
      `AppLinkURLScheme` ends with `://` and is in `CFBundleURLTypes`.
- [ ] Android meta-data `com.meta.wearable.mwdat.APPLICATION_ID` and
      `CLIENT_TOKEN`; remove `DAM_ENABLED` / `DAMEnabled`.
- [ ] `dumpDiagnostics().errors` is empty on a release build.
- [ ] Mock Device Kit disabled (`disableMockDevice()`; no
      `enableMockDevice()` in release paths).
- [ ] No experimental APIs if targeting production channels. On Android,
      `mwdat.experimental=false` removes the AARs and makes accidental
      calls fail fast with `EXPERIMENTAL_NOT_LINKED`.
- [ ] Handle `DeviceSessionError.isTerminal` (`insufficientSDKVersion`)
      and `recoveryAction` (`openFirmwareUpdate`,
      `openDatGlassesAppUpdate`, `updateHostApp`).
- [ ] Optional opt-outs: iOS `MWDAT > CrashReporting > OptOut` and
      `MWDAT > Analytics > OptOut`; Android meta-data
      `com.meta.wearable.mwdat.CRASH_REPORTING_OPT_OUT` /
      `ANALYTICS_OPT_OUT`. Reported as `crashReportingOptOut` /
      `analyticsOptOut` in `dumpDiagnostics().raw`.
- [ ] Users need Meta AI V290+ and glasses firmware V128+.
- [ ] iOS: Xcode 26.4+, deployment target 17.2, SPM.

## B. Releasing the plugin

### Versioning

- Plugin `major.minor` = Meta DAT `major.minor`; patch is ours.
- `@experimental` APIs are excluded from semver.
- `dart run tool/check_versions.dart` must pass. It checks
  `pubspec.yaml` `version`, podspec, Swift `pluginVersion`,
  `android/build.gradle` `version`, top `CHANGELOG.md` entry, and SDK pins
  (`Package.swift` `exact:`, Swift `sdkVersion`, Android
  `ext.mwdat_version`).

### Adopting a new DAT release

1. Bump the SDK pins everywhere `check_versions` looks.
2. Diff Meta's Swift interface / Kotlin API; map every new enum case in
   `WireCodec.swift` / `WireCodec.kt` (pins are exact on purpose).
3. Regenerate icons if needed: `dart run tool/gen_icon_names.dart`.
4. Run every gate (below); update `CHANGELOG.md`, `doc/`, `AGENTS.md`.

### Gates before tagging

```bash
flutter analyze --fatal-infos
flutter test --coverage && dart run tool/coverage_gate.dart --min 90
dart run tool/check_channel_parity.dart
dart run tool/check_versions.dart
cd example/android && ./gradlew :meta_wearables_dat_flutter:testDebugUnitTest
# Swift RunnerTests on an iOS 26+ simulator (example/ios)
cd example && flutter test integration_test/plugin_test.dart -d <device>
flutter pub publish --dry-run
```

### Publishing

1. Merge to `main` with CI green.
2. Push tag `vX.Y.Z` (or `vX.Y.Z-rc.N`).
3. `.github/workflows/release.yml`: `check_versions --tag` → full CI →
   OIDC `flutter pub publish --force` in the `pub.dev` environment
   (manual approval) → GitHub release from the CHANGELOG section.
4. Never publish from a laptop; never commit credentials.

## Links

- [`CHANGELOG.md`](../../CHANGELOG.md)
- [experimental-modules.md](experimental-modules.md)
- Wearables Developer Center: <https://wearables.developer.meta.com/>
