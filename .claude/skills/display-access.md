---
description: Render declarative UI on Ray-Ban Display glasses with the Display Access API (FlexBox/Text/Image/Button/Icon/VideoPlayer), callbacks, and DisplayState
globs: lib/**/*.dart, lib/src/models/display/**, ios/**/MetaDisplayManager.swift, android/**/MetaDisplayManager.kt
---

# Display Access (Flutter)

Guide for rendering a declarative UI tree on Ray-Ban Display glasses via
the `meta_wearables_dat_flutter` plugin. Wraps Meta DAT 0.7.0's
`MWDATDisplay` (iOS) / `mwdat-display` (Android) module.

## Key concepts

- **`startDisplaySession({deviceUUID?})`** — creates a `DeviceSession`,
  attaches the `Display` capability, and waits for it to start.
- **`sendDisplayView(DisplayView view)`** — serializes a Dart component
  tree to JSON, rebuilds it natively, and renders it on the glasses.
- **`displayStateStream()`** — `DisplayState`: `starting | started |
  stopping | stopped`. The display is ready once it reaches `started`.
- **`stopDisplaySession()`** — detaches the display and tears down the
  session.
- **Callbacks** — `onTap` (FlexBox), `onClick` (Button), and
  `onPlaybackEvent` (VideoPlayer) closures are assigned ids during
  serialization and dispatched back from the `display_events` channel.
  The callback table is rebuilt on every `sendDisplayView`, so ids only
  resolve for the view currently on screen.

## Lifecycle

```dart
await MetaWearablesDat.requestAndroidPermissions(); // Android only
await MetaWearablesDat.startRegistration();          // connect glasses
await MetaWearablesDat.startDisplaySession();
MetaWearablesDat.displayStateStream().listen((s) {
  // starting | started | stopping | stopped
});
await MetaWearablesDat.sendDisplayView(myView);
// ...later
await MetaWearablesDat.stopDisplaySession();
```

## Building a view

```dart
final view = FlexBox(
  spacing: 12,
  children: [
    FlexBox(
      padding: 24,
      background: FlexBoxBackground.card,
      onTap: () => print('card tapped'),
      children: [
        DisplayText('Oil change', style: DisplayTextStyle.heading),
        DisplayText(
          'Easy • 45 min',
          style: DisplayTextStyle.meta,
          color: DisplayTextColor.secondary,
        ),
        DisplayImage(
          'https://example.com/oil.png',
          sizePreset: DisplayImageSize.fill,
          cornerRadius: DisplayCornerRadius.medium,
        ),
      ],
    ),
    FlexBox(
      direction: DisplayDirection.row,
      spacing: 8,
      alignment: DisplayAlignment.center,
      children: [
        DisplayButton(label: 'Back', onClick: () => goBack()),
        DisplayButton(
          label: 'Next',
          iconName: DisplayIconName.triangleRightVerticalLine,
          onClick: () => goNext(),
        ),
      ],
    ),
  ],
);
await MetaWearablesDat.sendDisplayView(view);
```

## Components

| Dart model | Meta type | Notes |
| --- | --- | --- |
| `FlexBox` | `FlexBox` | `direction`, `spacing`, `padding`, `background`, `alignment`, `crossAlignment`, `wrap`, `flexGrow`, `onTap` |
| `DisplayText` | `Text` | `style` (heading/body/meta), `color` (primary/secondary) |
| `DisplayImage` | `Image` | remote `uri`, `sizePreset`, `cornerRadius` |
| `DisplayButton` | `Button` | `label`, `style`, `iconName`, `onClick` |
| `DisplayIcon` | `Icon` | built-in `DisplayIconName` glyph |
| `VideoPlayer` | `VideoPlayer` | root-only; `uri` provider + `onPlaybackEvent` |

## Video playback

```dart
final view = VideoPlayer(
  'https://example.com/clip.mp4',
  onPlaybackEvent: (event) {
    if (event.type == DisplayPlaybackEventType.ended) showNextStep();
  },
);
await MetaWearablesDat.sendDisplayView(view);
```

`VideoPlayer` is a root view, not a nestable component. The plugin starts
playback automatically once the video is sent.

## Bridge architecture

- Dart `DisplayNode.toJson()` emits a plain map with `onTapId` /
  `onClickId` / `onPlaybackEventId` keys; the `DisplayCallbackTable`
  maps those ids back to closures.
- Native `MetaDisplayManager` (Swift / Kotlin) rebuilds the SDK DSL from
  the JSON, wires each callback to emit `{callbackId, type, event?}` on
  the `display_events` channel, and forwards `DisplayState` on
  `display_state`.
- One display session per device; the camera and display sessions are
  independent.

## Gotchas

- Requires DAT 0.7.0+ and a Display-capable device (Ray-Ban Display).
- `sendDisplayView` throws if no session is active — call
  `startDisplaySession()` first.
- New `DeviceSessionError.datAppOnTheGlassesUpdateRequired` surfaces when
  the on-glasses DAT app needs an update.

## Links

- [`doc/display_access.md`](../../doc/display_access.md)
- Sample app: [`samples/display_access/`](../../samples/display_access/)
- Meta Display docs:
  <https://wearables.developer.meta.com/docs/develop/>
