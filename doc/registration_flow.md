# Registration flow

Registration pairs your app with a specific user's Meta account and
glasses. It is a deep-link round-trip: your app -> Meta AI -> your app.

## End-to-end timeline

```
[1] requestAndroidPermissions()    (Android only, no-op on iOS)
[2] startRegistration()
[3] Meta AI app handles consent
[4] Meta AI deep-links back into your app's URL scheme
[5] handleUrl(uri.toString())     (iOS only; Android consumes the
                                   intent-filter automatically)
[6] registrationStateStream() emits RegistrationState.registered
[7] activeDeviceStream() emits a non-null DeviceInfo
```

## Code

```dart
import 'package:app_links/app_links.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

final appLinks = AppLinks();

// 1. Permissions (Android only, returns true on iOS).
await MetaWearablesDat.requestAndroidPermissions();

// 2. Listen for state transitions.
MetaWearablesDat.registrationStateStream().listen((state) {
  print('Registration state: $state');
});

// 3. Forward incoming deep links to the SDK on iOS. Android consumes
//    the intent-filter on its own.
appLinks.uriLinkStream.listen((uri) {
  MetaWearablesDat.handleUrl(uri.toString());
});

// 4. Kick off the flow.
await MetaWearablesDat.startRegistration();
```

## RegistrationState semantics

| State           | Meaning                                                   |
| --------------- | --------------------------------------------------------- |
| `unavailable`   | SDK not initialised, or no internet.                      |
| `available`     | SDK ready, no glasses paired.                             |
| `registering`   | Mid-flow: Meta AI screen is up, or returning from it.     |
| `registered`    | Glasses paired and active. APIs requiring a device work.  |

## Unregistering

```dart
await MetaWearablesDat.startUnregistration();
```

## Troubleshooting

- **State stays `unavailable`** on Android — `BLUETOOTH_CONNECT` was not
  granted. Call `requestAndroidPermissions()` and verify the user
  accepted.
- **Deep link never returns** — check that your URL scheme matches the
  one in `Info.plist` (iOS) / `AndroidManifest.xml` (Android) and that
  Meta AI is installed.
- **Android's `MainActivity` does not receive the deep link** — verify
  `launchMode="singleTop"` and the `<intent-filter>` block.
