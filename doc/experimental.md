# Experimental APIs

DAT 1.0 ships several capabilities that Meta marks as experimental. The
plugin exposes them with Dart's `@experimental` annotation.

> **Apps that use any experimental API cannot ship to production release
> channels.** Use them in Developer Mode and in the Beta release channel
> of the Wearables Developer Center only.

## What is experimental

| Capability | API | Native module |
| --- | --- | --- |
| [Inputs](#inputs) | `startInputs`, `stopInputs`, `inputEventsStream`, `inputsStateStream`, `inputsErrorStream` | `MWDATInputs` / `mwdat-inputs` |
| [Motion](#motion) | `startMotion`, `stopMotion`, `motionSamplesStream`, `motionStateStream`, `motionErrorStream` | `MWDATMotion` / `mwdat-motion` |
| [Speech](#speech) | `startSpeech`, `stopSpeech`, `transcriptionStream`, `speechStateStream`, `speechErrorStream` | `MWDATSpeech` / `mwdat-speech` |
| [Voice invocations](#voice-invocations) | `startVoiceInvocations`, `stopVoiceInvocations`, `voiceInvocationsStream`, `voiceInvocationsStateStream`, `voiceInvocationErrorStream` | Core |
| [High-resolution photos](#high-resolution-photos) | `captureHighResPhoto`, `photoTransferProgressStream`, `photoStateStream`, `photoErrorStream` | Camera |
| [In-stream audio](#in-stream-audio) | `StreamSessionConfig.audio`, `audioFramesStream` | Camera |
| Mock simulators | `mockInput*`, `setMockSpeechSource`, `simulateMockTranscription`, `simulateMockSpeechError`, `simulateMockSpeechCompletion`, `setMockMotionFeed`, `simulateMockVoiceInvocation`, `setMockCapturedPhoto`, `simulateMockCaptureFailure` | MockDevice |

Everything is exported from
`package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart`.
The models are also exported from
`package:meta_wearables_dat_flutter/experimental.dart`; importing it as
well makes experimental usage easy to find in your codebase.

Using an `@experimental` member triggers the analyzer's
`experimental_member_use` diagnostic. Silence it deliberately, per file
or per line, so every use stays visible:

```dart
// ignore_for_file: experimental_member_use
```

## Versioning

`@experimental` APIs are **excluded from semantic versioning**. They can
change or disappear in a minor or patch release when Meta changes them.
Everything else follows semver: the plugin's major.minor tracks Meta's
DAT version, the patch number is the plugin's own.

## Approval in Wearables Developer Center

- **Inputs** must be approved for your app in the Wearables Developer
  Center. Without approval, `inputsErrorStream()` reports
  `InputsErrorCase.permissionDenied`.
- **Voice invocations** need the Voice Invocation permission approved in
  the Wearables Developer Center.
- **Speech** needs `Permission.microphone` (see
  [Registration](registration_flow.md#permissions)) and
  `NSMicrophoneUsageDescription` on iOS.

## Inputs

Touchpad (captouch), capture button, action button and Meta Neural Band
input.

```dart
await MetaWearablesDat.startInputs(
  configuration: const InputsConfiguration(
    sources: {InputSource.captouch, InputSource.neuralBand},
    consumeBack: true, // deliver Back to the app instead of the system
  ),
);

MetaWearablesDat.inputEventsStream().listen((event) {
  switch (event) {
    case NavInputEvent(:final direction):
      moveFocus(direction);
    case SelectInputEvent():
      activate();
    case BackInputEvent():
      goBack();
    case CaptureInputEvent(:final pressType):
      onCapture(pressType);
    case ButtonInputEvent():
      onActionButton();
    case DragInputEvent(:final dx, :final dy):
      pan(dx, dy);
    case UnknownInputEvent():
      break;
  }
});

await MetaWearablesDat.stopInputs();
```

- An empty `sources` set means all sources.
- States: `InputsState.inactive`, `activating`, `active`, `deactivating`.
- Every `InputsError` ends the event stream (`permissionDenied`,
  `connectionClosed`, `activationTimeout`, `activationFailed`,
  `capabilityUnavailable` on iOS, `deviceDisconnected`,
  `communicationError`).
- `BackInputEvent` is not yet delivered by real glasses.

## Motion

Head motion samples from the glasses (or the Neural Band).

```dart
final samples = MetaWearablesDat.motionSamplesStream().listen((sample) {
  // sample.timestampNs, accelerometer, gyroscope, magnetometer (Vector3?),
  // orientation (Quaternion?), source (glasses / neuralBand)
});
await MetaWearablesDat.startMotion(samplingRate: MotionSamplingRate.hz30);
// ...
await MetaWearablesDat.stopMotion();
await samples.cancel();
```

- Rates: `hz5`, `hz10` (default), `hz15`, `hz24`, `hz30`, `hz60`.
- Samples are produced only while `motionSamplesStream()` is listened to.
- States: `stopped`, `starting`, `started`, `stopping`, `paused`
  (Android: while the device session is paused; resumes automatically).
- Errors: `MotionErrorCase.sensorUnavailable`, `capabilityClosed`,
  `deviceDisconnected`.

## Speech

On-device transcription from the glasses microphone.

```dart
final mic = await MetaWearablesDat.requestPermission(Permission.microphone);
if (mic.isGranted) {
  MetaWearablesDat.transcriptionStream().listen((result) {
    // result.text, result.isFinal, result.confidence (nullable)
  });
  await MetaWearablesDat.startSpeech();
}
// ...
await MetaWearablesDat.stopSpeech();
```

- States: `starting`, `started`, `stopping`, `stopped`.
- Errors: `SpeechErrorCase.deviceDisconnected`, `invalidState`,
  `unavailable`, `alreadyListening`, `startFailed`, `unexpectedError`.

## Voice invocations

"Hey Meta, open <your app>" requests directed at your app.

```dart
await MetaWearablesDat.startVoiceInvocations();
MetaWearablesDat.voiceInvocationsStream().listen((invocation) async {
  switch (invocation) {
    case LaunchAppInvocation():
      final ok = await openMainFeature();
      if (ok) {
        await invocation.respondSuccess();
      } else {
        await invocation.respondFailure(actionOutput: 'Could not start');
      }
  }
});
// ...
await MetaWearablesDat.stopVoiceInvocations();
```

- Answer every invocation **exactly once** with `respondSuccess` or
  `respondFailure`. A second answer throws a `StateError`;
  `isResponded` tells you whether it was answered. Unanswered
  invocations are failed when the stream stops.
- States: `starting`, `started`, `stopped`.
- `VoiceInvocationErrorCase` covers channel and protocol failures, for
  example `channelNotConnected` and `alreadyResponded`.

## High-resolution photos

Captures up to 4032 x 3024 while a stream runs.

```dart
final progress = MetaWearablesDat.photoTransferProgressStream().listen((p) {
  // p.bytesReceived, p.totalBytes, p.fraction
});
try {
  final photo = await MetaWearablesDat.captureHighResPhoto(
    resolution: PhotoResolution.full,
    quality: PhotoQuality.high,
  );
  // photo.bytes, photo.metadata, photo.timestamp
} on PhotoError catch (e) {
  // notReady, busy, permissionDenied, deviceHealthCritical, timeout, ...
} finally {
  await progress.cancel();
}
```

- `PhotoResolution`: `small`, `medium` (default), `large`, `full`.
- `PhotoQuality`: `low`, `medium` (default), `high`.
- `photoStateStream()`: `stopped`, `starting`, `started`, `stopping`.

## In-stream audio

PCM audio from the glasses microphone alongside the video. See
[Frame processing](frame_processing.md#audioframesstream-experimental).

```dart
final textureId = await MetaWearablesDat.startStreamSession(
  config: const StreamSessionConfig(
    audio: AudioStreamConfig(sampleRate: AudioSampleRate.hz48000, channels: 1),
  ),
);
MetaWearablesDat.audioFramesStream().listen((frame) {
  // frame.bytes, frame.ptsUs, frame.sampleRate, frame.channels
});
```

## Android: opting out of the experimental modules

On Android the experimental modules (`mwdat-inputs`, `mwdat-motion`,
`mwdat-speech`) are linked by default so every API works out of the box.
To drop them from your APK, add this to your app's
`android/gradle.properties`:

```properties
mwdat.experimental=false
```

The plugin then compiles stubs: Inputs, Motion and Speech calls throw a
`DatPluginError` with category `EXPERIMENTAL_NOT_LINKED`
(`isExperimentalNotLinked == true`). Check at runtime with diagnostics:

```dart
final diagnostics = await MetaWearablesDat.dumpDiagnostics();
final hasInputs = diagnostics.experimentalModulesLinked['inputs'] ?? false;
```

Voice invocations, high-resolution photos and in-stream audio are part
of the core and camera modules and stay available. On iOS all modules
are always linked; there is no opt-out.

Opting out removes the binaries, but it does not by itself make your
app eligible for production release channels: also remove every call
to an experimental API.

## Testing

Every experimental capability has a Mock Device Kit simulator. See
[Mock Device Kit: input, speech, motion and voice simulators](mock_device.md#input-speech-motion-and-voice-simulators)
and the last test in
[`example/integration_test/plugin_test.dart`](../example/integration_test/plugin_test.dart).
