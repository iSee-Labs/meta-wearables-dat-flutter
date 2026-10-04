---
description: App registration with Meta AI (app- and Meta-AI-initiated), deep-link callbacks, camera and microphone permissions, and Meta AI update navigation (DAT 1.0)
globs: lib/**/*.dart, ios/**/RegistrationBridge.swift, android/**/RegistrationBridge.kt, **/AppDelegate.swift, **/MainActivity.kt
---

# Permissions & Registration (Flutter, DAT 1.0)

1. **Registration** — the app registers with the Meta AI app.
2. **Wearable permissions** — then requests `Permission.camera` /
   `Permission.microphone`, granted inside Meta AI.

## App-initiated registration

```dart
await MetaWearablesDat.startRegistration();
```

No parameters (the 0.x `appId`/`urlScheme` args were removed). Values
come from `Info.plist` `MWDAT` (iOS) and manifest meta-data
`com.meta.wearable.mwdat.APPLICATION_ID` / `CLIENT_TOKEN` (Android).

Throws `RegistrationError`; switch on `reason`
(`RegistrationErrorCase.configurationInvalid`, `metaAINotInstalled`,
`alreadyRegistered`, `networkUnavailable`, `timeout`, ...).

Callback URLs are handled by the plugin (iOS application delegate,
Android `onNewIntent`). Call `handleUrl(url)` only for URLs your app receives
another way; it returns whether the SDK consumed it and throws
`HandleUrlError`.

## Meta AI-initiated registration

```dart
MetaWearablesDat.registrationRequestStream().listen((req) async {
  if (await userAccepts()) {
    await req.continueRegistration();
  } else {
    await req.cancel();
  }
});
```

Answer each `RegistrationRequest` exactly once (second answer throws
`StateError`); unanswered requests expire after 5 minutes. Failures throw
`RegistrationRequestError`.

## State

```dart
final now = await MetaWearablesDat.getRegistrationState();
MetaWearablesDat.registrationStateStream().listen((s) {
  // unavailable | available | registering | registered | unregistering
});
MetaWearablesDat.registrationErrorStream().listen((e) { /* DatError */ });
```

Unregister: `startUnregistration()` (`UnregistrationError`).

## Permissions

```dart
final status = await MetaWearablesDat.checkPermissionStatus(Permission.camera);
if (status != PermissionStatus.granted) {
  await MetaWearablesDat.requestPermission(Permission.camera);
}
```

- `PermissionStatus`: `granted`, `denied`.
- `Permission.microphone` is needed for Speech and in-stream audio.
- `PermissionError` reasons include `noDevice`, `requestInProgress`,
  `requestTimeout`, `metaAINotInstalled`, `missingFragmentActivity`
  (Android `MainActivity` must be a `FlutterFragmentActivity`).
- `requestCameraPermission()` / `getCameraPermissionStatus()` are
  deprecated shims.
- A grant on any linked device counts; if all devices disconnect,
  permissions are unavailable.

## Android runtime permissions

`requestAndroidPermissions()` requests `BLUETOOTH_CONNECT` and
initialises the DAT SDK on Android; returns `true` on iOS. Call it before
registration.

## Update navigation

`openFirmwareUpdate()` and `openDatGlassesAppUpdate()` open Meta AI;
failures throw `NavigationError`. Trigger them from
`DatError.recoveryAction`.

## Developer Mode vs Beta/production

| Mode | Setup |
|---|---|
| Developer Mode | Meta AI → Settings → App Info → tap version 5 times; app id/token may be omitted |
| Beta release channel | App id + client token from Wearables Developer Center; create a new app version for 1.0 builds |

## Links

- [`doc/registration_flow.md`](../../doc/registration_flow.md)
- Meta docs: <https://wearables.developer.meta.com/docs/develop/>
