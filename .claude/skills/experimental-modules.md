---
description: DAT 1.0 experimental capabilities - Inputs, Motion, Speech, voice invocations, high-resolution photo, in-stream audio; @experimental policy, Android mwdat.experimental opt-out, EXPERIMENTAL_NOT_LINKED, and how to add or change an experimental bridge
globs: lib/experimental.dart, lib/src/models/experimental/**, lib/src/models/high_res_photo.dart, ios/**/ExperimentalBridges.swift, android/src/experimental/**, android/src/noexperimental/**, android/**/ExperimentalCapabilities.kt, android/**/VoiceInvocationsBridge.kt
---

# Experimental Modules (Flutter, DAT 1.0)

## Policy

- Every API here is `@experimental` (package:meta) and excluded from the
  plugin's semver. Models are also exported by
  `package:meta_wearables_dat_flutter/experimental.dart`.
- Apps using them can run in Developer Mode and the Beta release channel
  but **cannot ship to production release channels**.
- Inputs and voice invocations need approval for the app in Wearables
  Developer Center.
- iOS always links `MWDATInputs`, `MWDATMotion`, `MWDATSpeech`.
- Android: `mwdat.experimental=false` (app `android/gradle.properties`, or
  `--android-project-arg=mwdat.experimental=false`) drops
  `mwdat-inputs`/`mwdat-motion`/`mwdat-speech` and compiles
  `android/src/noexperimental`. Inputs, Motion and Speech calls (and
  their mock simulators) then throw `DatPluginError` with
  `category == 'EXPERIMENTAL_NOT_LINKED'` (`isExperimentalNotLinked`).
  Voice invocations (Core), high-res photo and audio (Camera) stay
  available.
- Check at runtime: `dumpDiagnostics().experimentalModulesLinked`.

## Inputs

```dart
await MetaWearablesDat.startInputs(
  configuration: const InputsConfiguration(
    sources: {InputSource.captouch, InputSource.neuralBand}, // empty = all
    consumeBack: true,
  ),
);
MetaWearablesDat.inputEventsStream().listen((e) => switch (e) {
  NavInputEvent(:final direction) => move(direction),
  SelectInputEvent() => select(),
  BackInputEvent() => back(),
  CaptureInputEvent(:final pressType) => capture(pressType),
  DragInputEvent(:final dx, :final dy) => drag(dx, dy),
  ButtonInputEvent() || UnknownInputEvent() => null,
});
await MetaWearablesDat.stopInputs();
```

`inputsStateStream()` (`inactive`, `activating`, `active`,
`deactivating`); `inputsErrorStream()` — every `InputsError` ends the
event stream.

## Motion

```dart
await MetaWearablesDat.startMotion(samplingRate: MotionSamplingRate.hz30);
MetaWearablesDat.motionSamplesStream().listen((s) {
  // s.accelerometer, s.gyroscope, s.magnetometer (Vector3?),
  // s.orientation (Quaternion?), s.source, s.timestampNs
});
```

Rates: `hz5`, `hz10` (default), `hz15`, `hz24`, `hz30`, `hz60`. Samples
are produced only while listened to.

## Speech

Requires `Permission.microphone`.

```dart
await MetaWearablesDat.startSpeech();
MetaWearablesDat.transcriptionStream().listen((t) {
  if (t.isFinal) commit(t.text);
});
```

`speechStateStream()`, `speechErrorStream()`.

## Voice invocations ("Hey Meta, open <app>")

```dart
await MetaWearablesDat.startVoiceInvocations();
MetaWearablesDat.voiceInvocationsStream().listen((inv) async {
  final ok = await handle(inv);       // LaunchAppInvocation
  ok ? await inv.respondSuccess() : await inv.respondFailure();
});
```

Answer each invocation exactly once (second answer throws
`StateError`); `stopVoiceInvocations()` fails unanswered ones.

## High-resolution photo and in-stream audio

```dart
final hq = await MetaWearablesDat.captureHighResPhoto(
  resolution: PhotoResolution.full,   // small | medium | large | full
  quality: PhotoQuality.high,
);
MetaWearablesDat.photoTransferProgressStream().listen(showProgress);

final id = await MetaWearablesDat.startStreamSession(
  config: const StreamSessionConfig(audio: AudioStreamConfig()),
);
MetaWearablesDat.audioFramesStream().listen((a) => pcm.add(a.bytes));
```

Errors: `PhotoError`, `StreamError` (`audioStreamingError`).

## Mock simulators

`mockInputNav/Select/Back/Capture/Button/Drag`, `setMockSpeechSource`,
`simulateMockTranscription`, `simulateMockSpeechError`,
`simulateMockSpeechCompletion`, `setMockMotionFeed`,
`simulateMockVoiceInvocation`, `setMockCapturedPhoto`,
`simulateMockCaptureFailure`. See
[mockdevice-testing.md](mockdevice-testing.md).

## Changing an experimental bridge (plugin code)

1. Dart: facade method + `@experimental` + dartdoc noting the release
   channel restriction; model in `lib/src/models/experimental/`; export
   from `lib/experimental.dart`.
2. Channels: add names to `DatChannels` and register in Swift and Kotlin
   in the same change; run `dart run tool/check_channel_parity.dart`.
3. iOS: `ExperimentalBridges.swift`; acquire/release the shared session
   via `DeviceSessionHub`.
4. Android: interface in `ExperimentalCapabilities.kt`, real impl in
   `src/experimental/.../ExperimentalCapabilitiesImpl.kt`, stub throwing
   `EXPERIMENTAL_NOT_LINKED` in `src/noexperimental/...`. Both must
   compile (CI builds with `mwdat.experimental=false`).
5. Capability `StateFlow`s start at `STOPPED`; do not treat it as terminal.

## Links

- [`doc/experimental.md`](../../doc/experimental.md)
