# `display_access` (Flutter)

A polished Flutter clone of Meta's official iOS and Android **Display Access**
"Car Maintenance" sample, built on `meta_wearables_dat_flutter`.

It renders a declarative UI tree on Ray-Ban Display glasses: a scrollable list
of car-maintenance tutorials, a detail screen with images, step-by-step
instructions, and an inline video — all driven from Dart with the plugin's
`startDisplaySession` / `sendDisplayView` API. Touchpad taps and button clicks
on the glasses fire Dart callbacks that send the next screen.

## Setup

1. Install Flutter `>=3.24.0` and ensure SPM is enabled:
   ```bash
   flutter config --enable-swift-package-manager
   ```
2. Place a GitHub PAT with `read:packages` scope into `local.properties`
   (Android) under `github_token=...`, or export `GITHUB_TOKEN` in your
   shell.
3. Open `ios/Runner.xcodeproj` and set your team and bundle id.
4. Update `ios/Runner/Info.plist`'s `MWDAT` dictionary with your
   `MetaAppID`, `ClientToken`, and `TeamID` from the Wearables Developer
   Center. (Default values are placeholders for hardware-less testing.)
5. Run:
   ```bash
   cd samples/display_access
   flutter run
   ```

## Tour

- **Home** — registration status, BT / Internet permission, the live display
  state, and the screen currently shown on the glasses.
- **Start display** — `startDisplaySession()` attaches the display capability
  and `sendDisplayView()` renders the tutorial list.
- **On the glasses** — tap a tile to open a tutorial, step Previous / Next /
  Done through the instructions, and "Watch video" to play an inline clip
  whose `ended` event advances back to the step.

## How it maps to the Display API

| UI piece | Plugin model |
| --- | --- |
| Cards / rows | `FlexBox(direction, spacing, padding, background, …)` |
| Titles / body | `DisplayText(style:, color:)` |
| Thumbnails | `DisplayImage(sizePreset:, cornerRadius:)` |
| Buttons | `DisplayButton(style:, iconName:, onClick:)` |
| Inline video | `VideoPlayer(url, onPlaybackEvent:)` |

## Differences from Meta's official samples

- Pure Dart UI (no SwiftUI / Compose).
- One unified codebase across iOS and Android.
- `VideoPlayer` exposes the `.uri` provider only, matching the official sample.
