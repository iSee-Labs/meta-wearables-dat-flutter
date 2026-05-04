/// `meta_wearables_dat_flutter` is an unofficial Flutter plugin bridging
/// Meta's official iOS and Android Wearables Device Access Toolkit (DAT)
/// SDKs. It is not affiliated with Meta Platforms, Inc.
///
/// Public entry point: [MetaWearablesDat]. All methods on the facade are
/// static; lifecycle is managed by the plugin internally and shared across
/// the entire Flutter engine.
library;

import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_platform_interface.dart';
import 'package:meta_wearables_dat_flutter/src/models/camera_facing.dart';
import 'package:meta_wearables_dat_flutter/src/models/device_info.dart';
import 'package:meta_wearables_dat_flutter/src/models/frame_data.dart';
import 'package:meta_wearables_dat_flutter/src/models/photo_result.dart';
import 'package:meta_wearables_dat_flutter/src/models/registration_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/session_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/stream_quality.dart';
import 'package:meta_wearables_dat_flutter/src/models/video_stream_size.dart';

export 'package:meta_wearables_dat_flutter/src/models/camera_facing.dart';
export 'package:meta_wearables_dat_flutter/src/models/dat_error.dart';
export 'package:meta_wearables_dat_flutter/src/models/device_info.dart';
export 'package:meta_wearables_dat_flutter/src/models/frame_data.dart';
export 'package:meta_wearables_dat_flutter/src/models/photo_result.dart';
export 'package:meta_wearables_dat_flutter/src/models/registration_state.dart';
export 'package:meta_wearables_dat_flutter/src/models/session_state.dart';
export 'package:meta_wearables_dat_flutter/src/models/stream_quality.dart';
export 'package:meta_wearables_dat_flutter/src/models/video_stream_size.dart';

/// Static facade for the entire plugin.
///
/// **Lifecycle order** (see `doc/getting_started.md`):
///
/// 1. [requestAndroidPermissions] (Android only; safe no-op on iOS).
/// 2. [startRegistration] + [handleUrl] (host app forwards inbound deep
///    links to [handleUrl]).
/// 3. [requestCameraPermission] (Meta AI bottom sheet).
/// 4. [startStreamSession] returns a Flutter texture id; render with
///    `Texture(textureId: id)`.
/// 5. [stopStreamSession] when done.
abstract final class MetaWearablesDat {
  // --- Diagnostics ----------------------------------------------------------

  /// Returns a short string identifying the host platform, e.g.
  /// `iOS 17.4` or `Android 14`. Useful as a smoke check that the plugin's
  /// native side is correctly wired in your app — see `doc/getting_started.md`.
  static Future<String?> getPlatformVersion() {
    return MetaWearablesDatPlatform.instance.getPlatformVersion();
  }

  // --- Permissions ----------------------------------------------------------

  /// Requests the Android runtime permissions Meta's SDK requires
  /// (`BLUETOOTH_CONNECT` and `INTERNET`).
  ///
  /// Returns `true` if every required permission ends up granted, `false`
  /// otherwise. On iOS this method is a documented no-op and always resolves
  /// to `true` immediately, so host apps can call it unconditionally.
  ///
  /// Must be called once before any other registration / session method on
  /// Android — the underlying SDK initialises lazily after Bluetooth is
  /// granted.
  static Future<bool> requestAndroidPermissions() {
    return MetaWearablesDatPlatform.instance.requestAndroidPermissions();
  }

  /// Requests the wearable-side **camera permission** by deep-linking into
  /// the Meta AI app and showing its standard permission bottom sheet.
  ///
  /// Returns `true` when the user grants the permission and the SDK
  /// confirms it, `false` if the user denies. Throws [PermissionError] when
  /// the request cannot be initiated (no registered device, glasses
  /// disconnected, ...).
  ///
  /// On Android this drives `Wearables.RequestPermissionContract`, which
  /// requires the host activity to extend `FlutterFragmentActivity`
  /// (otherwise [DatErrorCodes.missingFragmentActivity] is thrown).
  static Future<bool> requestCameraPermission() {
    return MetaWearablesDatPlatform.instance.requestCameraPermission();
  }

  /// Returns the current wearable-side camera permission status without
  /// triggering the Meta AI bottom sheet. Convenience wrapper around the
  /// SDK's `checkPermissionStatus(.camera)`.
  static Future<bool> getCameraPermissionStatus() {
    return MetaWearablesDatPlatform.instance.getCameraPermissionStatus();
  }

  // --- Registration ---------------------------------------------------------

  /// Starts the device registration flow.
  ///
  /// On both platforms this opens the Meta AI app (or its developer-mode
  /// bottom sheet) where the user authorises the host app to access a paired
  /// wearable. When the user confirms, the Meta AI app deep-links back into
  /// the host app — at which point the host **must** forward the inbound URL
  /// to [handleUrl] for the SDK to complete registration.
  ///
  /// [appId] / [urlScheme] are optional overrides; when omitted, the SDK
  /// uses values from the host app's `Info.plist` (`MWDAT` dict on iOS) or
  /// `AndroidManifest.xml` `<meta-data>` entries (Android).
  ///
  /// Throws [RegistrationError] if registration cannot be initiated.
  static Future<void> startRegistration({
    String? appId,
    String? urlScheme,
  }) {
    return MetaWearablesDatPlatform.instance.startRegistration(
      appId: appId,
      urlScheme: urlScheme,
    );
  }

  /// Forwards an inbound deep-link URL to the SDK so it can complete the
  /// registration flow it started in [startRegistration].
  ///
  /// Returns `true` if the URL was recognised and consumed by the SDK on
  /// iOS. **On Android this method is a documented no-op returning `false`**
  /// because Meta's Android SDK consumes the registration callback through
  /// the host activity's intent-filter automatically; host apps still need
  /// to declare the matching intent-filter and use `singleTop` launch mode.
  /// See `doc/registration_flow.md`.
  ///
  /// Apps typically wire this to a deep-link package such as `app_links`:
  ///
  /// ```dart
  /// AppLinks().uriLinkStream.listen((uri) {
  ///   MetaWearablesDat.handleUrl(uri.toString());
  /// });
  /// ```
  static Future<bool> handleUrl(String url) {
    return MetaWearablesDatPlatform.instance.handleUrl(url);
  }

  /// Starts an unregistration flow for the currently registered device.
  static Future<void> startUnregistration() {
    return MetaWearablesDatPlatform.instance.startUnregistration();
  }

  /// Returns the current [RegistrationState].
  static Future<RegistrationState> getRegistrationState() {
    return MetaWearablesDatPlatform.instance.getRegistrationState();
  }

  /// Broadcast stream of [RegistrationState] changes.
  ///
  /// Replays the current state to every new listener, so a UI built around
  /// `StreamBuilder` does not need to call [getRegistrationState] separately.
  static Stream<RegistrationState> registrationStateStream() {
    return MetaWearablesDatPlatform.instance.registrationStateStream();
  }

  /// Broadcast stream of the currently active device, or `null` when no
  /// device is paired or the registered device disconnects.
  static Stream<DeviceInfo?> activeDeviceStream() {
    return MetaWearablesDatPlatform.instance.activeDeviceStream();
  }

  // --- Streaming ------------------------------------------------------------

  /// Starts a video stream from the active wearable and returns a Flutter
  /// `textureId` you can render with `Texture(textureId: id)`.
  ///
  /// Frames are delivered zero-copy through Flutter's texture registry
  /// (`CVPixelBuffer` on iOS, `SurfaceTexture` on Android) — they are
  /// **never** serialised through the method channel.
  ///
  /// [fps] must be one of [StreamQuality.fpsValues] (other values are
  /// clamped by Meta's SDK). [quality] picks the resolution preset.
  ///
  /// Pair with [videoStreamSizeStream] to know the frame dimensions and
  /// size your `AspectRatio` accordingly.
  ///
  /// Throws [SessionError] if the session cannot be started.
  static Future<int> startStreamSession({
    String? deviceUUID,
    int fps = 30,
    StreamQuality quality = StreamQuality.medium,
  }) {
    return MetaWearablesDatPlatform.instance.startStreamSession(
      deviceUUID: deviceUUID,
      fps: fps,
      quality: quality,
    );
  }

  /// Stops the active stream session and unregisters the texture.
  static Future<void> stopStreamSession({String? deviceUUID}) {
    return MetaWearablesDatPlatform.instance.stopStreamSession(
      deviceUUID: deviceUUID,
    );
  }

  /// Pauses the active stream session.
  ///
  /// Pauses are usually initiated by the SDK itself (thermal limits,
  /// temple hinge closed, app backgrounded). Programmatic pause is a hint;
  /// some device generations may treat it as a no-op.
  static Future<void> pauseStreamSession({String? deviceUUID}) {
    return MetaWearablesDatPlatform.instance.pauseStreamSession(
      deviceUUID: deviceUUID,
    );
  }

  /// Resumes a paused stream session.
  static Future<void> resumeStreamSession({String? deviceUUID}) {
    return MetaWearablesDatPlatform.instance.resumeStreamSession(
      deviceUUID: deviceUUID,
    );
  }

  /// Broadcast stream of [SessionState] changes.
  static Stream<SessionState> sessionStateStream() {
    return MetaWearablesDatPlatform.instance.sessionStateStream();
  }

  /// Broadcast stream of session errors raised by Meta's SDK during an
  /// active session. Events are typed [DatError] subclasses (most often
  /// [SessionError] or [CaptureError]).
  static Stream<Object> sessionErrorStream() {
    return MetaWearablesDatPlatform.instance.sessionErrorStream();
  }

  /// Broadcast stream of [VideoStreamSize] updates emitted once per
  /// resolution change. Use the latest value to drive an `AspectRatio`
  /// around the texture widget.
  static Stream<VideoStreamSize> videoStreamSizeStream() {
    return MetaWearablesDatPlatform.instance.videoStreamSizeStream();
  }

  // --- Capture --------------------------------------------------------------

  /// Captures a single frame from a live texture in pure Dart, without
  /// touching the platform channel for the pixel data.
  ///
  /// This is the recommended path for OCR / ML pipelines: keep
  /// [Texture] rendering at the requested fps, and call
  /// [captureStreamFrame] every 200-500 ms to sample. At 720x1280 each raw
  /// RGBA frame weighs ~3.7 MB, so calling this every video frame is
  /// strongly discouraged.
  static Future<FrameData?> captureStreamFrame(
    int textureId, {
    FrameFormat format = FrameFormat.rawRgba,
  }) {
    return MetaWearablesDatPlatform.instance.captureStreamFrame(
      textureId,
      format: format,
    );
  }

  /// Captures a high-resolution still mid-stream.
  ///
  /// Returns the encoded image bytes plus the actual format used (Meta's
  /// Android SDK chooses JPEG vs HEIC at the device level; on iOS [format]
  /// is honoured directly).
  ///
  /// Throws [CaptureError] if the device is disconnected, no session is
  /// active, a capture is already in progress, or the SDK reports a
  /// hardware-side capture failure.
  static Future<PhotoResult> capturePhoto({
    String? deviceUUID,
    PhotoFormat format = PhotoFormat.jpeg,
  }) {
    return MetaWearablesDatPlatform.instance.capturePhoto(
      deviceUUID: deviceUUID,
      format: format,
    );
  }

  // --- Mock Device Kit ------------------------------------------------------

  /// Enables Meta's Mock Device Kit so [pairMockRayBanMeta] and friends can
  /// be used to develop without real glasses.
  ///
  /// In v0.1.0 the mock APIs ship inside this plugin; a sibling add-on
  /// package is planned for v0.2.0 (see `doc/mock_device.md`).
  static Future<void> enableMockDevice() {
    return MetaWearablesDatPlatform.instance.enableMockDevice();
  }

  /// Disables the Mock Device Kit and unpairs all simulated devices.
  static Future<void> disableMockDevice() {
    return MetaWearablesDatPlatform.instance.disableMockDevice();
  }

  /// Pairs a simulated Ray-Ban Meta device. Returns the UUID assigned to it.
  static Future<String> pairMockRayBanMeta() {
    return MetaWearablesDatPlatform.instance.pairMockRayBanMeta();
  }

  /// Unpairs a previously-paired mock device.
  static Future<void> unpairMockDevice(String uuid) {
    return MetaWearablesDatPlatform.instance.unpairMockDevice(uuid);
  }

  /// Powers a mock device on (transitions it into a connectable state).
  static Future<void> mockPowerOn(String uuid) {
    return MetaWearablesDatPlatform.instance.mockPowerOn(uuid);
  }

  /// Marks the mock device as worn ("donned").
  static Future<void> mockDon(String uuid) {
    return MetaWearablesDatPlatform.instance.mockDon(uuid);
  }

  /// Picks which of the host phone's cameras feeds the simulated device.
  static Future<void> setMockCameraFacing(String uuid, CameraFacing facing) {
    return MetaWearablesDatPlatform.instance.setMockCameraFacing(uuid, facing);
  }

  /// Sets a video file (or content URI on Android) as the mock device's
  /// camera feed. `filePath` may be a local file path, an iOS bundle path,
  /// or an Android `content://` URI string.
  static Future<void> setMockCameraFeed(String uuid, String filePath) {
    return MetaWearablesDatPlatform.instance.setMockCameraFeed(uuid, filePath);
  }

  /// Sets a still image file as what the mock device returns from
  /// [capturePhoto] requests.
  static Future<void> setMockCapturedImage(String uuid, String filePath) {
    return MetaWearablesDatPlatform.instance.setMockCapturedImage(
      uuid,
      filePath,
    );
  }

  /// Broadcast stream of currently paired mock devices.
  static Stream<List<DeviceInfo>> mockDevicesStream() {
    return MetaWearablesDatPlatform.instance.mockDevicesStream();
  }
}
