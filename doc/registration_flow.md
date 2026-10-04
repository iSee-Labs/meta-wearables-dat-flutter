# Registration and permissions

Registration links your app to the user's Meta account and glasses
through the Meta AI app. DAT 1.0 supports two flows:

- **App-initiated:** your app calls `startRegistration()`, Meta AI
  opens, the user approves, and Meta AI calls back into your app.
- **Meta-AI-initiated (new in 1.0):** the user starts the connection
  from the Meta AI app. Your app receives a `RegistrationRequest` and
  decides whether to continue.

Complete the platform setup in [Getting started](getting_started.md)
first: the callback scheme, the iOS scene delegate forwarding and the
Android intent filter.

## Registration states

`registrationStateStream()` emits the current state first, then every
change. `getRegistrationState()` returns a one-off snapshot.

| `RegistrationState` | Meaning |
| --- | --- |
| `unavailable` | Registration is not possible: the SDK is not initialised (Android: `BLUETOOTH_CONNECT` not granted yet) or Meta AI is missing |
| `available` | The app can register |
| `registering` | The flow is in progress (Meta AI is open, or the callback is being processed) |
| `registered` | The app is registered; device, permission and session APIs work |
| `unregistering` | Android: unregistration is in progress |

## App-initiated registration

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

Future<void> connectGlasses() async {
  // Android: requests BLUETOOTH_CONNECT and initialises the SDK.
  // iOS: returns true immediately.
  if (!await MetaWearablesDat.requestAndroidPermissions()) return;

  MetaWearablesDat.registrationStateStream().listen((state) {
    debugPrint('registration: ${state.name}');
  });

  // Failures that happen after Meta AI opened arrive here.
  MetaWearablesDat.registrationErrorStream().listen((error) {
    debugPrint('registration failed: $error');
  });

  try {
    await MetaWearablesDat.startRegistration();
  } on RegistrationError catch (e) {
    switch (e.reason) {
      case RegistrationErrorCase.metaAINotInstalled:
        // Ask the user to install the Meta AI app.
        break;
      case RegistrationErrorCase.configurationInvalid:
        // Run dumpDiagnostics() and fix the reported findings.
        break;
      case RegistrationErrorCase.alreadyRegistered:
        break;
      default:
        debugPrint('startRegistration: $e');
    }
  }
}
```

Timeline:

1. `startRegistration()` opens the Meta AI app.
2. The user approves (Developer Mode shows an "unverified app" prompt).
3. Meta AI opens `<your scheme>://?...` in your app.
4. The plugin hands the URL to the SDK: on iOS through the application
   delegate or the `MetaWearablesDatHandleURL` notification posted by
   your scene delegate; on Android through the launch intent and
   `onNewIntent`.
5. `registrationStateStream()` emits `registered`.
6. `devicesStream()` and `activeDeviceStream()` start reporting glasses.

### `handleUrl`

You normally do not call `handleUrl`. Use it only when your app
receives the Meta AI callback URL through another path (for example
your own deep-link router consumed it first):

```dart
final consumed = await MetaWearablesDat.handleUrl(url.toString());
```

It returns whether the SDK consumed the URL and throws a
`HandleUrlError` (`invalidUrl`, `registrationError`,
`unregistrationError`) when the URL carries a failed result.

## Meta-AI-initiated registration

In DAT 1.0 the user can start the connection from the Meta AI app.
Subscribe early (for example in `main()` or your root widget), because
the request can arrive as soon as your app launches from Meta AI:

```dart
StreamSubscription<RegistrationRequest> listenForMetaAiRequests(
  Future<bool> Function() askUser,
) {
  return MetaWearablesDat.registrationRequestStream().listen((request) async {
    final accepted = await askUser();
    try {
      if (accepted) {
        await request.continueRegistration();
      } else {
        await request.cancel();
      }
    } on RegistrationRequestError catch (e) {
      // alreadyHandled: answered before or expired.
      debugPrint('registration request ${request.requestId}: $e');
    }
  });
}
```

Rules:

- Answer each request **exactly once**. A second answer throws a
  `StateError`; `request.isHandled` tells you whether it was answered.
- Unanswered requests **expire after five minutes**. Answering an
  expired request fails with `RegistrationRequestErrorCase.alreadyHandled`.
- After `continueRegistration()` the result arrives on
  `registrationStateStream()` like the app-initiated flow.

## Unregistration

```dart
try {
  await MetaWearablesDat.startUnregistration();
} on UnregistrationError catch (e) {
  if (e.reason != UnregistrationErrorCase.alreadyUnregistered) rethrow;
}
```

`startUnregistration()` stops any running session first. The state
moves to `available` (through `unregistering` on Android). Users can
also remove your app in the Meta AI app; watch
`registrationStateStream()` rather than assuming the app stays
registered.

## Permissions

DAT permissions are granted per app in the Meta AI app, not through
the iOS or Android permission dialogs. Request them after registration.

| `Permission` | Needed for |
| --- | --- |
| `camera` | `startStreamSession`, `capturePhoto`, experimental `captureHighResPhoto` |
| `microphone` | Experimental Speech (`startSpeech`) and the glasses microphone |

```dart
Future<bool> ensureCameraPermission() async {
  var status = await MetaWearablesDat.checkPermissionStatus(Permission.camera);
  if (status.isGranted) return true;
  try {
    status = await MetaWearablesDat.requestPermission(Permission.camera);
  } on PermissionError catch (e) {
    if (e.recoveryAction == DatRecoveryAction.connectGlasses) {
      // noDevice / noDeviceWithConnection: pair, power on and wear the glasses.
    }
    return false;
  }
  return status.isGranted;
}
```

- A denial is returned as `PermissionStatus.denied`, not thrown.
- `requestCameraPermission()` and `getCameraPermissionStatus()` still
  work but are deprecated; use `requestPermission(Permission.camera)`
  and `checkPermissionStatus(Permission.camera)`.
- Android needs `MainActivity` to extend `FlutterFragmentActivity`,
  otherwise `PermissionErrorCase.missingFragmentActivity`.

## Errors

| Error | Thrown by / delivered on | Common reasons and fixes |
| --- | --- | --- |
| `RegistrationError` | `startRegistration`, `registrationErrorStream` | `metaAINotInstalled`: install Meta AI. `configurationInvalid`: fix the findings from `dumpDiagnostics()`. `networkUnavailable`: retry online. `alreadyRegistered`: nothing to do. `noActivity` (Android): call from the foreground |
| `UnregistrationError` | `startUnregistration`, `registrationErrorStream` | `alreadyUnregistered`: nothing to do |
| `HandleUrlError` | `handleUrl` | `invalidUrl`: pass the full callback URL |
| `RegistrationRequestError` | `continueRegistration`, `cancel` | `alreadyHandled`: answered or expired |
| `PermissionError` | `requestPermission`, `checkPermissionStatus` | `noDevice`, `noDeviceWithConnection`: connect glasses. `requestInProgress`: wait. `metaAINotInstalled`. `missingFragmentActivity` (Android) |

Every error is a `DatError` with `category`, `code`, `message`,
`platformCase` and `recoveryAction`. See
[Streaming: error handling](streaming.md#error-handling) for the
pattern-matching style.

If registration never completes, check [Troubleshooting: registration](troubleshooting.md#registration).
