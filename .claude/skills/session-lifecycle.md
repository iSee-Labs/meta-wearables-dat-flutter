---
description: Shared DeviceSession (DeviceSessionHub) vs capabilities (camera, display, experimental), state streams, device-driven pauses, terminal errors, and teardown (DAT 1.0)
globs: lib/**/*.dart, ios/**/DeviceSessionHub.swift, ios/**/MetaSessionManager.swift, android/**/DeviceSessionHub.kt, android/**/MetaSessionManager.kt
---

# Session Lifecycle (Flutter, DAT 1.0)

## Model

| Layer | Owner | Represents |
|---|---|---|
| `DeviceSession` | `DeviceSessionHub` (one per device, shared) | sustained access to a paired device |
| Capabilities | camera, display, inputs, motion, speech, voice | features attached to that session |

Each capability `acquire`s the hub under an owner name on start and
`release`s on stop. The session is stopped when the last owner releases.
Starting display while streaming reuses the same session. A terminal
STOPPED (hinges closed, device gone) notifies every owner so each frees
its resources.

## Device session state

```dart
MetaWearablesDat.deviceSessionStateStream().listen((s) {
  // idle | starting | started | paused | stopping | stopped
});
MetaWearablesDat.deviceSessionErrorStream().listen((e) {
  if (e.isTerminal) showUpdateRequired();          // insufficientSDKVersion
  else if (e.isWarning) logOnly(e);                 // dwaOutOfStuRange
  else if (e.reason == DeviceSessionErrorCase.noEligibleDevice) askToConnect();
});
```

Other notable reasons: `deviceDisconnected`, `sessionEndedByDevice`,
`thermalCritical`, `batteryCritical`, `datAppOnTheGlassesUpdateRequired`
(`recoveryAction == openDatGlassesAppUpdate`), `startTimeout`.

## Camera state

```dart
MetaWearablesDat.streamSessionStateStream().listen((s) {
  // stopped | waitingForDevice | starting | streaming | paused | stopping
});
MetaWearablesDat.cameraStateStream().listen((s) {
  // starting | started | stopping | stopped
});
```

There is no pause/resume API (removed in 1.0; it never did anything).
The device pauses on its own: captouch tap, glasses taken off, system
gesture, "Hey Meta", another app taking the session. Wait for
`streaming` or `stopped`; do not restart while `paused`.

iOS: the stream ends on `didEnterBackground` unless
`enableBackgroundStreaming()` was called.

## Restart safety

`stopStreamSession()` and `stopDisplaySession()` are idempotent. After
`stopStreamSession()` returns you may call `startStreamSession()` again.
After all capabilities stop, `dumpDiagnostics().isIdle` is true.

## Implementation rules (plugin code)

- Android `StateFlow`s start at `STOPPED` before the device answers.
  Only a STOPPED reached after leaving STOPPED is terminal.
- Public Dart streams must not use `async*` with awaited teardown
  (`first`/`firstWhere` await cancel and hang).
- State channels replay their last value to new listeners.

## Checklist

- [ ] Subscribe to `deviceSessionStateStream` and the capability's state
      stream.
- [ ] Handle `deviceSessionErrorStream` with `isTerminal` / `isWarning`
      / `recoveryAction`.
- [ ] Don't infer causes; rely on observable state.
- [ ] Always stop capabilities in `dispose`, including in tests.

## Links

- [`doc/streaming.md`](../../doc/streaming.md)
- [device-state.md](device-state.md)
- Meta docs: <https://wearables.developer.meta.com/docs/develop/>
