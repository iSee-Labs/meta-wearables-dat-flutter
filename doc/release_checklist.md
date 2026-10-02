# Release checklist (maintainers)

How to release `meta_wearables_dat_flutter`. App developers want the
[production checklist](production_checklist.md) instead.

Versioning: the plugin's **major.minor equals Meta's DAT major.minor**;
the patch number is ours. `@experimental` APIs are excluded from
semver. `tool/check_versions.dart` enforces this.

## 1. Prepare

- [ ] Branch is up to date with `main`; the release PR is reviewed.
- [ ] Version bumped everywhere `tool/check_versions.dart` reads it:
      `pubspec.yaml`, `ios/meta_wearables_dat_flutter.podspec`,
      `pluginVersion` in `MetaWearablesDatPlugin.swift`, `version` in
      `android/build.gradle`, and the top `CHANGELOG.md` entry.
- [ ] SDK pins agree: `Package.swift` (`exact:`), the Swift
      `sdkVersion`, and `mwdat_version` in `android/build.gradle`.
- [ ] `CHANGELOG.md` has Added / Changed / Deprecated / Removed / Fixed
      sections and migration notes for breaking changes.
- [ ] README and `doc/` show the new install snippet and requirements.

```bash
dart run tool/check_versions.dart --tag v1.0.0-rc.1
dart run tool/check_channel_parity.dart
flutter test --coverage && dart run tool/coverage_gate.dart --min 90
flutter pub publish --dry-run
```

## 2. Automated checks

- [ ] **CI green** on the release commit (`.github/workflows/ci.yml`):
      format, analyze (`--fatal-infos --fatal-warnings`), unit tests
      with the coverage gate, channel parity, version consistency,
      publish dry-run, pana; Android build, Kotlin unit tests, merged
      manifest check, release (R8) build and the
      `mwdat.experimental=false` build; iOS simulator build, Swift unit
      tests (RunnerTests), archive without codesign; samples; Mock
      Device Kit integration tests on the iOS Simulator and the Android
      emulator.
- [ ] **Nightly green** (`.github/workflows/nightly.yml`) for the last
      run before the release: Mock Device Kit integration on Android
      API 31, 34 and 35, and the Flutter beta canary build (iOS
      simulator and Android debug, Xcode 26.6).

## 3. Manual real-device matrix

Run on real glasses, with Meta AI V290+ and firmware V128+.

| Glasses | iOS | Android |
| --- | --- | --- |
| Ray-Ban Meta (Gen 2) | 17.2, 18, 26 | 12, 14, 15+ |
| Oakley Meta | 18 | 14 |
| Meta Ray-Ban Display | 18, 26 | 14, 15+ |

Record each cell as pass/fail with the build number and attach
`dumpDiagnostics()` output to the release PR.

### Scenarios per cell

Registration and permissions

- [ ] App-initiated registration (`startRegistration`) from a clean
      install.
- [ ] Meta-AI-initiated registration (`registrationRequestStream`):
      continue, cancel, and an expired request.
- [ ] Unregistration (`startUnregistration`) and removal from Meta AI.
- [ ] `Permission.camera` grant and deny; `Permission.microphone`.

Streaming

- [ ] `raw` and `hvc1`, each at `low`, `medium` and `high` quality.
- [ ] Frame rates 2, 7, 15, 24 and 30 fps (spot-check per codec).
- [ ] Captouch tap pauses and resumes (`paused` then `streaming`).
- [ ] Closing the hinges ends the stream (`hingesClosed`, then
      `stopped`), texture released.
- [ ] Doff pauses, don resumes.
- [ ] Background: iOS without `enableBackgroundStreaming` stops
      (`stoppedInBackground`); with it, `hvc1` keeps flowing and `raw`
      pauses (`rawPausedInBackground`); Android foreground service and
      notification.
- [ ] `capturePhoto` as `jpeg` and `heic`.
- [ ] `videoFramesStream` for both codecs; `captureStreamFrame`.

Display (Ray-Ban Display only)

- [ ] `startDisplaySession`, a view with every component, button
      callbacks, `DisplayButtonGroup` focus, `actionRole`.
- [ ] `VideoPlayer` playback events; `stopDisplayVideo`; `clearDisplay`.
- [ ] Back gesture ends the session; dim and sleep timing.
- [ ] Display and camera at the same time (shared device session).

Device state and updates

- [ ] `deviceStateStream`: battery, charging, don, hinge, link.
- [ ] Thermal: warm the glasses with a long `high`/`fps30` stream and
      confirm `thermalLevel` changes and the stream errors
      (`thermalHot`) are reported.
- [ ] Update errors: `datAppOnTheGlassesUpdateRequired` (when
      reproducible) opens the update flow via `openDatGlassesAppUpdate`;
      `openFirmwareUpdate` deep-links into Meta AI.

Experimental

- [ ] Inputs, Motion, Speech, voice invocations, `captureHighResPhoto`,
      in-stream audio.
- [ ] Android build with `mwdat.experimental=false`:
      `EXPERIMENTAL_NOT_LINKED` for Inputs, Motion and Speech.

Resources

- [ ] 20 x start/stop of the stream (and of the display on Ray-Ban
      Display): `dumpDiagnostics().isIdle` is `true` afterwards, no
      memory growth.
- [ ] `dumpDiagnostics()` output attached to the release PR.

## 4. Release candidate

- [ ] Set the version to `1.0.0-rc.1` (all files above, CHANGELOG
      heading `## 1.0.0-rc.1`).
- [ ] Tag and push:

```bash
git tag v1.0.0-rc.1
git push origin v1.0.0-rc.1
```

- [ ] `.github/workflows/release.yml` runs: `verify-tag`
      (`check_versions.dart --tag`), the full CI, then `publish`.
- [ ] Approve the **`pub.dev` environment** deployment in GitHub. The
      job publishes with an OIDC token (`id-token: write`); no pub.dev
      credentials are stored in the repository. Automated publishing
      must be enabled on pub.dev for this repository with tag pattern
      `v{{version}}`.
- [ ] The GitHub release is created as a prerelease with notes from
      `CHANGELOG.md`.
- [ ] Install `^1.0.0-rc.1` in a fresh app and in both samples; repeat
      a subset of the device matrix.

## 5. Final release

- [ ] Fix anything found in the rc (`-rc.2`, ... as needed).
- [ ] Set the version to `1.0.0`, CHANGELOG heading `## 1.0.0`.
- [ ] `dart run tool/check_versions.dart --tag v1.0.0`
- [ ] Tag `v1.0.0`, push, approve the `pub.dev` environment.
- [ ] Check the pub.dev page: score, platforms, README rendering,
      unofficial disclaimer at the top.
- [ ] Announce; update issue templates if requirements changed.
