# `glasses_companion` (Flutter)

A companion-app sample for `meta_wearables_dat_flutter` 1.0. Where
`camera_access` and `display_access` mirror Meta's official samples one to
one, this app shows the features added in Meta Wearables DAT 1.0 in one
place:

| Tab | What it shows |
|---|---|
| **Devices** | Registration (including Meta-AI-initiated requests), `dumpDiagnostics()` configuration findings, a device picker, live battery / charging / thermal / wear / hinge state from `deviceStateStream`, firmware and glasses-app update deep links, and Mock Device Kit controls. |
| **Camera** | HEVC (`hvc1`) preview through a `Texture`, quality selection, `capturePhoto`, and the experimental `captureHighResPhoto`. |
| **Display** | A status card on Ray-Ban Display glasses that mirrors device state, with a `DisplayButtonGroup` whose primary button calls back into Dart. |
| **Lab** | The experimental modules: inputs, motion, speech and voice invocations. |

The Lab tab and the high-resolution photo use experimental APIs. They work in
Developer Mode, but Meta does not allow them in apps on production release
channels.

## Setup

1. Install Flutter `>=3.44.0` (Swift Package Manager is the default) and
   Xcode 26.4 or newer. The iOS deployment target is 17.2.
2. Android needs no extra setup: Meta's SDK resolves from Maven Central.
3. Open `ios/Runner.xcodeproj` and set your team and bundle id.
4. Put your `MetaAppID`, `ClientToken` and `TeamID` from the Wearables
   Developer Center into the `MWDAT` dictionary in `ios/Runner/Info.plist`,
   and the matching meta-data into `android/app/src/main/AndroidManifest.xml`.
   The URL scheme is `glassescompanion://`. The placeholder values work in
   Developer Mode and with mock glasses.
5. Run:
   ```bash
   cd samples/glasses_companion
   flutter run
   ```

## Without glasses

On the Devices tab, pick a model and tap **Add mock**. The app enables Mock
Device Kit, pairs simulated glasses, powers them on, unfolds and dons them,
and loads a bundled H.265 clip as the camera feed. Pick `metaRayBanDisplay`
to try the Display tab. The battery slider, thermal menu and the
charging / worn / open chips drive the mock device, and the state card
updates live.
