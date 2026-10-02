# Production checklist

Use this before you hand a build of **your app** to testers or users.
(Releasing the plugin itself is covered in the
[release checklist](release_checklist.md).)

Distribution today: Meta's iOS guide states that publishing DAT apps to
the App Store is not currently supported. Distribute through Developer
Mode and the invite-only **Beta release channel** of the Wearables
Developer Center. Treat this checklist as "Beta-channel ready"; the
same items apply once store distribution opens.

## Wearables Developer Center

- [ ] The app exists in the Wearables Developer Center and has a **new
      app version created for your DAT 1.0 build**.
- [ ] iOS `MWDAT` has the real `MetaAppID`, `ClientToken` and `TeamID`
      (no `0`, no placeholder). Android has the real `APPLICATION_ID`
      and `CLIENT_TOKEN` meta-data.
- [ ] Credentials come from build configuration (xcconfig variables,
      Gradle `manifestPlaceholders`), not hard-coded in source control.
- [ ] Testers are invited to the Beta release channel and have the
      required Meta AI app (V290+) and glasses firmware (V128+).
- [ ] Capabilities that need approval (Inputs, Voice Invocation) are
      not used, or are approved and the build stays on Beta (see
      [Experimental APIs](#experimental-apis)).

## Configuration

- [ ] `dumpDiagnostics()` on a release build reports **zero findings of
      severity `error` or `warning`**. `developerModeCredentials` must not
      appear either.
- [ ] `diagnostics.pluginVersion` and `diagnostics.sdkVersion` are what
      you expect (`1.0.x` / `1.0.0`).
- [ ] iOS: deployment target 17.2+, built with Xcode 26.4+, Swift
      Package Manager (no CocoaPods resolution of this plugin).
- [ ] iOS: no `DAMEnabled`; Android: no `DAM_ENABLED`.
- [ ] Android: `MainActivity` extends `FlutterFragmentActivity`,
      `minSdk` 31, no GitHub Packages repository or token left in the
      build.
- [ ] The callback scheme is unique to your app, RFC 3986 compliant,
      and identical in `MWDAT > AppLinkURLScheme` (with `://`),
      `CFBundleURLTypes` and the Android intent filter.
- [ ] Mock Device Kit is never enabled in release builds
      (`resources['mockDevices'] == 0`, `enableMockDevice` behind
      `kDebugMode` or a flavour).

## Privacy

- [ ] iOS usage strings are user-facing and accurate:
      `NSBluetoothAlwaysUsageDescription`,
      `NSLocalNetworkUsageDescription`, and
      `NSMicrophoneUsageDescription` if you use the `audio` background
      mode, Speech or in-stream audio.
- [ ] Your app's `PrivacyInfo.xcprivacy` declares the data your app
      collects from the glasses (for example photos, video, audio,
      transcriptions) and how it is used. The plugin ships its own
      privacy manifest (no tracking) for its code only.
- [ ] Analytics and crash-reporting opt-outs (`MWDAT > Analytics`,
      `MWDAT > CrashReporting`, Android `ANALYTICS_OPT_OUT` /
      `CRASH_REPORTING_OPT_OUT`) are set the way your privacy policy
      says. `dumpDiagnostics().raw` shows `analyticsOptOut` and
      `crashReportingOptOut` on iOS.
- [ ] Your privacy policy covers the camera, microphone and device data
      your app processes, and where it is sent.

## Registration and permissions

- [ ] Both registration flows work: app-initiated
      (`startRegistration`) and Meta-AI-initiated
      (`registrationRequestStream`, answered once, within five minutes).
- [ ] Unregistration works, and the app reacts when the user removes it
      in Meta AI (`registrationStateStream` leaves `registered`).
- [ ] `Permission.camera` (and `Permission.microphone` if used) are
      requested in context, and a `denied` result has a clear message.
- [ ] Android: `requestAndroidPermissions()` runs before any glasses
      call, and a refusal is handled.

## Error handling

- [ ] Every `startStreamSession`, `startDisplaySession` and
      `capturePhoto` call catches `DatError` subclasses.
- [ ] `streamErrorStream()`, `deviceSessionErrorStream()` and
      `displayErrorStream()` are listened to and shown to the user.
- [ ] `recoveryAction` is honoured: `openDatGlassesAppUpdate()`,
      `openFirmwareUpdate()` (for `deviceUpdateRequired`), an "update
      this app" message for `insufficientSDKVersion` (terminal), and a
      non-blocking hint for `dwaOutOfStuRange`. See
      [Device state](device_state.md#update-flows).
- [ ] Thermal and battery: the app lowers quality/frame rate when
      `thermalLevel.isThrottling` and stops optional work when
      `isCritical`.
- [ ] `hingesClosed`, doff/don and touchpad pause are handled without
      leaving the UI in a broken state.
- [ ] Error messages shown to users are your own localized strings,
      not `DatError.message`.

## Resources and lifecycle

- [ ] After stopping everything, `dumpDiagnostics().isIdle` is `true`
      (all resource counters `0`). Check after a stream, a display
      session, and 20 start/stop cycles.
- [ ] `stopStreamSession()` is called when the streaming screen is
      disposed; `stopDisplaySession()` likewise.
- [ ] Every subscription to `videoFramesStream()` and other streams is
      cancelled when no longer needed.

## Background behaviour

- [ ] Decide the policy: on iOS the stream **stops** in the background
      unless `enableBackgroundStreaming()` was called before
      `startStreamSession()`.
- [ ] If you stream in the background on iOS: `VideoCodec.hvc1`
      (raw frames pause), `audio` background mode, and the
      `stoppedInBackground` / `rawPausedInBackground` warnings handled.
- [ ] If you stream in the background on Android: a meaningful
      `BackgroundNotification`, `POST_NOTIFICATIONS` requested on
      Android 13+, `disableBackgroundStreaming()` when done.
- [ ] Tested: lock the phone during a stream, switch apps, return.

## Experimental APIs

- [ ] A build for a **production** release channel contains **no
      experimental API calls** (Inputs, Motion, Speech, voice
      invocations, `captureHighResPhoto`, in-stream audio, experimental
      mock simulators). Search for `experimental_member_use` ignores to
      find them.
- [ ] Android: optionally set `mwdat.experimental=false` to drop the
      experimental binaries (see [Experimental APIs](experimental.md#android-opting-out-of-the-experimental-modules)).
- [ ] Builds that do use experimental APIs stay on Developer Mode or the
      Beta release channel.

## Devices

- [ ] Tested on real glasses for every model you support (Ray-Ban Meta,
      Oakley Meta, Meta Ray-Ban Display), on the minimum Meta AI app and
      firmware versions.
- [ ] Tested on the oldest iOS (17.2) and Android (12) versions you
      support.
