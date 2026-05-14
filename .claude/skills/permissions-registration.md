---
description: App registration with Meta AI, deep-link callbacks, and camera permission flows
globs: lib/**/*.dart, **/AppDelegate.swift, **/SceneDelegate.swift, **/MainActivity.kt
---

# Permissions & Registration (Flutter)

The DAT SDK separates two concepts:

1. **Registration** — your app registers with the Meta AI app to
   become an approved integration.
2. **Device permissions** — once registered, request specific device
   permissions (e.g. camera).

All permission grants happen inside the Meta AI companion app via deep
link.

## Registration flow

```
Your app                       Meta AI app
   │                                │
   │ startRegistration()            │
   │ ───────────────────────────▶   │
   │                                │ user taps "Allow"
   │ deep-link callback             │
   │ ◀───────────────────────────   │
   │ handleUrl(url)                 │
   │                                │
   │ registrationStateStream emits  │
   │ RegistrationState.registered   │
```

### Start

```dart
await MetaWearablesDat.startRegistration();
```

`appId` and `urlScheme` are accepted as optional parameters but
ignored — both platforms read the active values from the host app's
`Info.plist` (`MWDAT` dict) and `AndroidManifest.xml` `<meta-data>`
entries. The parameters will be removed in v0.2.0.

Throws `RegistrationError` if misconfigured:

- `isConfigurationInvalid` — `Info.plist` `MWDAT` keys missing/bad
  scheme (no underscores).
- `isMetaAiNotInstalled` — install or update the Meta AI app.
- `isAlreadyRegistered` — call `startUnregistration()` first.

### Handle the deep-link callback

The plugin's `iOS SceneDelegate` and Android `MainActivity` already
forward URLs to native code. From Dart you only need to do this if
you handle deep links yourself:

```dart
await MetaWearablesDat.handleUrl(uri.toString());
```

### Observe state

```dart
MetaWearablesDat.registrationStateStream().listen((state) {
  // unregistered | registering | registered
});
```

### Unregister

```dart
await MetaWearablesDat.startUnregistration();
```

## Camera permissions

```dart
final status = await MetaWearablesDat.checkCameraPermissionStatus();
// notDetermined | granted | denied | restricted

await MetaWearablesDat.requestCameraPermission();
// opens Meta AI for the user to grant; resolves with the new status
```

Users can choose:

- **Allow once** — temporary, single-session grant.
- **Allow always** — persistent grant.

## Multi-device behavior

- Users can link multiple glasses to Meta AI.
- A permission granted on **any** linked device counts as granted for
  your app.
- If all devices disconnect, permissions become unavailable.

## Developer Mode vs Production

| Mode | Registration |
|------|---------------|
| Developer Mode | `MetaAppID = "0"` + Developer Mode toggle in Meta AI app |
| Production | Request an AppID from the [Wearables Developer Center](https://wearables.developer.meta.com/) |

## Prerequisites

- Internet connection (registration calls Meta's servers).
- Meta AI companion app installed.
- Developer Mode toggle ON in Meta AI app for unverified apps.

## Links

- [`doc/registration_flow.md`](../../doc/registration_flow.md)
- Meta permissions docs:
  <https://wearables.developer.meta.com/docs/permissions-requests>
