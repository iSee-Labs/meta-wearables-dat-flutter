# Changelog

All notable changes to this project will be documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0

Moves the plugin to Meta Wearables Device Access Toolkit (DAT) **1.0.0**,
Meta's first stable, supported release. This is a breaking release; follow
[`doc/migration_0.7_to_1.0.md`](doc/migration_0.7_to_1.0.md).

### Highlights

- Native pins: `facebook/meta-wearables-dat-ios` `exact: "1.0.0"` and
  `com.meta.wearable:mwdat-*:1.0.0` from Maven Central.
- Android SDK artifacts now come from Maven Central. No GitHub Packages
  repository and no `GITHUB_TOKEN` are needed.
- Typed, sealed error model with per-category reason enums and a suggested
  `DatRecoveryAction`.
- `hvc1` texture preview on Android (MediaCodec), matching iOS.
- Live device state: battery, charging, wear, hinge, thermal level, link
  state and compatibility.
- Registrations started from the Meta AI app (`registrationRequestStream`).
- `dumpDiagnostics()` returns a typed `DatDiagnostics` that validates
  Info.plist / AndroidManifest configuration and reports held native
  resources.
- Bridges DAT 1.0's experimental modules (Inputs, Motion, Speech, voice
  invocations, high-resolution photo, in-stream audio) behind
  `@experimental`.

### Breaking changes

- Toolchain: Flutter >= 3.44.0, Dart ^3.8.0, Xcode 26.4+, iOS 17.2 minimum.
  iOS resolves only through Swift Package Manager; CocoaPods is no longer
  supported for this plugin.
- Android: remove the GitHub Packages Maven repository and token
  configuration from your Gradle files.
- Developer Center: create a new app version for builds made with DAT 1.0.
- `DatError` is now a sealed hierarchy. `DatError.code` is the specific case
  name (for example `hingesClosed`); the former meaning of `code` (for
  example `STREAM_ERROR`) moved to the new `DatError.category`. `details` is
  now a `Map<String, Object?>`.
- `SessionError` is replaced by `StreamError` (category `STREAM_ERROR`
  instead of `SESSION_ERROR`). `SessionError` remains as a typedef.
- `dumpDiagnostics()` returns `DatDiagnostics` instead of
  `Map<String, Object?>` (the map is still available as `raw`).
- `deviceSessionErrorStream()` emits `DeviceSessionError` instead of
  `Object`.
- `sendDisplayView()` returns `Future<List<String>>` (substitution warnings)
  instead of `Future<void>`.
- `stopStreamSession()` and `capturePhoto()` no longer take `deviceUUID`;
  they act on the running stream.
- `setMockCameraFeed()` and `setMockCapturedImage()` take a non-null
  `filePath`.
- `setMockPermission()` / `setMockPermissionRequestResult()` take
  `Permission` / `PermissionStatus` (`MockPermission` and
  `MockPermissionStatus` are deprecated typedefs of those).
- State enums (`RegistrationState`, `StreamSessionState`,
  `DeviceSessionState`, `DisplayState`) no longer carry an integer `value`;
  state travels as a string on the platform channels. Use `fromWire`.
- Default stream frame rate is 24 fps (was 30), matching the SDK default.
- `MWDAT > DAMEnabled` (iOS) and `com.meta.wearable.mwdat.DAM_ENABLED`
  (Android) are obsolete and ignored.

### Added

- `StreamSessionConfig` (`quality`, `frameRate` as `StreamFrameRate`,
  `videoCodec`, `deviceKinds`, experimental `audio`) for
  `startStreamSession(config: ...)`.
- `streamErrorStream()`, `cameraStateStream()` (`CameraState`).
- `RegistrationState.unregistering`,
  `registrationErrorStream()`, `registrationRequestStream()` with
  `RegistrationRequest.continueRegistration()` / `cancel()`.
- `requestPermission(Permission)` and `checkPermissionStatus(Permission)`
  returning `PermissionStatus`; `Permission.microphone`.
- `openFirmwareUpdate()` and `openDatGlassesAppUpdate()`.
- `getDevice(uuid)`, `getSessionDevice()`, `deviceStateStream(uuid)`.
  `DeviceInfo` gains `type` (`DeviceType`), `linkState`, `compatibility`,
  `batteryLevel`, `chargingState`, `donState`, `hingeState`,
  `thermalLevel`, `supportsDisplay` and `isMock`. `DeviceKind.metaGlasses`.
- `VideoFrame.pixelFormat` (`i420`, `nv12`, `bgra`), `planes`
  (`VideoFramePlane`) and `isCodecConfig`.
- `PhotoResult.format` reports the actual encoding.
- Display: `clearDisplay()`, `stopDisplayVideo()`, `displayErrorStream()`,
  `displayWarningStream()`, `DisplayButtonGroup`, `DisplayImage.bytes`,
  `DisplayButton.actionRole`, `DisplayIcon.style`, `DisplayEdgeInsets`
  (`FlexBox.paddingInsets`), `flexGrow` / `flexShrink` / `alignSelf` on every
  node, `DisplayNode.validate()`, and the full `DisplayIconName` set (116
  icons).
- Errors: `RegistrationRequestError`, `NavigationError`, `StreamError`,
  `PhotoError`, `DisplayError`, `InputsError`, `MotionError`,
  `SpeechError`, `VoiceInvocationError`, `MockDeviceKitError`,
  `DatArgumentError`, `DatPluginError`; `DatError.platformCase`,
  `DatError.platform`, `DatError.recoveryAction` (`DatRecoveryAction`);
  `DeviceSessionError.isTerminal` / `isWarning`; `StreamError.isFatal` /
  `isWarning`.
- `DatDiagnostics`: `findings` (`DatFinding` with `id`, `severity`,
  `message`, `fix`), `errors`, `resources`, `isIdle`,
  `experimentalModulesLinked`.
- Mock Device Kit: `pairMockGlasses(MockGlassesModel)` returning
  `DeviceInfo`, `mockTap`, `mockTapAndHold`, `setMockBatteryLevel`,
  `setMockChargingState`, `setMockThermalLevel`, `startMockTestServer`,
  `stopMockTestServer`, `sendMockDisplayClick`.
- Diagnostics findings for Info.plist (iOS) and AndroidManifest (Android).
- Tests and tooling: 125 Dart unit tests, Kotlin and Swift unit tests, Mock
  Device Kit integration tests, channel-parity, version-agreement and
  coverage-gate tools, and release / nightly CI workflows.

### Changed

- Plugin version tracks Meta's DAT version (major.minor); the patch number is
  the plugin's own. `@experimental` APIs are excluded from semantic
  versioning.
- One device session per device is shared by camera, display and the
  experimental capabilities; it stays open while any of them runs.
- iOS: the stream session ends when the app enters the background unless
  `enableBackgroundStreaming()` was called. Raw frames pause in the
  background; `hvc1` continues.
- `videoStreamSizeStream()` emits only when the size changes.
- State streams replay the last value to new listeners.

### Deprecated

- `startStreamSession(fps:, quality:, videoCodec:, deviceKinds:)`: use
  `config: StreamSessionConfig(...)`.
- `streamSessionErrorStream()`: use `streamErrorStream()`.
- `requestCameraPermission()` / `getCameraPermissionStatus()`: use
  `requestPermission(Permission.camera)` /
  `checkPermissionStatus(Permission.camera)`.
- `pairMockRayBanMeta()`: use `pairMockGlasses(MockGlassesModel.rayBanMeta)`.
- `MockPermission` / `MockPermissionStatus`: use `Permission` /
  `PermissionStatus`.
- The `is*` getters on error classes (for example `isHingesClosed`): switch
  on `reason` instead. They now work; in 0.7 they always returned `false`.
- `fromInt` on state enums: use `fromWire`.
- `DatErrorCodes.session` and `DatErrorCodes.missingFragmentActivity`.
- `FlexBox.cornerRadius`: not supported by the DAT Display SDK; ignored.

### Removed

- `pauseStreamSession()` and `resumeStreamSession()` (they never did
  anything).
- `sessionStateStream()`, `sessionErrorStream()` and the `SessionState`
  typedef.
- `startRegistration(appId:, urlScheme:)` parameters; values come from
  Info.plist / AndroidManifest.
- Sub-code constants in `DatErrorCodes` (for example
  `DatErrorCodes.hingesClosed`); use the `*ErrorCase` enums. Category
  constants remain.

### Fixed

- Typed `is*` getters on errors never matched.
- Android: `handleUrl()` never called the SDK.
- Android: `capturePhoto(format:)` was ignored.
- Android: `enableMockDevice()` ignored `initiallyRegistered` and
  `initialPermissionsGranted`; mock permission setters were no-ops.
- Android: no `hvc1` preview.
- Android: `STARTED` was mapped to `streaming`; default quality was `high`
  while Dart defaulted to `medium`.
- Android: the display was torn down on the initial `STOPPED` state.
- iOS: `video_stream_size` was emitted on every frame.
- iOS: `stopDisplaySession()` leaked its state listener token.
- iOS: `getRegistrationState()` returned a raw ordinal.
- Display DSL: `space*` alignments collapsed and the `large` corner radius
  mapped to `medium`.
- `dumpDiagnostics()` returned a different shape on each platform.
- `deviceStateStream()` could hang `first` / `firstWhere` on cancel.

### Experimental

All APIs below are `@experimental`. Apps that use them can be tested in
Developer Mode and Beta release channels but cannot ship to production
release channels. They are also exported by
`package:meta_wearables_dat_flutter/experimental.dart`.

- Inputs: `startInputs(configuration:)`, `stopInputs`, `inputEventsStream`
  (`NavInputEvent`, `SelectInputEvent`, `BackInputEvent`,
  `ButtonInputEvent`, `CaptureInputEvent`, `DragInputEvent`),
  `inputsStateStream`, `inputsErrorStream`.
- Motion: `startMotion(samplingRate:)`, `stopMotion`, `motionSamplesStream`,
  `motionStateStream`, `motionErrorStream`.
- Speech: `startSpeech`, `stopSpeech`, `transcriptionStream`,
  `speechStateStream`, `speechErrorStream`.
- Voice invocations: `startVoiceInvocations`, `stopVoiceInvocations`,
  `voiceInvocationsStream` (respond exactly once),
  `voiceInvocationsStateStream`, `voiceInvocationErrorStream`.
- High-resolution photo: `captureHighResPhoto(resolution:, quality:)`,
  `photoTransferProgressStream`, `photoStateStream`, `photoErrorStream`.
- In-stream audio: `StreamSessionConfig(audio: AudioStreamConfig(...))`,
  `audioFramesStream`.
- Mock simulators for inputs, speech, motion, voice invocations and
  high-resolution photo capture.
- Android: set `mwdat.experimental=false` in the app's
  `android/gradle.properties` to leave out the `mwdat-inputs`,
  `mwdat-motion` and `mwdat-speech` AARs; experimental calls then throw
  `DatPluginError` with category `EXPERIMENTAL_NOT_LINKED`.

### Migration

See [`doc/migration_0.7_to_1.0.md`](doc/migration_0.7_to_1.0.md).

## 0.7.1

Documentation-only release: README and getting-started guides now show
`^0.7.0` (the install snippet in the 0.7.0 pub publish still said
`^0.2.0` because docs were updated on GitHub after that upload).

## 0.7.0

Aligns the plugin version with Meta's native DAT SDKs and adds **Display
Access**.

### Display Access (new)

- Bridge Meta DAT 0.7.0's `MWDATDisplay` (iOS) / `mwdat-display`
  (Android) module: render a declarative UI tree on Ray-Ban Display
  glasses.
- New Dart API: `startDisplaySession({deviceUUID?})`,
  `sendDisplayView(DisplayView)`, `stopDisplaySession()`, and
  `displayStateStream()` (`DisplayState`:
  `starting/started/stopping/stopped`).
- Component DSL with `toJson` serialization and callback ids: `FlexBox`,
  `DisplayText`, `DisplayImage`, `DisplayButton`, `DisplayIcon`,
  `VideoPlayer`, plus layout / style enums and `onTap` / `onClick` /
  `onPlaybackEvent` callbacks dispatched over a new `display_events`
  EventChannel. Display lifecycle is reported on a new `display_state`
  EventChannel.
- Native `MetaDisplayManager` on both platforms rebuilds the SDK DSL from
  JSON and routes interaction + playback callbacks back to Dart by id.
- New sample app `samples/display_access/` porting Meta's official "Car
  Maintenance" Display sample (list → detail → steps → video).
- New `doc/display_access.md`, `display-access` skill, and Cursor rule
  entries.

### SDK bump

- Update native pins `0.6.0 → 0.7.0` (iOS SPM `meta-wearables-dat-ios`
  + `MWDATDisplay`; Android Maven `mwdat-*` + `mwdat-display`).
- Adapt the camera bridge to 0.7 renames (`Stream` /
  `StreamConfiguration` / `StreamState`) with resilient,
  string-based state/error encoding.
- Add `DeviceSessionError.datAppOnTheGlassesUpdateRequired`
  (`error.isDatAppUpdateRequired`).

## 0.2.0

### Android live preview — correct colours

- Rewrite `YuvToArgb` to mirror the official Meta DAT Android sample's
  `YuvToBitmapConverter`: tightly-packed I420 only (no layout sniffing)
  with BT.709 limited-range coefficients. The previous BT.601 matrix
  produced a green/purple cast on real glasses frames; BT.709 matches
  the codec's advertised `raw.color.matrix = 1`.
- Cache the YUV byte buffer and ARGB int buffer across frames in
  `YuvToArgb` so the hot path is allocation-free. Eliminates ~150 MiB/s
  of GC pressure on a 720p stream and stops mid-stream frame stalls.
- **Fix the "wrong-colour / squashed preview" bug**: call
  `SurfaceTexture.setDefaultBufferSize(width, height)` the first time
  we see a frame (or whenever the resolution changes). Without this
  the canvas returned by `Surface.lockHardwareCanvas()` was sized to
  Flutter's default 1×1 producer buffer and the scale-fit was clamping
  the bitmap into a tiny destination — the preview looked like a flat
  one-colour image even when YUV decode was correct.

### Android session reliability

- Replace `AutoDeviceSelector` with `SpecificDeviceSelector` driven by
  the paired device UUID (matches the iOS path). Resolves
  `SESSION_ERROR: No eligible device found` on the first start when
  Meta AI has just released the device.
- Add an in-process retry loop around `Wearables.createSession` (6
  attempts × 1.5 s) for the transient warm-up failures the underlying
  SDK throws while the glasses transition from `AVAILABLE` to
  `ELIGIBLE_FOR_DAT`.
- Make `AndroidManifest.xml` Developer-Mode-ready in both bundled
  apps: `APPLICATION_ID = "0"`, `CLIENT_TOKEN = "0"`,
  `ANALYTICS_OPT_OUT = "true"`, `DAM_ENABLED = "true"`.

### Sample app

- `samples/camera_access` now fetches the paired device UUID before
  calling `startStreamSession` and shows a "Connecting…" spinner on
  the **Start** button while the retry loop is in flight, so the user
  knows the first tap is doing something. The button is disabled
  during the warm-up window.

### Diagnostics

- Add per-frame Y / chroma min/mean/max diagnostics to `logcat` for
  the first 10 frames of a stream and a 1 Hz heartbeat afterwards.
  Flat Y → SDK is streaming placeholders (glasses not worn). Flat
  chroma + varying Y → real monochrome scene. Catches root-cause
  questions before a screen-recording round-trip with users.

### Docs

- README, `doc/getting_started.md` and `doc/troubleshooting.md` now
  document every Android Developer-Mode meta-data key (including the
  newly-required `DAM_ENABLED`), call out that **Developer Mode in the
  Meta AI app itself must be turned on** as a one-time per-phone step,
  and add a dedicated troubleshooting entry for "No eligible device
  found".

## 0.1.5

- Fix Android `CLIENT_TOKEN` in both bundled apps (`example/` and
  `samples/camera_access/`) — was an empty string `""`, which causes
  the SDK to throw `TOKEN_NOT_CONFIGURED` and silently refuse to
  register even when Developer Mode is on. Set to
  `"developer-mode-placeholder"` (the SDK doesn't validate the value
  when `APPLICATION_ID = "0"`).
- Add `ANALYTICS_OPT_OUT = true` to both Android manifests so failed
  analytics uploads to Meta's servers don't surface as misleading
  "Internal error" toasts during developer testing.
- Same fixes applied to the README and `doc/getting_started.md`
  snippets.

## 0.1.4

- Bump the recommended Android NDK to **28.2.13676358** in the README
  and both bundled samples (`example/`, `samples/camera_access/`).
  Newer Flutter plugin transitive deps (notably `jni`, pulled by
  `share_plus`) require r28.2; AGP enforces "use highest" so any
  consumer that pulls one of those breaks against r27. Meta's
  `mwdat-core` AAR (built against r27) is fine on r28.2 — NDK is
  backward compatible.

## 0.1.3

- Inline the full iOS and Android setup walkthrough in the README so
  the complete setup (deployment target, `MWDAT` dict with Developer
  Mode `MetaAppID = "0"`, `CFBundleURLTypes`,
  `LSApplicationQueriesSchemes`, `UIBackgroundModes`, Bonjour,
  external-accessory protocol, `SceneDelegate.swift`,
  `AndroidManifest.xml` meta-data + deep-link intent-filter,
  GitHub Packages Maven repo) is visible directly on pub.dev — no
  click-through to `doc/getting_started.md` required.
- Add a dedicated "Enable Developer Mode in the Meta AI app" section
  at the top of the setup so the two-sided contract (Meta AI toggle
  ↔ `MetaAppID = "0"`) cannot be missed.

## 0.1.2

- Refresh README title and introduction to match the SDK's full name
  ("Meta Wearables Device Access Toolkit for Flutter") and improve
  first-impression clarity on pub.dev and GitHub.

## 0.1.1

Documentation, deprecation, and discoverability fixes only — no
runtime behaviour changes vs. 0.1.0.

### Deprecated

- `MetaWearablesDat.startRegistration({appId, urlScheme})` — both
  named parameters are now annotated `@Deprecated`. They have always
  been ignored on iOS (`Wearables.shared.startRegistration()` reads
  `MetaAppID` / `AppLinkURLScheme` from `Info.plist.MWDAT`) and on
  Android (`Wearables.startRegistration(activity)` reads the same
  values from `<meta-data>` and the activity's `<intent-filter>`).
  Call sites should drop the arguments. The parameters will be
  removed in v0.2.0.

### Documentation

- Fix the `Info.plist` `AppLinkURLScheme` snippet in
  `doc/getting_started.md` and `.claude/skills/getting-started.md` to
  end with `://`. Meta AI builds the registration callback URL by
  literally concatenating this value with the query string, so
  without the `://` separator the callback becomes a malformed URL
  that iOS silently drops. The example app and `doc/troubleshooting.md`
  were already correct; the getting-started doc was the outdated
  one. Added a dedicated troubleshooting bullet so the symptom
  ("Allow → app reopens but nothing happens") is searchable.
- Document the required iOS `SceneDelegate.swift` wiring for scene-based
  Flutter apps (Flutter ≥ 3.32). Without it, Meta AI's registration
  callback URL is silently dropped on iOS and the SDK never advances
  past `registering`. Added a dedicated section to
  `doc/registration_flow.md`, a setup step to `doc/getting_started.md`,
  a fresh troubleshooting entry, and a quick-reference note in
  `README.md`. Verified against
  [`example/ios/Runner/SceneDelegate.swift`](example/ios/Runner/SceneDelegate.swift).
- README and skill snippets no longer pass the vestigial `appId` /
  `urlScheme` arguments to `startRegistration()`.

### Other

- Add `flutter-plugin` to the pubspec topic list for improved
  discoverability on pub.dev.

## 0.1.0

Initial developer-preview release. Full feature and structural parity with
Meta's official iOS / Android DAT 0.6 SDKs.

### Added

- Unified `MetaWearablesDat` Dart facade for Meta's iOS and Android DAT SDKs.
- `requestAndroidPermissions()` — runtime Bluetooth/Internet grant on Android,
  no-op on iOS.
- Registration flow: `startRegistration`, `handleUrl`, `startUnregistration`,
  `getRegistrationState`, `registrationStateStream`, `activeDeviceStream`.
- `requestCameraPermission()` / `checkCameraPermissionStatus()`.
- **Device enumeration & compatibility:** `devicesStream()`, `getDevices()`,
  `compatibilityStream()`. New `DeviceCompatibility` enum
  (`compatible`, `deviceUpdateRequired`, `sdkUpdateRequired`, `unknown`).
- **Streaming:** `startStreamSession`, `stopStreamSession`,
  `pauseStreamSession`, `resumeStreamSession`, `streamSessionStateStream`,
  `streamSessionErrorStream`, `videoStreamSizeStream`. Frames are delivered
  zero-copy via Flutter's texture registry (CVPixelBuffer on iOS,
  SurfaceTexture on Android). New `deviceKinds` parameter for device-kind
  filtering.
- **Device-session lifecycle:** `deviceSessionStateStream()`,
  `deviceSessionErrorStream()`. New `DeviceSessionState` enum
  (`idle`, `starting`, `started`, `paused`, `stopping`, `stopped`).
- **Per-frame video stream:** `videoFramesStream()` emitting `VideoFrame`
  events with raw BGRA (iOS) / I420 (Android) payloads. Subscriber-gated
  so the per-frame copy is free when no Dart listener is attached.
- **HEVC (`hvc1`) codec:** `videoCodec: VideoCodec` parameter on
  `startStreamSession`. iOS routes compressed `CMSampleBuffer`s through a
  `VTDecompressionPipeline`; Android sets `compressVideo = true`.
- **Background streaming:** `enableBackgroundStreaming` /
  `disableBackgroundStreaming` with `BackgroundNotification` model. iOS
  activates `AVAudioSession` and software HEVC decoding; Android starts a
  foreground service with wake lock.
- `capturePhoto({format})` — mid-stream high-res JPEG / HEIC capture.
- **Typed errors:** `DatError` hierarchy with `RegistrationError`,
  `UnregistrationError`, `HandleUrlError`, `DeviceSessionError`,
  `SessionError`, `CaptureError` — each with `is*` convenience getters so
  callers can switch on errors without string-matching codes.
- **Mock Device Kit:** `enableMockDevice`, `disableMockDevice`,
  `isMockDeviceEnabled`, `pairMockRaybanMeta`, `pairedMockDevices`,
  `mockPowerOn`, `mockPowerOff`, `mockDon`, `mockDoff`, `mockFold`,
  `mockUnfold`, `setMockCameraFeed`, `setMockCapturedImage`,
  `setMockPermission`, `setMockPermissionRequestResult`, `mockDevicesStream`.
- `samples/camera_access/` — polished Flutter clone of Meta's official iOS
  and Android Camera Access samples (settings sheet, photo capture, devices
  screen, video recording).
- Long-form documentation in `doc/` (getting started, registration,
  streaming, frame processing, mock device, troubleshooting).
- AI-assisted development config: `AGENTS.md`, `.claude/skills/`,
  `.cursor/rules/`, `.github/copilot-instructions.md`, `install-skills.sh`.

### Notes

- Audio (microphone capture, speaker playback) is intentionally out of scope
  for `0.1.x` — it is handled via standard Bluetooth Hands-Free Profile, not
  Meta's DAT SDK.
- `SessionState` and `sessionStateStream()` / `sessionErrorStream()` are
  deprecated aliases for `StreamSessionState` and
  `streamSessionStateStream()` / `streamSessionErrorStream()`; they will be
  removed in v0.2.0.
