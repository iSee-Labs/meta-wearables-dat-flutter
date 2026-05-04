# Project: meta-wearables-dat-flutter

## Identity
- GitHub org: iSee-Labs
- Repo: https://github.com/iSee-Labs/meta-wearables-dat-flutter
- Package name (pub.dev): meta_wearables_dat_flutter
- License: MIT
- Copyright holder: iSee Labs
- Maintainer: Talha Ordukaya

## What this project is
An unofficial Flutter plugin that bridges Meta's official iOS and Android 
Wearables Device Access Toolkit (DAT) SDKs. Provides a unified Dart API for 
Flutter apps integrating with Meta AI Glasses (Ray-Ban Meta, Oakley Meta, 
Ray-Ban Display).

## What this project is NOT
- NOT a reimplementation of Meta's SDK. Meta's SDKs are closed-source binaries.
- NOT affiliated with, endorsed by, or sponsored by Meta Platforms, Inc. The 
  README must include an unofficial disclaimer at the very top, BEFORE the title.
  "Meta", "Ray-Ban Meta", "Oakley Meta" are trademarks of their respective owners.
- NOT for publishing to public app stores yet — Meta DAT is in developer preview.

## Architecture (non-negotiable)
- Dart layer: public API, type-safe models, streams. No platform code.
- iOS bridge (Swift): MethodChannel/EventChannel handlers calling Meta's Swift SDK.
- Android bridge (Kotlin): MethodChannel/EventChannel handlers calling Meta's 
  Kotlin SDK.
- Video frames go through Flutter texture registry (CVPixelBuffer on iOS, 
  SurfaceTexture on Android). NEVER serialize frames over MethodChannel.
- We do NOT copy code from rodcone's plugin. Reference its design decisions 
  (especially the texture bridge and captureStreamFrame pattern), but write 
  our own implementation.

## Reference implementations available in workspace
- ../meta-glasses-research/meta-wearables-dat-ios/samples/CameraAccess — 
  official iOS sample
- ../meta-glasses-research/meta-wearables-dat-android/samples/CameraAccess — 
  official Android sample
- ../meta-glasses-research/flutter_meta_wearables_dat — existing community 
  Flutter plugin. Reference for architecture decisions, but we're building 
  our own; do not copy code wholesale.

## Coding conventions
- Dart: very_good_analysis lint rules, dartdoc on all public APIs
- Swift: follow Meta's iOS sample style
- Kotlin: follow Meta's Android sample style
- All public Dart APIs return Future<T> or Stream<T>, never callbacks

## Critical native-side requirements (don't forget these)
- iOS Info.plist needs UISupportedExternalAccessoryProtocols with 
  com.meta.ar.wearable
- iOS needs UIBackgroundModes: bluetooth-peripheral + external-accessory
- Android requires FlutterFragmentActivity (not FlutterActivity) — document this
- Android Maven auth needs GITHUB_TOKEN env var with read:packages scope

## Performance constraints (non-negotiable)
- Video frames NEVER serialize over MethodChannel. Use Flutter's texture 
  registry (FlutterTexture on iOS, SurfaceTexture + TextureRegistry on Android).
- captureStreamFrame() returns raw RGBA bytes on demand, NOT every frame. 
  Document the ~3.7MB-per-frame cost at 720x1280. Recommend 200-500ms sampling.
- All event streams must be backpressure-safe. If Dart stops listening, 
  native side stops emitting.
- Texture lifecycle: stopStreamSession() must unregister the texture, otherwise 
  GPU memory leaks.

## API surface to implement (in order of priority)
1. requestAndroidPermissions() — Android only, no-op iOS
2. startRegistration(appId, urlScheme) + handleUrl(url)
3. registrationStateStream(), activeDeviceStream()
4. requestCameraPermission()
5. startStreamSession(deviceUUID, fps, quality) → textureId
6. stopStreamSession(deviceUUID)
7. captureStreamFrame(textureId, format) → FrameData
8. capturePhoto(deviceUUID) → PhotoResult
9. enableMockDevice() — for development without hardware
10. DEFERRED TO v0.2 — microphone capture and speaker playback. Audio uses 
    standard Bluetooth Hands-Free Profile (not Meta's DAT SDK), so it's a 
    separate concern. Do NOT implement audio in v0.1 even if asked.

## Required README structure
1. Unofficial disclaimer block (italicized, before the title)
2. Title and one-line tagline
3. Badges (pub.dev version, license, Flutter compatibility)
4. Compatible devices list
5. Setup section: iOS config, Android config, Meta Wearables Developer Center
6. Integration lifecycle: permissions → registration → session
7. API reference summary (link to dartdoc)
8. Troubleshooting
9. Contributing, License, Acknowledgments (credit Meta's official SDKs)

## How we work
- Build in vertical slices: one feature working end-to-end (Dart → iOS → 
  Android → example app) before starting the next.
- After every slice: run `flutter analyze` (must pass with zero warnings) and 
  `cd example && flutter run` on both iOS and Android.
- Commit after each completed slice with a clear conventional-commit message 
  (e.g. `feat: add registration flow`).
- Use Plan mode for slices 5-7 (the registration flow and texture bridge are 
  the hardest — plan before coding).
- When uncertain, STOP and ask. Do not guess at Meta SDK behavior — read the 
  reference samples first.

## What "done" looks like for v0.1.0
- API methods 1-9 implemented and verified on real hardware OR Mock Device Kit
- samples/camera_access/ Flutter app working on both iOS and Android
- README with unofficial disclaimer at top, full setup instructions, troubleshooting
- LICENSE (MIT), NOTICE attributing Meta's SDKs, CHANGELOG.md starting at 0.1.0
- CONTRIBUTING.md and CODE_OF_CONDUCT.md (Contributor Covenant)
- analysis_options.yaml using very_good_analysis
- pubspec.yaml with metadata pointing to iSee-Labs/meta-wearables-dat-flutter
- `dart pub publish --dry-run` passes with no warnings
- Tagged release v0.1.0 on GitHub matching pub.dev version