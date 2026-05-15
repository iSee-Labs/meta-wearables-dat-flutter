# Changelog

All notable changes to this project will be documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
