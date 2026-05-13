# meta_wearables_dat_flutter — Copilot Instructions

> Full Meta DAT API reference: <https://wearables.developer.meta.com/llms.txt?full=true>
>
> Plugin AGENTS guide (canonical): [`../AGENTS.md`](../AGENTS.md)
>
> Per-topic Claude skills: [`../.claude/skills/`](../.claude/skills/)
>
> Cursor rule: [`../.cursor/rules/meta-wearables-dat.mdc`](../.cursor/rules/meta-wearables-dat.mdc)

This repository is `meta_wearables_dat_flutter` — an unofficial Flutter
plugin bridging Meta's official iOS and Android Wearables Device
Access Toolkit (DAT) SDKs. Read [`AGENTS.md`](../AGENTS.md) for the
canonical context.

## Architecture in 30 seconds

- **Dart facade** (`lib/meta_wearables_dat_flutter.dart`) — public
  `Future<T>` / `Stream<T>` API, typed errors, models.
- **iOS bridge** (`ios/.../*.swift`) — `MWDATCore` / `MWDATCamera` /
  `MWDATMockDevice` thin wrapper.
- **Android bridge** (`android/.../*.kt`) — equivalent Kotlin wrapper.
- One `MethodChannel` plus the channels listed in
  [`AGENTS.md`](../AGENTS.md#architecture).

## Naming map

| Meta type | Dart equivalent |
|-----------|-----------------|
| `Wearables.shared` | `MetaWearablesDat` |
| `RegistrationState` | `RegistrationState` enum |
| `DeviceSessionState` | `DeviceSessionState` enum |
| `StreamSessionState` | `StreamSessionState` enum |
| `StreamSessionConfig` | named args on `startStreamSession()` |
| `AutoDeviceSelector` | default selector |
| `SpecificDeviceSelector` | `deviceUUID:` arg |
| `MockDeviceKit` | `enableMockDevice() / *Mock*()` methods |

## Conventions

- Dart: `very_good_analysis`; all public APIs `Future<T>` or
  `Stream<T>`; dartdoc on every public symbol.
- Swift: `async`/`await`, `AnyListenerToken.cancel()`, `@MainActor`
  for channel/UI code.
- Kotlin: `Flow`/`StateFlow` + `collectLatest`, dedicated
  `CoroutineScope` per stream.
- Performance: texture path never serializes frames over
  `MethodChannel`; `videoFramesStream` gates emission on subscriber
  count; `stopStreamSession()` unregisters the texture.

## Per-topic deep dives

| Topic | File |
|-------|------|
| Getting started | [`../.claude/skills/getting-started.md`](../.claude/skills/getting-started.md) |
| Camera streaming | [`../.claude/skills/camera-streaming.md`](../.claude/skills/camera-streaming.md) |
| Mock device | [`../.claude/skills/mockdevice-testing.md`](../.claude/skills/mockdevice-testing.md) |
| Session lifecycle | [`../.claude/skills/session-lifecycle.md`](../.claude/skills/session-lifecycle.md) |
| Permissions & registration | [`../.claude/skills/permissions-registration.md`](../.claude/skills/permissions-registration.md) |
| Debugging | [`../.claude/skills/debugging.md`](../.claude/skills/debugging.md) |
| Sample app | [`../.claude/skills/sample-app-guide.md`](../.claude/skills/sample-app-guide.md) |
| Conventions | [`../.claude/skills/dat-conventions.md`](../.claude/skills/dat-conventions.md) |
