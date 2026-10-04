# meta_wearables_dat_flutter — AI Instructions

> Full Meta Wearables DAT API reference: <https://wearables.developer.meta.com/llms.txt?full=true>
>
> Meta Wearables Developer docs: <https://wearables.developer.meta.com/docs/develop/>
>
> Plugin docs: [`doc/`](doc/)

This file is the canonical context for AI coding assistants working on
`meta_wearables_dat_flutter`. The `.claude/skills/`, `.cursor/rules/`, and
`.github/copilot-instructions.md` configs are all generated from the same
knowledge captured here. When they disagree, this file and the code win.

## Identity

- GitHub org: iSee-Labs
- Repo: <https://github.com/iSee-Labs/meta-wearables-dat-flutter>
- Package name (pub.dev): `meta_wearables_dat_flutter`
- Version: **1.0.0**, targeting Meta Wearables Device Access Toolkit
  (DAT) **1.0.0**. Previous release: 0.7.1 (DAT 0.7.0, commit `8bcc8d3`).
- License: MIT
- Copyright holder: iSee Labs
- Maintainer: Talha Ordukaya

## What this project is

An **unofficial** Flutter plugin that bridges Meta's official iOS and
Android Wearables Device Access Toolkit (DAT) SDKs. Provides a unified
Dart API for Flutter apps integrating with Meta AI Glasses
(Ray-Ban Meta, Ray-Ban Meta Optics, Oakley Meta HSTN / Vanguard,
Meta Ray-Ban Display).

## What this project is NOT

- NOT a reimplementation of Meta's SDK. Meta's SDKs are closed-source
  binaries that we link as dependencies.
- NOT affiliated with, endorsed by, or sponsored by Meta Platforms, Inc.
  The README must include an unofficial disclaimer at the very top,
  BEFORE the title. "Meta", "Ray-Ban Meta", "Oakley Meta" are trademarks
  of their respective owners.
- NOT App Store ready. Meta's iOS guide still says App Store publishing is
  not supported. Distribute via Developer Mode and the invite-only **Beta
  release channel** in the Wearables Developer Center. Experimental APIs
  can never ship to production release channels.

## Versioning policy

- Plugin `major.minor` tracks Meta's DAT `major.minor`; the patch is ours.
- `@experimental` APIs are excluded from semver.
- `tool/check_versions.dart` enforces agreement between `pubspec.yaml`,
  the podspec, Swift `pluginVersion`, `android/build.gradle` `version`,
  the top `CHANGELOG.md` entry, and the SDK pins (`Package.swift`
  `exact:`, Swift `sdkVersion`, Android `ext.mwdat_version`).

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│ Dart facade   lib/meta_wearables_dat_flutter.dart                │
│ • abstract final class MetaWearablesDat (static API)             │
│ • sealed DatError hierarchy, models in lib/src/models/**         │
│ • lib/experimental.dart re-exports experimental models           │
│ • lib/src/channels.dart = single source of channel names         │
└──────────────────────────────────────────────────────────────────┘
        │ MethodChannel                      │ 34 EventChannels
        │ meta_wearables_dat_flutter         │ meta_wearables_dat_flutter/<name>
        │ (67 methods)                       │ (see table below)
   ┌────┴──────────────────────────┐   ┌─────┴─────────────────────────────┐
   │ iOS (Swift, SPM only)          │   │ Android (Kotlin)                   │
   │ MetaWearablesDatPlugin         │   │ MetaWearablesDatPlugin             │
   │ WireCodec                      │   │ WireCodec                          │
   │ DeviceSessionHub               │   │ DeviceSessionHub                   │
   │ MetaSessionManager             │   │ MetaSessionManager                 │
   │  + FramePump (texture)         │   │  + HevcSurfaceDecoder, HevcNal,    │
   │  + VTDecompressionPipeline     │   │    YuvToArgb                       │
   │ MetaDisplayManager+DisplayNode │   │ MetaDisplayManager + DisplayNode   │
   │ MetaMockDeviceManager          │   │ MetaMockDeviceManager              │
   │ DeviceStateObserver            │   │ DeviceStateObserver                │
   │ RegistrationBridge             │   │ RegistrationBridge                 │
   │ ExperimentalBridges            │   │ ExperimentalCapabilities           │
   │ BackgroundStreamingController  │   │  (src/experimental | noexperimental)│
   │ InfoPlistValidator             │   │ VoiceInvocationsBridge             │
   │ ResourceLedger                 │   │ BackgroundStreamingService         │
   │ EventSinkHandler               │   │ ManifestDiagnostics                │
   │ StreamSessionArgs              │   │ ResourceLedger, EventSinkHandler,  │
   │ PrivacyInfo.xcprivacy          │   │ StreamSessionArgs                  │
   └────────┬───────────────────────┘   └────────┬───────────────────────────┘
            │                                     │
   facebook/meta-wearables-dat-ios       com.meta.wearable:mwdat-*:1.0.0
   exact 1.0.0 (SPM)                     (Maven Central)
   MWDATCore  MWDATCamera                Kotlin packages com.meta.wearable.dat.
   MWDATDisplay  MWDATMockDevice           core, camera, display, mockdevice,
   MWDATInputs MWDATMotion MWDATSpeech     inputs, motion, speech
```

Sources:
`ios/meta_wearables_dat_flutter/Sources/meta_wearables_dat_flutter/`,
`android/src/main/kotlin/com/iseelabs/meta_wearables_dat_flutter/`
(+ `android/src/experimental/` and `android/src/noexperimental/`
providing `ExperimentalCapabilitiesImpl`).

### Event channels (34, from `DatChannels.events`)

Prefix `meta_wearables_dat_flutter/`.

| Area | Channels |
|------|----------|
| Registration | `registration_state`, `registration_errors`, `registration_requests` |
| Devices | `active_device`, `devices`, `device_state`, `compatibility` |
| Device session | `device_session_state`, `device_session_errors` |
| Camera | `stream_session_state`, `stream_session_errors`, `camera_state`, `video_stream_size`, `video_frames`, `audio_frames` |
| HQ photo (exp.) | `photo_state`, `photo_progress`, `photo_errors` |
| Display | `display_state`, `display_events`, `display_errors` |
| Inputs (exp.) | `inputs_state`, `inputs_events`, `inputs_errors` |
| Motion (exp.) | `motion_state`, `motion_samples`, `motion_errors` |
| Speech (exp.) | `speech_state`, `speech_transcriptions`, `speech_errors` |
| Voice (exp.) | `voice_invocations`, `voice_state`, `voice_errors` |
| Mock | `mock_devices` |

`display_events` carries taps, clicks, playback events and build warnings.
State channels replay their last value to each new listener.

### Module layout

The plugin links 7 DAT modules and keeps a 1-to-1 mapping:

- **Core** — registration, Meta AI-initiated registration requests,
  device discovery and state, permissions, selectors, `DeviceSession`,
  and **voice invocations** (`core.voiceinvocations` on Android).
- **Camera** — `Stream`, `VideoFrame`, `PhotoData`, in-stream audio,
  high-resolution photo.
- **Display** — `Display`, `DisplayState`, the component DSL
  (`FlexBox`, `Text`, `Image`, `Button`, `ButtonGroup`, `Icon`,
  `VideoPlayer`) and playback events.
- **MockDevice** — Mock Device Kit (dev/test only).
- **Inputs** (experimental) — touchpad, buttons, Meta Neural Band.
- **Motion** (experimental) — IMU samples.
- **Speech** (experimental) — on-device transcription.

### DeviceSessionHub (shared session)

One `DeviceSession` per device is shared by camera, display and every
experimental capability. Owners `acquire` the session under an owner name
and `release` it when they stop; the session stops when the last owner
releases. A terminal STOPPED (hinges closed, device gone) notifies every
owner so it frees its own resources.

### Wire contract v2

- State channels carry **strings** (enum names), never ints.
- Method errors: `PlatformException(code: CATEGORY, details: {case,
  description, platformCase, platform})`.
- Event errors: `{code: case, category, message, platformCase, platform}`.
- Mapping lives in `WireCodec.swift` / `WireCodec.kt` and
  `lib/src/error_mapping.dart`.

### Error model

Sealed `DatError` (`lib/src/models/dat_error.dart`). Every error has
`category` (a `DatErrorCodes` constant, e.g. `STREAM_ERROR`), `code`
(canonical case name, = iOS Swift case name, e.g. `hingesClosed`),
`message`, `platformCase` (raw native name), `platform`, and
`recoveryAction` (`DatRecoveryAction`: `none`, `openFirmwareUpdate`,
`openDatGlassesAppUpdate`, `updateHostApp`, `suggestUpdate`,
`checkMetaAiAndRetry`, `connectGlasses`, `grantPermission`).
Typed subclasses expose `reason` (a `*ErrorCase` enum):

`RegistrationError`, `UnregistrationError`, `HandleUrlError`,
`RegistrationRequestError`, `PermissionError`, `NavigationError`,
`DeviceSessionError` (`isTerminal`, `isWarning`), `StreamError`,
`CaptureError`, `PhotoError`, `DisplayError`, `InputsError`,
`MotionError`, `SpeechError`, `VoiceInvocationError`,
`MockDeviceKitError`, plus `DatArgumentError` (`INVALID_ARGUMENT`) and
`DatPluginError` (`PLUGIN_ERROR`, `NOT_SUPPORTED`,
`EXPERIMENTAL_NOT_LINKED`; `isExperimentalNotLinked`).

```dart
switch (error) {
  StreamError(reason: StreamErrorCase.hingesClosed) => askToOpenHinges(),
  DeviceSessionError(isTerminal: true) => showUpdateRequired(),
  _ => showMessage(error.message),
}
```

### Experimental policy

- Inputs, Motion, Speech, voice invocations, `captureHighResPhoto`
  (+ photo streams) and in-stream audio (`AudioStreamConfig`,
  `audioFramesStream`) are annotated `@experimental` and also exported via
  `package:meta_wearables_dat_flutter/experimental.dart`.
- Apps using them cannot ship to production release channels. Inputs and
  voice invocations also need approval in Wearables Developer Center.
- Android: `mwdat.experimental=false` in the app's
  `android/gradle.properties` (or `--android-project-arg=mwdat.experimental=false`)
  drops the inputs/motion/speech AARs and compiles
  `src/noexperimental`; Inputs/Motion/Speech calls then throw
  `DatPluginError` with category `EXPERIMENTAL_NOT_LINKED`. Voice
  invocations (Core), high-res photo and audio (Camera) stay available.
- iOS always links all 7 products.
- `dumpDiagnostics().experimentalModulesLinked` reports what is linked.

## Performance constraints (non-negotiable)

- **Texture path:** decoded preview frames go through the Flutter texture
  registry (`FramePump` on iOS; `SurfaceTexture`/`TextureRegistry` on
  Android, `HevcSurfaceDecoder` for `hvc1`). NEVER serialize decoded
  preview frames over `MethodChannel`.
- **`videoFramesStream`:** opt-in, gated on subscriber count. 720x1280
  raw is ~1.4 MB I420 / ~3.7 MB BGRA per frame. Document the cost.
- **Backpressure:** sinks are set in `onListen` and nulled in `onCancel`;
  native stops emitting when Dart stops listening.
- **Lifecycle:** `stopStreamSession()` unregisters the texture; after
  every stop the `ResourceLedger` (`dumpDiagnostics().resources`) must
  return to zero (`isIdle`).

## Coding conventions

- Dart: `very_good_analysis`, `flutter analyze --fatal-infos` clean,
  dartdoc on every public API. All public APIs return `Future<T>` or
  `Stream<T>`, never callbacks (display DSL handlers are the exception).
- Swift: follow Meta's iOS sample style. `async`/`await` for SDK calls,
  `AnyListenerToken.cancel()` for listeners, `@MainActor` for UI- and
  channel-touching code. Swift language mode 5.
- Kotlin: follow Meta's Android sample style. `Flow`/`StateFlow` with
  `collectLatest`; coroutine scopes torn down in `stop*`.

## Hard-won rules

- Android `StateFlow`s (device session, display, capabilities) start at
  `STOPPED` before the device answers. Never treat the initial value as
  terminal; only a STOPPED after leaving STOPPED is terminal.
- Public Dart streams must not use `async*` with awaited teardown:
  `first`/`firstWhere` await cancel, so the stream hangs. Use a
  `StreamController` with a non-awaiting `onCancel` (see
  `deviceStateStream`).
- Add an event channel in Dart (`DatChannels`), Swift and Kotlin in the
  same change; keep `dart run tool/check_channel_parity.dart` green.
  Same for method names.
- Android display builders: pass arguments by name
  (`scope.button(label = ..., actionRole = ...)`); parameter order differs
  from iOS and between releases.
- iOS `IconName` raw values are snake_case (`checkmark_circle`); Dart
  `DisplayIconName` is camelCase. `DisplayNode.swift` converts.
  Regenerate Dart names with `dart run tool/gen_icon_names.dart`.
- Do not call Android `display.stop()`; detach with
  `session.removeDisplay()` only (`stop()` first can NPE inside the SDK).
- Below iOS 26, anything that calls `objc_copyClassList` (XCTest, some
  SDKs) aborts inside MWDATCore: it weakly links iOS 26-only Network /
  WiFiAware types. Run Swift tests on an iOS 26+ simulator. Never add class
  enumeration to the plugin. See doc/troubleshooting.md "Known issues".
- Android `MainActivity` must extend `FlutterFragmentActivity`.

## Critical native-side requirements

### Toolchain floors

- Flutter **>= 3.44.0** (SPM default), Dart `^3.8.0`.
- Xcode **26.4+** (Meta binaries built with Swift 6.3).
- Meta AI app V290+, glasses firmware V128+.

### iOS

- **Swift Package Manager only.** `Package.swift` pins
  `facebook/meta-wearables-dat-ios` `exact: "1.0.0"`. The podspec exists
  only for tooling; never advertise CocoaPods.
- Minimum iOS **17.2**.
- `Info.plist` (validated at runtime by `dumpDiagnostics` findings):
  `MWDAT` dict (`AppLinkURLScheme` ending with `://` and registered in
  `CFBundleURLTypes`, `MetaAppID`, `ClientToken`, `TeamID`),
  `LSApplicationQueriesSchemes` with `fb-viewapp`,
  `UISupportedExternalAccessoryProtocols` with `com.meta.ar.wearable`,
  `UIBackgroundModes` with `bluetooth-central` and `external-accessory`
  (`bluetooth-peripheral`, `processing` recommended),
  `NSBluetoothAlwaysUsageDescription`, `NSLocalNetworkUsageDescription`,
  `NSBonjourServices`, `NSMicrophoneUsageDescription` (speech/audio).
  `DAMEnabled` is obsolete.
- The plugin registers as an application delegate and forwards
  callback URLs itself.
- Stream session ends on `didEnterBackground` unless
  `enableBackgroundStreaming` was called; raw frames pause in background,
  `hvc1` continues.

### Android

- Artifacts on **Maven Central**
  (`com.meta.wearable:mwdat-{core,camera,display,mockdevice,inputs,motion,speech}:1.0.0`).
  No GitHub Packages, no `GITHUB_TOKEN`.
- `minSdk 31`, `compileSdk 36`, Kotlin 2.2.21, AGP 8.11.1, JVM 17.
- `MainActivity` extends `FlutterFragmentActivity`.
- Manifest meta-data `com.meta.wearable.mwdat.APPLICATION_ID` and
  `CLIENT_TOKEN`; `DAM_ENABLED` is obsolete. `ManifestDiagnostics`
  reports findings.
- Plugin merges `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`,
  `WAKE_LOCK`, `POST_NOTIFICATIONS` and `BackgroundStreamingService`.

### Meta developer setup

- Developer Mode: Meta AI app → Settings → App Info → tap the version
  5 times.
- Create a **new app version in Wearables Developer Center** for 1.0
  builds.

## Public API surface (1.0.0)

Static facade `MetaWearablesDat`. Exact signatures and dartdoc in
`lib/meta_wearables_dat_flutter.dart`. (exp.) = `@experimental`.

### Platform & diagnostics

- `getPlatformVersion()`, `dumpDiagnostics()` → `DatDiagnostics`
  (`platform`, `pluginVersion`, `sdkVersion`, `wearablesConfigured`,
  `registrationState`, `devices`, `findings` / `errors`, `resources`,
  `isIdle`, `experimentalModulesLinked`).
- `requestAndroidPermissions()` — Android runtime permissions; `true` on iOS.

### Registration

- `startRegistration()`, `startUnregistration()`, `handleUrl(url)`,
  `getRegistrationState()`.
- `registrationStateStream()` (`unavailable`, `available`, `registering`,
  `registered`, `unregistering`), `registrationErrorStream()`,
  `registrationRequestStream()` → `RegistrationRequest`
  (`continueRegistration()` / `cancel()`, answer once, 5-minute expiry).

### Permissions & Meta AI navigation

- `requestPermission(Permission)`, `checkPermissionStatus(Permission)` →
  `PermissionStatus` (`granted`/`denied`); `Permission.camera`,
  `Permission.microphone`.
- `requestCameraPermission()`, `getCameraPermissionStatus()` — deprecated shims.
- `openFirmwareUpdate()`, `openDatGlassesAppUpdate()` (`NavigationError`).

### Devices & device session

- `getDevices()`, `getDevice(uuid)`, `getSessionDevice()`.
- `devicesStream()`, `deviceStateStream(uuid)` (snapshot then live),
  `activeDeviceStream()`, `compatibilityStream()`.
- `DeviceInfo`: `uuid`, `name`, `kind`, `type`, `linkState`,
  `compatibility`, `batteryLevel`, `chargingState`, `donState`,
  `hingeState`, `thermalLevel` (`isThrottling`, `isCritical`),
  `supportsDisplay`, `isMock`, `isConnected`.
- `deviceSessionStateStream()` (`idle`, `starting`, `started`, `paused`,
  `stopping`, `stopped`), `deviceSessionErrorStream()`.

### Camera

- `startStreamSession({deviceUUID, config: StreamSessionConfig(quality,
  frameRate, videoCodec, deviceKinds, audio (exp.))})` → `int textureId`.
  Legacy `fps`/`quality`/`videoCodec`/`deviceKinds` args are deprecated.
- `stopStreamSession()`.
- `streamSessionStateStream()` (`stopped`, `waitingForDevice`,
  `starting`, `streaming`, `paused`, `stopping`), `streamErrorStream()`
  (`streamSessionErrorStream()` deprecated), `cameraStateStream()`,
  `videoStreamSizeStream()` (emits on change).
- `videoFramesStream()` (opt-in), `audioFramesStream()` (exp.).
- `capturePhoto({format: PhotoFormat.jpeg|heic})` → `PhotoResult`.
- `captureHighResPhoto({resolution, quality})` → `HighResPhoto`,
  `photoTransferProgressStream()`, `photoStateStream()`,
  `photoErrorStream()` (all exp.).
- `captureStreamFrame(textureId, {format})` → `FrameData?` (Dart-side,
  no native round trip).
- `enableBackgroundStreaming({androidNotification})`,
  `disableBackgroundStreaming()`.

### Display (Ray-Ban Display)

- `startDisplaySession({deviceUUID})`, `sendDisplayView(DisplayView)` →
  `List<String>` build warnings, `clearDisplay()`, `stopDisplayVideo()`,
  `stopDisplaySession()`.
- `displayStateStream()` (`starting/started/stopping/stopped`),
  `displayErrorStream()`, `displayWarningStream()`.
- DSL: `FlexBox`, `DisplayText`, `DisplayImage` / `DisplayImage.bytes`,
  `DisplayButton` (`actionRole`), `DisplayButtonGroup`, `DisplayIcon`
  (116 `DisplayIconName`, `DisplayIconStyle`), `VideoPlayer` (https MP4,
  root only), `DisplayEdgeInsets`, `DisplayNode.validate()`. Callbacks:
  `onTap`, `onClick`, `onPlaybackEvent`.

### Experimental (all `@experimental`)

- Inputs: `startInputs({configuration, deviceUUID})`, `stopInputs()`,
  `inputEventsStream()` (`NavInputEvent`, `SelectInputEvent`,
  `BackInputEvent`, `ButtonInputEvent`, `CaptureInputEvent`,
  `DragInputEvent`, `UnknownInputEvent`), `inputsStateStream()`,
  `inputsErrorStream()`.
- Motion: `startMotion({samplingRate, deviceUUID})`, `stopMotion()`,
  `motionSamplesStream()`, `motionStateStream()`, `motionErrorStream()`.
- Speech: `startSpeech({deviceUUID})`, `stopSpeech()`,
  `transcriptionStream()`, `speechStateStream()`, `speechErrorStream()`.
- Voice invocations: `startVoiceInvocations({deviceUUID})`,
  `stopVoiceInvocations()`, `voiceInvocationsStream()` (answer each with
  `respondSuccess` / `respondFailure` exactly once),
  `voiceInvocationsStateStream()`, `voiceInvocationErrorStream()`.

### Mock Device Kit

- `enableMockDevice({initiallyRegistered, initialPermissionsGranted})`,
  `disableMockDevice()`, `isMockDeviceEnabled()`.
- `pairMockGlasses([MockGlassesModel])` → `DeviceInfo`
  (`pairMockRayBanMeta()` deprecated), `pairedMockDevices()`,
  `unpairMockDevice(uuid)`, `mockDevicesStream()`.
- `mockPowerOn/Off`, `mockDon/Doff`, `mockFold/Unfold`, `mockTap`,
  `mockTapAndHold` (all `(uuid)`).
- `setMockBatteryLevel`, `setMockChargingState`, `setMockThermalLevel`,
  `setMockCameraFacing`, `setMockCameraFeed`, `setMockCapturedImage`,
  `setMockPermission`, `setMockPermissionRequestResult`.
- Exp. simulators: `setMockCapturedPhoto`, `simulateMockCaptureFailure`,
  `mockInputNav/Select/Back/Capture/Button/Drag`, `setMockSpeechSource`,
  `simulateMockTranscription`, `simulateMockSpeechError`,
  `simulateMockSpeechCompletion`, `setMockMotionFeed`,
  `simulateMockVoiceInvocation`.
- `startMockTestServer({port = 9000})`, `stopMockTestServer()`,
  `sendMockDisplayClick(uuid, identifier)`.

### Removed in 1.0

`pauseStreamSession`/`resumeStreamSession`, `sessionStateStream`,
`sessionErrorStream`, `SessionState`, `startRegistration(appId:,
urlScheme:)` parameters, `DatErrorCodes` sub-code constants (categories
remain). `fromInt` helpers are deprecated.

## How we work

- Build in vertical slices: one feature working end-to-end
  (Dart → iOS → Android → sample) before starting the next.
- After every slice, all quality gates green:
  - `flutter analyze --fatal-infos` (root, `example/`, samples)
  - `dart format --set-exit-if-changed lib test tool example/lib example/integration_test samples`
  - `flutter test --coverage` then `dart run tool/coverage_gate.dart --min 90`
  - `dart run tool/check_channel_parity.dart`
  - `dart run tool/check_versions.dart`
  - Kotlin unit tests:
    `cd example/android && ./gradlew :meta_wearables_dat_flutter:testDebugUnitTest`
  - Swift `RunnerTests` (`example/ios`) on an **iOS 26+** simulator
  - Integration (Mock Device Kit):
    `cd example && flutter test integration_test/plugin_test.dart -d <device>`
  - `flutter build ios --debug --simulator` and `flutter build apk --debug`
    in `example/`, `samples/camera_access/`, `samples/display_access/`,
    `samples/glasses_companion/`
- CI: `.github/workflows/ci.yml` (all of the above plus
  `mwdat.experimental=false` build, pana, publish dry-run),
  `release.yml` (tag `vX.Y.Z` → `check_versions --tag` → CI → OIDC
  pub.dev publish behind the `pub.dev` environment approval → GitHub
  release), `nightly.yml`.
- Commit after each completed slice with a conventional-commit message
  (e.g. `feat: add deviceStateStream`).
- When uncertain, STOP and ask. Do not guess at Meta SDK behavior — read
  the reference SDKs and docs first.

## Reference implementations

- `../meta-glasses-research/meta-wearables-dat-ios/` — official iOS SDK +
  sample app (also ships the `mwdat-ios` Claude plugin).
- `../meta-glasses-research/meta-wearables-dat-android/` — official
  Android SDK + sample app (also ships the `mwdat-android` Claude plugin).
- `../meta-glasses-research/flutter_meta_wearables_dat/` — community
  Flutter plugin (rodcone). Design reference only; never copy wholesale.
- MCP server `meta-wearables` (<https://mcp.developer.meta.com/wearables>,
  tool `search_dat_docs`) for current Meta docs.

## See also

- [`doc/`](doc/) — getting started, registration, streaming, frame
  processing, device state, display access, experimental, mock device,
  troubleshooting, and `migration_0.7_to_1.0.md`.
- [`CHANGELOG.md`](CHANGELOG.md) — 1.0 breaking changes and fixes.
- [`.claude/skills/`](.claude/skills/) — per-topic AI skill files.
- [`.cursor/rules/`](.cursor/rules/) — Cursor rule with the same content.
- [`.github/copilot-instructions.md`](.github/copilot-instructions.md) —
  Copilot pointer to this file.
