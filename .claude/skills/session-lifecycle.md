---
description: DeviceSession vs StreamSession lifecycle, pause/resume, and how to observe them from Dart
globs: lib/**/*.dart, ios/**/MetaSessionManager.swift, android/**/MetaSessionManager.kt
---

# Session Lifecycle (Flutter)

The DAT SDK exposes **two** session levels and `meta_wearables_dat_flutter`
surfaces both. Get this mental model right or you'll fight the SDK.

## The two sessions

| Layer | Lifecycle | Owner | What it represents |
|-------|-----------|-------|--------------------|
| `DeviceSession` | starts when you ask for a device, lives across multiple capabilities | the plugin, on your behalf | sustained access to a paired device |
| `StreamSession` | child capability attached to a `DeviceSession` | the plugin | one specific video stream |

On both platforms, the plugin starts the `DeviceSession` first, waits
until it reports `started`, and only then adds a stream. On stop, the
stream is stopped first, then the device session.

## DeviceSession state

```dart
MetaWearablesDat.deviceSessionStateStream().listen((state) {
  // idle | starting | started | paused | stopping | stopped
});
MetaWearablesDat.deviceSessionErrorStream().listen((err) {
  if (err.isNoEligibleDevice) { /* show "Connect glasses" */ }
});
```

## StreamSession state

```dart
MetaWearablesDat.streamSessionStateStream().listen((state) {
  // stopped | waitingForDevice | starting | streaming | paused | stopping
});
```

State flow:

```
stopped → waitingForDevice → starting → streaming → paused → stopped
```

## Common pause/resume causes

The device decides when to transition. Causes include:

- User triggers a system gesture or "Hey Meta" wake word.
- Another app starts a device session.
- User removes/folds the glasses (Bluetooth disconnects → `stopped`).
- User revokes permission in the Meta AI companion app.
- Phone-to-glasses connectivity drops.

When paused, the device keeps the connection alive but stops delivering
frames. Do **not** restart while paused — wait for `streaming` or
`stopped`.

## Restart safety

`stopStreamSession()` is idempotent. After it returns, you may
immediately call `startStreamSession()` again. The plugin guarantees
the underlying `DeviceSession` is stopped before re-starting.

## Implementation checklist

- [ ] Subscribe to both `deviceSessionStateStream` and
      `streamSessionStateStream`.
- [ ] Release resources only after observing `stopped`.
- [ ] Don't infer transition causes — rely on observable state.
- [ ] Don't restart during `paused`.
- [ ] Always call `stopStreamSession()` on dispose, including in tests.

## Links

- [`doc/streaming.md`](../../doc/streaming.md)
- Meta session lifecycle docs:
  <https://wearables.developer.meta.com/docs/lifecycle-events>
