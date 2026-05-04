# Changelog

All notable changes to this project will be documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

Initial developer-preview release.

### Added

- Unified `MetaWearablesDat` Dart facade for Meta's iOS and Android DAT SDKs.
- `requestAndroidPermissions()` — runtime Bluetooth/Internet grant on Android,
  no-op on iOS.
- Registration flow: `startRegistration`, `handleUrl`, `startUnregistration`,
  `getRegistrationState`, plus `registrationStateStream` and
  `activeDeviceStream`.
- `requestCameraPermission()` — opens Meta AI's permission bottom sheet.
- Streaming: `startStreamSession`, `stopStreamSession`, `pauseStreamSession`,
  `resumeStreamSession`, `sessionStateStream`, `sessionErrorStream`,
  `videoStreamSizeStream`. Frames are delivered zero-copy via Flutter's
  texture registry (CVPixelBuffer on iOS, SurfaceTexture on Android).
- `captureStreamFrame()` — pure-Dart on-demand RGBA snapshot.
- `capturePhoto()` — mid-stream high-res JPEG / HEIC capture.
- Mock Device Kit pass-through for hardware-less development
  (`enableMockDevice`, `pairMockRayBanMeta`, `mockPowerOn`, `mockDon`,
  `setMockCameraFacing`, `setMockCameraFeed`, `setMockCapturedImage`,
  `unpairMockDevice`, `disableMockDevice`).
- `samples/camera_access/` — polished Flutter clone of Meta's official iOS and
  Android Camera Access samples.
- Long-form documentation in `doc/` (getting started, registration, streaming,
  frame processing, mock device, troubleshooting).

### Notes

- Audio (microphone capture, speaker playback) is intentionally out of scope
  for `0.1.x` — it is handled via standard Bluetooth Hands-Free Profile, not
  Meta's DAT SDK, and will arrive in `0.2`.
- HEVC (`hvc1`) codec, background streaming, and a dedicated
  `videoFramesStream()` API are planned for `0.2`.
