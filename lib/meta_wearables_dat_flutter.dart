/// Unofficial Flutter plugin for Meta's Wearables Device Access Toolkit
/// (DAT) 1.0 on iOS and Android. Not affiliated with Meta Platforms, Inc.
///
/// Entry point: [MetaWearablesDat]. Experimental DAT capabilities (Inputs,
/// Motion, Speech, voice invocations, high-resolution photos and in-stream
/// audio) are marked `@experimental`: apps that use them can be built and
/// tested in Developer Mode and Beta release channels, but cannot ship to
/// production release channels.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:meta/meta.dart';
import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_platform_interface.dart';
import 'package:meta_wearables_dat_flutter/src/models/background_notification.dart';
import 'package:meta_wearables_dat_flutter/src/models/camera_facing.dart';
import 'package:meta_wearables_dat_flutter/src/models/dat_error.dart';
import 'package:meta_wearables_dat_flutter/src/models/device_compatibility.dart';
import 'package:meta_wearables_dat_flutter/src/models/device_info.dart';
import 'package:meta_wearables_dat_flutter/src/models/device_session_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/diagnostics.dart';
import 'package:meta_wearables_dat_flutter/src/models/display/display_components.dart';
import 'package:meta_wearables_dat_flutter/src/models/display/display_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/experimental/inputs.dart';
import 'package:meta_wearables_dat_flutter/src/models/experimental/motion.dart';
import 'package:meta_wearables_dat_flutter/src/models/experimental/speech.dart';
import 'package:meta_wearables_dat_flutter/src/models/experimental/voice.dart';
import 'package:meta_wearables_dat_flutter/src/models/frame_data.dart';
import 'package:meta_wearables_dat_flutter/src/models/high_res_photo.dart';
import 'package:meta_wearables_dat_flutter/src/models/mock.dart';
import 'package:meta_wearables_dat_flutter/src/models/permission.dart';
import 'package:meta_wearables_dat_flutter/src/models/photo_result.dart';
import 'package:meta_wearables_dat_flutter/src/models/registration_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/stream_config.dart';
import 'package:meta_wearables_dat_flutter/src/models/stream_quality.dart';
import 'package:meta_wearables_dat_flutter/src/models/stream_session_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/video_frame.dart';
import 'package:meta_wearables_dat_flutter/src/models/video_stream_size.dart';

export 'package:meta_wearables_dat_flutter/src/models/background_notification.dart';
export 'package:meta_wearables_dat_flutter/src/models/camera_facing.dart';
export 'package:meta_wearables_dat_flutter/src/models/dat_error.dart';
export 'package:meta_wearables_dat_flutter/src/models/device_compatibility.dart';
export 'package:meta_wearables_dat_flutter/src/models/device_info.dart';
export 'package:meta_wearables_dat_flutter/src/models/device_session_state.dart';
export 'package:meta_wearables_dat_flutter/src/models/diagnostics.dart';
export 'package:meta_wearables_dat_flutter/src/models/display/display_components.dart';
export 'package:meta_wearables_dat_flutter/src/models/display/display_icon_name.dart';
export 'package:meta_wearables_dat_flutter/src/models/display/display_playback_event.dart';
export 'package:meta_wearables_dat_flutter/src/models/display/display_state.dart';
export 'package:meta_wearables_dat_flutter/src/models/experimental/inputs.dart';
export 'package:meta_wearables_dat_flutter/src/models/experimental/motion.dart';
export 'package:meta_wearables_dat_flutter/src/models/experimental/speech.dart';
export 'package:meta_wearables_dat_flutter/src/models/experimental/voice.dart';
export 'package:meta_wearables_dat_flutter/src/models/frame_data.dart';
export 'package:meta_wearables_dat_flutter/src/models/high_res_photo.dart';
export 'package:meta_wearables_dat_flutter/src/models/mock.dart';
// ignore: deprecated_member_use_from_same_package
export 'package:meta_wearables_dat_flutter/src/models/mock_permission.dart';
export 'package:meta_wearables_dat_flutter/src/models/permission.dart';
export 'package:meta_wearables_dat_flutter/src/models/photo_result.dart';
export 'package:meta_wearables_dat_flutter/src/models/registration_state.dart';
export 'package:meta_wearables_dat_flutter/src/models/stream_config.dart';
export 'package:meta_wearables_dat_flutter/src/models/stream_quality.dart';
export 'package:meta_wearables_dat_flutter/src/models/stream_session_state.dart';
export 'package:meta_wearables_dat_flutter/src/models/video_frame.dart';
export 'package:meta_wearables_dat_flutter/src/models/video_stream_size.dart';

/// Static facade for the plugin.
///
/// Typical order (see `doc/getting_started.md`):
///
/// 1. [requestAndroidPermissions] (Android; returns `true` on iOS).
/// 2. [startRegistration] once; watch [registrationStateStream].
/// 3. [requestPermission] for [Permission.camera].
/// 4. [startStreamSession] returns a texture id for `Texture(textureId:)`.
/// 5. [stopStreamSession] when done.
///
/// Every failure is a [DatError] subclass. Camera, display and the
/// experimental capabilities share one device session, which stays open
/// while any of them runs.
abstract final class MetaWearablesDat {
  static MetaWearablesDatPlatform get _p => MetaWearablesDatPlatform.instance;

  // --- Platform & diagnostics -----------------------------------------------------

  /// The host OS name and version.
  static Future<String?> getPlatformVersion() => _p.getPlatformVersion();

  /// Configuration problems, versions, devices and held resources.
  ///
  /// Check [DatDiagnostics.errors] during development: they list missing
  /// Info.plist keys, manifest entries and permissions.
  static Future<DatDiagnostics> dumpDiagnostics() => _p.dumpDiagnostics();

  /// Android: requests `BLUETOOTH_CONNECT` and initialises the DAT SDK.
  /// Returns `true` when granted. iOS: returns `true`.
  ///
  /// Android initialises the SDK automatically at launch once the
  /// permission was granted before, so this is only needed until then.
  static Future<bool> requestAndroidPermissions() =>
      _p.requestAndroidPermissions();

  // --- Registration ------------------------------------------------------------------

  /// Opens the Meta AI app to register this app. The result arrives on
  /// [registrationStateStream] (and errors on [registrationErrorStream]).
  ///
  /// Throws a [RegistrationError].
  static Future<void> startRegistration() => _p.startRegistration();

  /// Unregisters this app. Stops any running session first.
  ///
  /// Throws an [UnregistrationError].
  static Future<void> startUnregistration() => _p.startUnregistration();

  /// Forwards a callback URL to the SDK. The plugin already forwards Meta
  /// AI callbacks automatically (iOS app delegate, Android intents); call
  /// this only for URLs your app receives another way. Returns whether the
  /// SDK consumed it.
  static Future<bool> handleUrl(String url) => _p.handleUrl(url);

  /// The current registration state.
  static Future<RegistrationState> getRegistrationState() =>
      _p.getRegistrationState();

  /// Registration state changes; emits the current state first.
  static Stream<RegistrationState> registrationStateStream() =>
      _p.registrationStateStream();

  /// Registration and unregistration failures reported asynchronously.
  static Stream<DatError> registrationErrorStream() =>
      _p.registrationErrorStream();

  /// Registrations started from the Meta AI app (DAT 1.0). Answer each with
  /// [RegistrationRequest.continueRegistration] or [RegistrationRequest.cancel].
  static Stream<RegistrationRequest> registrationRequestStream() =>
      _p.registrationRequestStream();

  // --- Permissions & Meta AI navigation ---------------------------------------------

  /// Asks the user (in the Meta AI app) to grant [permission].
  ///
  /// Android requires `MainActivity` to extend `FlutterFragmentActivity`.
  /// Throws a [PermissionError].
  static Future<PermissionStatus> requestPermission(Permission permission) =>
      _p.requestPermission(permission);

  /// The current status of [permission], without prompting.
  static Future<PermissionStatus> checkPermissionStatus(
    Permission permission,
  ) => _p.checkPermissionStatus(permission);

  /// Requests the camera permission. Returns whether it was granted.
  @Deprecated('Use requestPermission(Permission.camera)')
  static Future<bool> requestCameraPermission() async =>
      (await requestPermission(Permission.camera)).isGranted;

  /// Whether the camera permission is granted.
  @Deprecated('Use checkPermissionStatus(Permission.camera)')
  static Future<bool> getCameraPermissionStatus() async =>
      (await checkPermissionStatus(Permission.camera)).isGranted;

  /// Opens the Meta AI app's firmware update screen, for
  /// [DeviceCompatibility.deviceUpdateRequired]. Throws a [NavigationError].
  static Future<void> openFirmwareUpdate() => _p.openFirmwareUpdate();

  /// Opens the Meta AI app to update the DAT app on the glasses, for
  /// [DeviceSessionErrorCase.datAppOnTheGlassesUpdateRequired]. Throws a
  /// [NavigationError].
  static Future<void> openDatGlassesAppUpdate() => _p.openDatGlassesAppUpdate();

  // --- Devices ---------------------------------------------------------------------------

  /// Every paired device with its current state.
  static Future<List<DeviceInfo>> getDevices() => _p.getDevices();

  /// One paired device, or `null` when it is not paired.
  static Future<DeviceInfo?> getDevice(String deviceUuid) =>
      _p.getDevice(deviceUuid);

  /// The device of the open session, or `null` when no session is open.
  static Future<DeviceInfo?> getSessionDevice() => _p.getSessionDevice();

  /// Paired devices; emits the full list on every change, including state
  /// changes such as battery or wear.
  static Stream<List<DeviceInfo>> devicesStream() => _p.devicesStream();

  /// Live state (battery, charging, wear, hinge, thermal, link) of
  /// [deviceUuid]. Emits the current snapshot first.
  static Stream<DeviceInfo> deviceStateStream(String deviceUuid) {
    // A plain controller instead of `async*`: teardown must not await
    // anything, because `first`/`firstWhere` wait for cancel to finish.
    late final StreamController<DeviceInfo> controller;
    // Cancelled in onCancel.
    // ignore: cancel_subscriptions
    StreamSubscription<DeviceInfo>? changes;
    controller = StreamController<DeviceInfo>(
      onListen: () {
        // Live updates that arrive before the snapshot are held back so the
        // snapshot never overwrites a newer value.
        List<DeviceInfo>? pending = [];
        changes = _p
            .deviceStateChanges()
            .where((d) => d.uuid == deviceUuid)
            .listen(
              (d) => pending != null ? pending!.add(d) : controller.add(d),
              onError: controller.addError,
            );
        _p
            .getDevice(deviceUuid)
            .then(
              (current) {
                if (controller.isClosed) return;
                final held = pending!;
                pending = null;
                if (current != null && held.isEmpty) controller.add(current);
                held.forEach(controller.add);
              },
              onError: (Object error, StackTrace stack) {
                if (controller.isClosed) return;
                final held = pending ?? const <DeviceInfo>[];
                pending = null;
                controller.addError(error, stack);
                held.forEach(controller.add);
              },
            );
      },
      onPause: () => changes?.pause(),
      onResume: () => changes?.resume(),
      onCancel: () {
        final sub = changes;
        changes = null;
        unawaited(sub?.cancel());
      },
    );
    return controller.stream;
  }

  /// The device the SDK would pick automatically, or `null`.
  static Stream<DeviceInfo?> activeDeviceStream() => _p.activeDeviceStream();

  /// Compatibility verdicts per device.
  static Stream<DeviceCompatibilityEvent> compatibilityStream() =>
      _p.compatibilityStream();

  /// State of the shared device session.
  static Stream<DeviceSessionState> deviceSessionStateStream() =>
      _p.deviceSessionStateStream();

  /// Device session errors. Check [DeviceSessionError.isTerminal],
  /// [DeviceSessionError.isWarning] and [DatError.recoveryAction].
  static Stream<DeviceSessionError> deviceSessionErrorStream() =>
      _p.deviceSessionErrorStream();

  // --- Camera ---------------------------------------------------------------------------

  /// Starts the camera and returns a Flutter texture id for
  /// `Texture(textureId: id)`.
  ///
  /// Pass [config] (preferred) or the individual named arguments. Picks the
  /// best connected, worn device unless [deviceUUID] is given. Throws a
  /// [DeviceSessionError], [StreamError] or [DatArgumentError].
  static Future<int> startStreamSession({
    String? deviceUUID,
    StreamSessionConfig? config,
    @Deprecated('Use config: StreamSessionConfig(frameRate: ...)') int? fps,
    @Deprecated('Use config: StreamSessionConfig(quality: ...)')
    StreamQuality? quality,
    @Deprecated('Use config: StreamSessionConfig(videoCodec: ...)')
    VideoCodec? videoCodec,
    @Deprecated('Use config: StreamSessionConfig(deviceKinds: ...)')
    Set<DeviceKind>? deviceKinds,
  }) {
    var effective = config ?? const StreamSessionConfig();
    if (config == null &&
        (fps != null ||
            quality != null ||
            videoCodec != null ||
            deviceKinds != null)) {
      final rate = fps == null
          ? effective.frameRate
          : StreamFrameRate.values.where((r) => r.value == fps).firstOrNull;
      if (rate == null) {
        throw DatArgumentError(
          message: 'fps must be one of 2, 7, 15, 24, 30 (got $fps).',
        );
      }
      effective = StreamSessionConfig(
        frameRate: rate,
        quality: quality ?? effective.quality,
        videoCodec: videoCodec ?? effective.videoCodec,
        deviceKinds: deviceKinds,
      );
    }
    return _p.startStreamSession(effective, deviceUuid: deviceUUID);
  }

  /// Stops the camera, releases the texture and closes the session when
  /// nothing else uses it.
  static Future<void> stopStreamSession() => _p.stopStreamSession();

  /// Camera stream state; emits the current state first.
  static Stream<StreamSessionState> streamSessionStateStream() =>
      _p.streamSessionStateStream();

  /// Camera stream errors and warnings ([StreamError.isWarning]).
  static Stream<StreamError> streamErrorStream() => _p.streamErrorStream();

  /// Former name of [streamErrorStream].
  @Deprecated('Use streamErrorStream')
  static Stream<Object> streamSessionErrorStream() => streamErrorStream();

  /// State of the camera capability.
  static Stream<CameraState> cameraStateStream() => _p.cameraStateStream();

  /// Frame size; emits when it changes (the SDK lowers resolution under poor
  /// bandwidth).
  static Stream<VideoStreamSize> videoStreamSizeStream() =>
      _p.videoStreamSizeStream();

  /// Opt-in per-frame data. Costs a copy of every frame (up to 3.7 MB at
  /// 720p); nothing is produced while nobody listens. See
  /// `doc/frame_processing.md`.
  static Stream<VideoFrame> videoFramesStream() => _p.videoFramesStream();

  /// Experimental PCM audio, when the stream was started with
  /// [StreamSessionConfig.audio].
  ///
  /// **Experimental:** cannot be used in apps on production release channels.
  @experimental
  static Stream<AudioFrame> audioFramesStream() => _p.audioFramesStream();

  /// Captures a photo from the running stream. Throws a [CaptureError].
  static Future<PhotoResult> capturePhoto({
    PhotoFormat format = PhotoFormat.jpeg,
  }) => _p.capturePhoto(format: format);

  /// Captures an experimental high-resolution photo (up to 4032 x 3024)
  /// while the stream runs. Throws a [PhotoError].
  ///
  /// **Experimental:** cannot be used in apps on production release channels.
  @experimental
  static Future<HighResPhoto> captureHighResPhoto({
    PhotoResolution resolution = PhotoResolution.medium,
    PhotoQuality quality = PhotoQuality.medium,
  }) => _p.captureHighResPhoto(resolution: resolution, quality: quality);

  /// Transfer progress of [captureHighResPhoto].
  @experimental
  static Stream<PhotoTransferProgress> photoTransferProgressStream() =>
      _p.photoTransferProgressStream();

  /// State of the high-resolution photo capability.
  @experimental
  static Stream<PhotoState> photoStateStream() => _p.photoStateStream();

  /// Errors of the high-resolution photo capability.
  @experimental
  static Stream<PhotoError> photoErrorStream() => _p.photoErrorStream();

  /// Renders the current texture frame into an image, without native
  /// round-trips. Returns `null` when no frame size is known yet.
  static Future<FrameData?> captureStreamFrame(
    int textureId, {
    FrameFormat format = FrameFormat.rawRgba,
  }) async {
    VideoStreamSize size;
    try {
      size = await videoStreamSizeStream().first.timeout(
        const Duration(seconds: 1),
      );
    } on TimeoutException {
      return null;
    }
    if (size.width <= 0 || size.height <= 0) return null;
    ui.Scene? scene;
    ui.Image? image;
    try {
      final builder = ui.SceneBuilder()
        ..pushOffset(0, 0)
        ..addTexture(
          textureId,
          width: size.width.toDouble(),
          height: size.height.toDouble(),
        )
        ..pop();
      scene = builder.build();
      image = await scene.toImage(size.width, size.height);
      final byteData = await image.toByteData(
        format: switch (format) {
          FrameFormat.png => ui.ImageByteFormat.png,
          FrameFormat.rawStraightRgba => ui.ImageByteFormat.rawStraightRgba,
          FrameFormat.rawRgba => ui.ImageByteFormat.rawRgba,
        },
      );
      if (byteData == null) {
        throw const CaptureError(
          reason: CaptureErrorCase.captureFailed,
          message: 'toByteData returned null',
        );
      }
      return FrameData(
        bytes: byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
        width: size.width,
        height: size.height,
        format: format,
      );
    } finally {
      image?.dispose();
      scene?.dispose();
    }
  }

  /// Keeps the stream running in the background. Android starts a
  /// foreground service (pass [androidNotification]; request
  /// `POST_NOTIFICATIONS` first on Android 13+). iOS keeps an audio session
  /// alive; use [VideoCodec.hvc1], since raw frames pause in the background.
  static Future<void> enableBackgroundStreaming({
    BackgroundNotification? androidNotification,
  }) => _p.enableBackgroundStreaming(androidNotification: androidNotification);

  /// Stops background streaming.
  static Future<void> disableBackgroundStreaming() =>
      _p.disableBackgroundStreaming();

  // --- Display -----------------------------------------------------------------------------

  /// Starts the display on Meta Ray-Ban Display glasses. Throws a
  /// [DeviceSessionError] or [DisplayError].
  static Future<void> startDisplaySession({String? deviceUUID}) =>
      _p.startDisplaySession(deviceUuid: deviceUUID);

  /// Replaces the view on the glasses. Returns warnings for values the SDK
  /// does not support (they are substituted, not fatal). Throws a
  /// [DatArgumentError] for invalid trees, or a [DisplayError].
  static Future<List<String>> sendDisplayView(DisplayView view) =>
      _p.sendDisplayView(view);

  /// Clears the display.
  static Future<void> clearDisplay() => _p.clearDisplay();

  /// Stops the video on screen.
  static Future<void> stopDisplayVideo() => _p.stopDisplayVideo();

  /// Stops the display and closes the session when nothing else uses it.
  static Future<void> stopDisplaySession() => _p.stopDisplaySession();

  /// Display state; emits the current state first. `stopped` also follows
  /// the user pressing Back on the glasses.
  static Stream<DisplayState> displayStateStream() => _p.displayStateStream();

  /// Display and video playback errors.
  static Stream<DisplayError> displayErrorStream() => _p.displayErrorStream();

  /// Warnings for view values the SDK does not support.
  static Stream<String> displayWarningStream() => _p.displayWarningStream();

  // --- Experimental: Inputs ----------------------------------------------------------------------

  /// Starts receiving touchpad, button and Meta Neural Band input.
  ///
  /// **Experimental:** cannot be used in apps on production release channels.
  /// Inputs must be approved for the app in Wearables Developer Center.
  @experimental
  static Future<void> startInputs({
    InputsConfiguration configuration = const InputsConfiguration(),
    String? deviceUUID,
  }) => _p.startInputs(configuration, deviceUuid: deviceUUID);

  /// Stops input events.
  @experimental
  static Future<void> stopInputs() => _p.stopInputs();

  /// Input events.
  @experimental
  static Stream<InputEvent> inputEventsStream() => _p.inputEventsStream();

  /// Inputs state.
  @experimental
  static Stream<InputsState> inputsStateStream() => _p.inputsStateStream();

  /// Inputs errors. Every error ends the event stream.
  @experimental
  static Stream<InputsError> inputsErrorStream() => _p.inputsErrorStream();

  // --- Experimental: Motion ------------------------------------------------------------------------

  /// Starts head motion samples.
  ///
  /// **Experimental:** cannot be used in apps on production release channels.
  @experimental
  static Future<void> startMotion({
    MotionSamplingRate samplingRate = MotionSamplingRate.hz10,
    String? deviceUUID,
  }) => _p.startMotion(samplingRate, deviceUuid: deviceUUID);

  /// Stops motion samples.
  @experimental
  static Future<void> stopMotion() => _p.stopMotion();

  /// Motion samples; produced only while listened to.
  @experimental
  static Stream<MotionSample> motionSamplesStream() => _p.motionSamplesStream();

  /// Motion state.
  @experimental
  static Stream<MotionState> motionStateStream() => _p.motionStateStream();

  /// Motion errors.
  @experimental
  static Stream<MotionError> motionErrorStream() => _p.motionErrorStream();

  // --- Experimental: Speech ------------------------------------------------------------------------

  /// Starts on-device transcription from the glasses microphone. Requires
  /// [Permission.microphone].
  ///
  /// **Experimental:** cannot be used in apps on production release channels.
  @experimental
  static Future<void> startSpeech({String? deviceUUID}) =>
      _p.startSpeech(deviceUuid: deviceUUID);

  /// Stops transcription.
  @experimental
  static Future<void> stopSpeech() => _p.stopSpeech();

  /// Transcriptions.
  @experimental
  static Stream<TranscriptionResult> transcriptionStream() =>
      _p.transcriptionStream();

  /// Speech state.
  @experimental
  static Stream<SpeechState> speechStateStream() => _p.speechStateStream();

  /// Speech errors.
  @experimental
  static Stream<SpeechError> speechErrorStream() => _p.speechErrorStream();

  // --- Experimental: voice invocations ----------------------------------------------------------------

  /// Starts listening for "Hey Meta" requests directed at this app.
  ///
  /// **Experimental:** cannot be used in apps on production release channels.
  /// Needs the Voice Invocation permission approved in Wearables Developer
  /// Center.
  @experimental
  static Future<void> startVoiceInvocations({String? deviceUUID}) =>
      _p.startVoiceInvocations(deviceUuid: deviceUUID);

  /// Stops voice invocations; unanswered ones are failed.
  @experimental
  static Future<void> stopVoiceInvocations() => _p.stopVoiceInvocations();

  /// Voice invocations. Answer each exactly once.
  @experimental
  static Stream<VoiceInvocation> voiceInvocationsStream() =>
      _p.voiceInvocationsStream();

  /// Voice invocations stream state.
  @experimental
  static Stream<VoiceInvocationsState> voiceInvocationsStateStream() =>
      _p.voiceInvocationsStateStream();

  /// Voice invocation errors.
  @experimental
  static Stream<VoiceInvocationError> voiceInvocationErrorStream() =>
      _p.voiceInvocationErrorStream();

  // --- Mock Device Kit -------------------------------------------------------------------------------

  /// Enables simulated glasses for development and tests. Disable before
  /// shipping.
  static Future<void> enableMockDevice({
    bool initiallyRegistered = true,
    bool initialPermissionsGranted = true,
  }) => _p.enableMockDevice(
    initiallyRegistered: initiallyRegistered,
    initialPermissionsGranted: initialPermissionsGranted,
  );

  /// Disables simulated glasses and stops any session.
  static Future<void> disableMockDevice() => _p.disableMockDevice();

  /// Whether Mock Device Kit is enabled.
  static Future<bool> isMockDeviceEnabled() => _p.isMockDeviceEnabled();

  /// Pairs simulated glasses. They appear in [devicesStream] after
  /// [mockPowerOn] and [mockUnfold].
  static Future<DeviceInfo> pairMockGlasses([
    MockGlassesModel model = MockGlassesModel.rayBanMeta,
  ]) => _p.pairMockGlasses(model);

  /// Pairs simulated Ray-Ban Meta glasses and returns their id.
  @Deprecated('Use pairMockGlasses(MockGlassesModel.rayBanMeta)')
  static Future<String> pairMockRayBanMeta() async =>
      (await pairMockGlasses()).uuid;

  /// Paired simulated devices.
  static Future<List<DeviceInfo>> pairedMockDevices() => _p.pairedMockDevices();

  /// Unpairs a simulated device.
  static Future<void> unpairMockDevice(String uuid) =>
      _p.unpairMockDevice(uuid);

  /// Paired simulated devices; emits on every change.
  static Stream<List<DeviceInfo>> mockDevicesStream() => _p.mockDevicesStream();

  /// Powers the simulated glasses on.
  static Future<void> mockPowerOn(String uuid) =>
      _p.mockAction('mockPowerOn', uuid);

  /// Powers the simulated glasses off.
  static Future<void> mockPowerOff(String uuid) =>
      _p.mockAction('mockPowerOff', uuid);

  /// Puts the simulated glasses on.
  static Future<void> mockDon(String uuid) => _p.mockAction('mockDon', uuid);

  /// Takes the simulated glasses off.
  static Future<void> mockDoff(String uuid) => _p.mockAction('mockDoff', uuid);

  /// Folds the simulated glasses (ends sessions).
  static Future<void> mockFold(String uuid) => _p.mockAction('mockFold', uuid);

  /// Unfolds the simulated glasses.
  static Future<void> mockUnfold(String uuid) =>
      _p.mockAction('mockUnfold', uuid);

  /// Simulates a touchpad tap (pauses or resumes the stream).
  static Future<void> mockTap(String uuid) =>
      _p.mockAction('mockCaptouchTap', uuid);

  /// Simulates a touchpad tap-and-hold.
  static Future<void> mockTapAndHold(String uuid) =>
      _p.mockAction('mockCaptouchTapAndHold', uuid);

  /// Sets the simulated battery level (0-100, `null` for unknown).
  static Future<void> setMockBatteryLevel(String uuid, int? level) {
    if (level != null && (level < 0 || level > 100)) {
      throw DatArgumentError(
        message: 'Battery level must be between 0 and 100 (got $level).',
      );
    }
    return _p.setMockBatteryLevel(uuid, level);
  }

  /// Sets the simulated charging state.
  static Future<void> setMockChargingState(String uuid, ChargingState state) =>
      _p.setMockChargingState(uuid, state);

  /// Sets the simulated thermal level.
  static Future<void> setMockThermalLevel(String uuid, ThermalLevel level) =>
      _p.setMockThermalLevel(uuid, level);

  /// Streams the phone camera as the simulated glasses camera (needs the
  /// host app's camera permission).
  static Future<void> setMockCameraFacing(String uuid, CameraFacing facing) =>
      _p.setMockCameraFacing(uuid, facing);

  /// Streams an H.265 video file as the simulated glasses camera.
  static Future<void> setMockCameraFeed(String uuid, String filePath) =>
      _p.setMockFile('setMockCameraFeed', uuid, filePath);

  /// Sets the image [capturePhoto] returns.
  static Future<void> setMockCapturedImage(String uuid, String filePath) =>
      _p.setMockFile('setMockCapturedImage', uuid, filePath);

  /// Sets the image [captureHighResPhoto] returns.
  @experimental
  static Future<void> setMockCapturedPhoto(String uuid, String filePath) =>
      _p.setMockFile('setMockCapturedPhoto', uuid, filePath);

  /// Makes the next [captureHighResPhoto] fail.
  @experimental
  static Future<void> simulateMockCaptureFailure(String uuid) =>
      _p.simulateMockCaptureFailure(uuid);

  /// Sets a simulated permission status.
  static Future<void> setMockPermission(
    Permission permission,
    PermissionStatus status,
  ) => _p.setMockPermission(permission, status, requestResult: false);

  /// Sets the result the next [requestPermission] call returns.
  static Future<void> setMockPermissionRequestResult(
    Permission permission,
    PermissionStatus status,
  ) => _p.setMockPermission(permission, status, requestResult: true);

  /// Simulates a navigation input.
  @experimental
  static Future<void> mockInputNav(
    String uuid,
    NavDirection direction, {
    InputSource source = InputSource.captouch,
  }) {
    final action = switch (direction) {
      NavDirection.up => 'navUp',
      NavDirection.down => 'navDown',
      NavDirection.left => 'navLeft',
      NavDirection.right || NavDirection.unknown => 'navRight',
    };
    return _p.mockInput(uuid, {'action': action, 'source': source.name});
  }

  /// Simulates a select input.
  @experimental
  static Future<void> mockInputSelect(
    String uuid, {
    InputSource source = InputSource.captouch,
  }) => _p.mockInput(uuid, {'action': 'select', 'source': source.name});

  /// Simulates a back input.
  @experimental
  static Future<void> mockInputBack(
    String uuid, {
    InputSource source = InputSource.captouch,
  }) => _p.mockInput(uuid, {'action': 'back', 'source': source.name});

  /// Simulates a capture-button press.
  @experimental
  static Future<void> mockInputCapture(
    String uuid, {
    CapturePressType pressType = CapturePressType.shortPress,
  }) => _p.mockInput(uuid, {'action': 'capture', 'pressType': pressType.name});

  /// Simulates an action-button press.
  @experimental
  static Future<void> mockInputButton(String uuid) =>
      _p.mockInput(uuid, {'action': 'button'});

  /// Simulates a Meta Neural Band drag.
  @experimental
  static Future<void> mockInputDrag(
    String uuid, {
    required DragAction action,
    double x = 0,
    double y = 0,
    double dx = 0,
    double dy = 0,
  }) => _p.mockInput(uuid, {
    'action': 'drag',
    'dragAction': action.name,
    'x': x,
    'y': y,
    'dx': dx,
    'dy': dy,
  });

  /// Selects where simulated transcriptions come from.
  @experimental
  static Future<void> setMockSpeechSource(
    String uuid,
    MockSpeechSource source,
  ) => _p.mockSpeech(uuid, {'action': 'source', 'source': source.name});

  /// Emits a simulated transcription.
  @experimental
  static Future<void> simulateMockTranscription(
    String uuid,
    String text, {
    bool isFinal = true,
    double confidence = 1,
  }) => _p.mockSpeech(uuid, {
    'action': 'transcription',
    'text': text,
    'isFinal': isFinal,
    'confidence': confidence,
  });

  /// Emits a simulated speech error.
  @experimental
  static Future<void> simulateMockSpeechError(
    String uuid, {
    int errorCode = 0,
    String message = '',
  }) => _p.mockSpeech(uuid, {
    'action': 'error',
    'errorCode': errorCode,
    'message': message,
  });

  /// Ends the simulated speech session.
  @experimental
  static Future<void> simulateMockSpeechCompletion(String uuid) =>
      _p.mockSpeech(uuid, {'action': 'completion'});

  /// Feeds simulated motion samples (or a CSV [filePath]).
  @experimental
  static Future<void> setMockMotionFeed(
    String uuid, {
    List<MotionSample>? samples,
    String? filePath,
    bool loop = true,
  }) => _p.setMockMotionFeed(
    uuid,
    samples: samples,
    filePath: filePath,
    loop: loop,
  );

  /// Sends a simulated "Hey Meta, open `app`" request. Returns the mock's
  /// action id, if any.
  @experimental
  static Future<String?> simulateMockVoiceInvocation(
    String uuid, {
    bool incomplete = false,
  }) => _p.simulateMockVoiceInvocation(uuid, incomplete: incomplete);

  /// Starts the mock test server. With the Chrome "Meta Ray-Ban Display
  /// Simulator" extension open `http://127.0.0.1:<port>/` to preview the
  /// display (iOS Simulator only; Android needs `adb forward tcp:<port> tcp:<port>`).
  static Future<int> startMockTestServer({int port = 9000}) =>
      _p.startMockTestServer(port: port);

  /// Stops the mock test server.
  static Future<void> stopMockTestServer() => _p.stopMockTestServer();

  /// Clicks a clickable display component of simulated display glasses.
  /// The SDK numbers clickable components (`'0'`, `'1'`, ...) in the order
  /// the view builds them. Returns whether a component was clicked.
  static Future<bool> sendMockDisplayClick(String uuid, String identifier) =>
      _p.sendMockDisplayClick(uuid, identifier);
}
