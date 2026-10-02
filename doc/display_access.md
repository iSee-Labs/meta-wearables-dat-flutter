# Display access

Display access renders a declarative view on the in-lens display of
**Meta Ray-Ban Display** glasses. You build a tree of `DisplayNode`s in
Dart, send it with `sendDisplayView`, and receive taps, clicks and video
playback events as Dart callbacks. It wraps `MWDATDisplay` (iOS) and
`mwdat-display` (Android).

## Prerequisites

- Registered app (see [Registration](registration_flow.md)).
- Meta Ray-Ban Display glasses: `DeviceInfo.supportsDisplay` is `true`
  (`DeviceKind.rayBanDisplay`, `DeviceType.metaRayBanDisplay`).
- No extra permission is needed for the display.

## Display constraints

| Constraint | Detail |
| --- | --- |
| Canvas | 600 x 600, vertical scrolling only |
| Updates | Every `sendDisplayView` **replaces the whole view** and every callback on it |
| Root | A `FlexBox` or a `VideoPlayer`. Other roots are wrapped in a column |
| Dimming | The display dims after about 20 s and sleeps after about 25 s without interaction |
| Back gesture | Ends the display session: `displayStateStream()` emits `stopped`. Start a new session to show something again |
| Video | MP4 over https, at most 400 px per side and 70,000 px in total, root only |

## Lifecycle

```dart
MetaWearablesDat.displayStateStream().listen((state) {
  // starting, started, stopping, stopped (also after Back on the glasses)
});
MetaWearablesDat.displayErrorStream().listen((error) {
  debugPrint('display: $error');
});

await MetaWearablesDat.startDisplaySession(); // or deviceUUID: uuid
final warnings = await MetaWearablesDat.sendDisplayView(buildHome());
await MetaWearablesDat.clearDisplay();        // blank the display, keep the session
await MetaWearablesDat.stopDisplaySession();
```

| Method | Purpose |
| --- | --- |
| `startDisplaySession({deviceUUID})` | Opens (or joins) the device session and starts the display. Throws `DeviceSessionError` or `DisplayError` |
| `sendDisplayView(view)` | Replaces the view. Returns warnings for unsupported values (substituted, not fatal). Throws `DatArgumentError` for an invalid tree, `DisplayError` otherwise |
| `clearDisplay()` | Clears the view |
| `stopDisplayVideo()` | Stops the video that is playing |
| `stopDisplaySession()` | Stops the display; closes the device session if the camera and experimental capabilities do not use it |
| `displayStateStream()` | `DisplayState`; emits the current state first |
| `displayErrorStream()` | `DisplayError` (display and video playback) |
| `displayWarningStream()` | Warnings for unsupported view values |

The display shares one device session with the camera, so you can
stream and show a view on the same glasses at the same time (see
[Streaming](streaming.md#sharing-the-device-session-with-display-and-other-capabilities)).

## Building a view

```dart
DisplayView buildHome() => FlexBox(
  spacing: 12,
  paddingInsets: const DisplayEdgeInsets.symmetric(horizontal: 24, vertical: 16),
  children: [
    const DisplayText('Oil change', style: DisplayTextStyle.heading),
    const DisplayText(
      'Easy, 45 min',
      style: DisplayTextStyle.meta,
      color: DisplayTextColor.secondary,
    ),
    FlexBox(
      background: FlexBoxBackground.card,
      direction: DisplayDirection.row,
      spacing: 8,
      crossAlignment: DisplayAlignment.center,
      onTap: () => showDetail(),
      children: const [
        DisplayIcon(DisplayIconName.clock, style: DisplayIconStyle.outline),
        DisplayText('Next service in 3 weeks'),
      ],
    ),
    DisplayButtonGroup(
      buttons: [
        DisplayButton(
          label: 'Start',
          iconName: DisplayIconName.triangleRight,
          actionRole: DisplayActionRole.primary,
          onClick: () => startSteps(),
        ),
        DisplayButton(
          label: 'Later',
          style: DisplayButtonStyle.secondary,
          onClick: () => MetaWearablesDat.clearDisplay(),
        ),
      ],
    ),
  ],
);
```

### Components

| Component | Fields |
| --- | --- |
| `FlexBox` | `children`, `direction` (`row`, `column`, `rowReverse`, `columnReverse`), `spacing`, `padding` or `paddingInsets` (`DisplayEdgeInsets`), `background` (`none`, `card`), `alignment`, `crossAlignment`, `wrap`, `onTap` |
| `DisplayText` | `text`, `style` (`heading`, `body`, `meta`), `color` (`primary`, `secondary`) |
| `DisplayImage` | `DisplayImage(uri)` (https or `data:` URL) or `DisplayImage.bytes(bytes)` (PNG/JPEG, downscaled by the SDK); `sizePreset` (`fill`, `icon`), `cornerRadius` (`none`, `small`, `medium`) |
| `DisplayButton` | `label`, `style` (`primary`, `secondary`, `outline`), `iconName`, `actionRole`, `onClick` |
| `DisplayButtonGroup` | `buttons` (`List<DisplayButton>`), `alignment` (`start`, `center`, `end`) |
| `DisplayIcon` | `name` (`DisplayIconName`), `style` (`filled`, `outline`) |
| `VideoPlayer` | `uri`, `codec` (`DisplayVideoCodec.mp4`), `onPlaybackEvent` |

Every node also takes `flexGrow`, `flexShrink` and `alignSelf` (except
`VideoPlayer`).

Notes:

- **`actionRole: DisplayActionRole.primary`** marks the primary action;
  the first primary button gets focus when the view first renders.
- **`DisplayButtonGroup`** gives buttons the platform's focus and
  collapse behaviour: unfocused icon buttons collapse to their icon, the
  focused one shows its label. Prefer it over a row of loose buttons.
- **`DisplayIconName`** has the 116 icons of the DAT 1.0 Display SDK
  (generated from Meta's list), for example `checkmarkCircle`, `bell`,
  `gear`, `metaAi`, `triangleRight`, `x`.
- `DisplayAlignment.spaceBetween`, `spaceAround`, `spaceEvenly`,
  `DisplayCornerRadius.large` and `FlexBox.cornerRadius` are deprecated:
  the Display SDK does not support them. They render as `center`,
  `medium` and nothing respectively, and produce a warning.

### Validate before sending

`DisplayNode.validate()` checks a tree against the SDK rules without a
device:

```dart
final issues = buildHome().validate();
for (final issue in issues) {
  debugPrint(issue.toString()); // "error: ..." or "warning: ..."
}
final canSend = issues.every((issue) => !issue.isFatal);
```

It reports, for example, a nested `VideoPlayer` (fatal), a non-https
video URL, an empty `DisplayButtonGroup` and a root that is not a
`FlexBox`.

## Callbacks

`FlexBox.onTap`, `DisplayButton.onClick` and `VideoPlayer.onPlaybackEvent`
are plain Dart closures. Each send builds a new callback table, so only
handlers of the view currently on the glasses fire. Drive navigation by
sending a new view from a callback:

```dart
DisplayView listView(List<String> titles) => FlexBox(
  spacing: 8,
  children: [
    for (final title in titles)
      FlexBox(
        background: FlexBoxBackground.card,
        onTap: () => MetaWearablesDat.sendDisplayView(detailView(title)),
        children: [DisplayText(title)],
      ),
  ],
);
```

## Video

`VideoPlayer` must be the root view:

```dart
await MetaWearablesDat.sendDisplayView(
  VideoPlayer(
    'https://example.com/step1.mp4',
    onPlaybackEvent: (event) {
      if (event.type == DisplayPlaybackEventType.ended) {
        MetaWearablesDat.sendDisplayView(buildHome());
      }
    },
  ),
);

// Stop playback early:
await MetaWearablesDat.stopDisplayVideo();
```

`DisplayPlaybackEventType`: `started`, `paused` (Android), `ended`,
`stopped`, `error`, `unknown`. The pre-1.0 name `playing` is a
deprecated alias of `started`.

Playback failures arrive on `displayErrorStream()` as
`DisplayErrorCase.videoPlaybackFailed` (details in
`error.details['videoErrorType']`), `invalidVideoURL` (iOS) or
`unsupportedCodec`.

## Errors

| `DisplayErrorCase` | Meaning |
| --- | --- |
| `notStarted` | No display session; call `startDisplaySession()` |
| `timeout` | The display did not start in time; retry |
| `deviceDisconnected` | Glasses disconnected |
| `invalidSessionState` (Android) | The display is not in a state that accepts the call |
| `renderingFailed` (Android), `displayError` (iOS) | The SDK rejected or failed to render the view |
| `videoPlaybackFailed`, `invalidVideoURL`, `unsupportedCodec` | Video problems (see above) |
| `unexpectedError`, `unknown` | Other SDK failures |

`startDisplaySession` can also throw a `DeviceSessionError`, for example
`datAppOnTheGlassesUpdateRequired`; handle it with
`MetaWearablesDat.openDatGlassesAppUpdate()` (see
[Device state](device_state.md#update-flows)).

## Previewing without glasses

With the [Mock Device Kit](mock_device.md) you can pair simulated
`MockGlassesModel.metaRayBanDisplay` glasses and preview the display in
Chrome:

```dart
await MetaWearablesDat.enableMockDevice();
final glasses = await MetaWearablesDat.pairMockGlasses(
  MockGlassesModel.metaRayBanDisplay,
);
await MetaWearablesDat.mockPowerOn(glasses.uuid);
await MetaWearablesDat.mockUnfold(glasses.uuid);
await MetaWearablesDat.mockDon(glasses.uuid);

final port = await MetaWearablesDat.startMockTestServer(); // 9000 by default
await MetaWearablesDat.startDisplaySession(deviceUUID: glasses.uuid);
await MetaWearablesDat.sendDisplayView(buildHome());
```

1. Install the **Meta Ray-Ban Display Simulator** Chrome extension.
2. Open `http://127.0.0.1:<port>/`.
3. iOS: works on the iOS Simulator only. Android: forward the port
   first with `adb forward tcp:9000 tcp:9000`.
4. `stopMockTestServer()` when done.

`sendMockDisplayClick(uuid, '0')` clicks a clickable component (the SDK
numbers them `'0'`, `'1'`, ... in build order). Meta does not document
the identifier format: it returns `true` but may not fire your
`onClick` callback. See [Troubleshooting](troubleshooting.md#known-issues).

## See also

- Sample: [`samples/display_access/`](../samples/display_access/), a port
  of Meta's "Car Maintenance" Display sample.
- [Experimental Inputs](experimental.md#inputs) for raw touchpad and
  Neural Band events.
