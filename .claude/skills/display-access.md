---
description: Render declarative UI on Meta Ray-Ban Display glasses (FlexBox/DisplayText/DisplayImage/DisplayButton/DisplayButtonGroup/DisplayIcon/VideoPlayer), callbacks, warnings, errors and DisplayState (DAT 1.0)
globs: lib/**/*.dart, lib/src/models/display/**, ios/**/MetaDisplayManager.swift, ios/**/DisplayNode.swift, android/**/MetaDisplayManager.kt, android/**/DisplayNode.kt, samples/display_access/**
---

# Display Access (Flutter, DAT 1.0)

Wraps `MWDATDisplay` (iOS) / `mwdat-display` (Android) for Meta Ray-Ban
Display glasses (`DeviceInfo.supportsDisplay`).

## Key facts

- 600 x 600 canvas. Every `sendDisplayView` replaces the whole view.
- Display dims after ~20 s and sleeps after ~25 s of inactivity.
- The user's Back gesture ends the display session
  (`displayStateStream` → `stopped`).
- Display shares the device session with camera and experimental
  capabilities (`DeviceSessionHub`).

## API

| Call | Notes |
|---|---|
| `startDisplaySession({deviceUUID})` | acquires the shared session, adds the display, waits for `started` |
| `sendDisplayView(DisplayView)` → `List<String>` | build warnings (unsupported values substituted) |
| `clearDisplay()` | blank view |
| `stopDisplayVideo()` | stops a playing `VideoPlayer` |
| `stopDisplaySession()` | removes the display, releases the session |
| `displayStateStream()` | `starting` / `started` / `stopping` / `stopped` |
| `displayErrorStream()` | `DisplayError` (`DisplayErrorCase`) |
| `displayWarningStream()` | warnings from native builders |

## Building a view

```dart
final view = FlexBox(
  spacing: 12,
  paddingInsets: const DisplayEdgeInsets.all(24),
  children: [
    const DisplayText('Oil change', style: DisplayTextStyle.heading),
    const DisplayText('Easy, 45 min',
        style: DisplayTextStyle.meta, color: DisplayTextColor.secondary),
    const DisplayImage('https://example.com/oil.png',
        sizePreset: DisplayImageSize.fill,
        cornerRadius: DisplayCornerRadius.medium),
    DisplayButtonGroup(buttons: [
      DisplayButton(label: 'Back', onClick: goBack),
      DisplayButton(
        label: 'Next',
        iconName: DisplayIconName.triangleRightVerticalLine,
        actionRole: DisplayActionRole.primary,
        onClick: goNext,
      ),
    ]),
  ],
);
for (final issue in view.validate()) debugPrint('$issue');
final warnings = await MetaWearablesDat.sendDisplayView(view);
```

## Components

| Dart | Meta | Notes |
|---|---|---|
| `FlexBox` | `FlexBox` | `direction`, `spacing`, `padding` / `paddingInsets`, `background` (`none`/`card`), `alignment` / `crossAlignment` (incl. `spaceBetween/Around/Evenly`), `wrap`, `onTap`. `cornerRadius` deprecated (unsupported) |
| `DisplayText` | `Text` | `style` (heading/body/meta), `color` (primary/secondary) |
| `DisplayImage` / `DisplayImage.bytes` | `Image` | https or `data:` URI, or PNG/JPEG bytes; `sizePreset`, `cornerRadius` |
| `DisplayButton` | `Button` | `label`, `style`, `iconName`, `actionRole`, `onClick` |
| `DisplayButtonGroup` | `ButtonGroup` | focus/collapse behaviour, `alignment` |
| `DisplayIcon` | `Icon` | 116 `DisplayIconName`, `DisplayIconStyle` filled/outline |
| `VideoPlayer` | `VideoPlayer` | root only; https MP4, max 400 px per side and 70,000 px total; `onPlaybackEvent` |

All nodes accept `flexGrow`, `flexShrink`, `alignSelf`.
`DisplayNode.validate()` checks the tree against the SDK rules.

## Video

```dart
await MetaWearablesDat.sendDisplayView(VideoPlayer(
  'https://example.com/clip.mp4',
  onPlaybackEvent: (e) {
    if (e.type == DisplayPlaybackEventType.ended) showNext();
  },
));
```

`DisplayPlaybackEventType`: `started`, `paused`, `ended`, `stopped`,
`error`, `unknown`.

## Bridge internals

- `DisplayNode.toJson(callbacks)` embeds `onTapId` / `onClickId` /
  `onPlaybackEventId`; `DisplayCallbackTable` resolves them. Ids are
  rebuilt on every send.
- Native `DisplayNode` builders rebuild the SDK DSL and emit
  `{callbackId, type, event?}` on `display_events`.
- iOS `IconName` raw values are snake_case; `DisplayNode.swift` converts
  from camelCase. Regenerate Dart names with
  `dart run tool/gen_icon_names.dart` (source `tool/display_icons.json`).
- Android: builders take named arguments; never call `display.stop()`
  (NPE risk) — detach with `session.removeDisplay()`. The display
  `StateFlow` starts at `STOPPED`; only a STOPPED after leaving STOPPED
  is terminal.

## Gotchas

- `sendDisplayView` before `startDisplaySession` throws `DisplayError`
  (`notStarted`).
- `DeviceSessionErrorCase.datAppOnTheGlassesUpdateRequired` →
  `openDatGlassesAppUpdate()`.
- Mock: `sendMockDisplayClick` may not fire `onClick` (identifier format
  undocumented). Use `startMockTestServer()` and the Chrome "Meta Ray-Ban
  Display Simulator" preview.

## Links

- [`doc/display_access.md`](../../doc/display_access.md)
- Sample: [`samples/display_access/`](../../samples/display_access/)
- Meta docs: <https://wearables.developer.meta.com/docs/develop/>
