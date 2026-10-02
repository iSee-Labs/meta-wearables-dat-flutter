import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_method_channel.dart';
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
import 'package:meta_wearables_dat_flutter/src/models/high_res_photo.dart';
import 'package:meta_wearables_dat_flutter/src/models/mock.dart';
import 'package:meta_wearables_dat_flutter/src/models/permission.dart';
import 'package:meta_wearables_dat_flutter/src/models/photo_result.dart';
import 'package:meta_wearables_dat_flutter/src/models/registration_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/stream_config.dart';
import 'package:meta_wearables_dat_flutter/src/models/stream_session_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/video_frame.dart';
import 'package:meta_wearables_dat_flutter/src/models/video_stream_size.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface platform implementations of `meta_wearables_dat_flutter`
/// extend. Apps use the `MetaWearablesDat` facade instead.
///
/// New methods are added with an [UnimplementedError] default so existing
/// implementations keep compiling.
abstract class MetaWearablesDatPlatform extends PlatformInterface {
  /// Constructs a [MetaWearablesDatPlatform].
  MetaWearablesDatPlatform() : super(token: _token);

  static final Object _token = Object();

  static MetaWearablesDatPlatform _instance = MethodChannelMetaWearablesDat();

  /// The active implementation ([MethodChannelMetaWearablesDat] by default).
  static MetaWearablesDatPlatform get instance => _instance;

  /// Replaces the active implementation (tests, custom platforms).
  static set instance(MetaWearablesDatPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Never _unimplemented(String name) =>
      throw UnimplementedError('$name() has not been implemented.');

  // --- Platform & diagnostics ---------------------------------------------------

  /// See `MetaWearablesDat.getPlatformVersion`.
  Future<String?> getPlatformVersion() => _unimplemented('getPlatformVersion');

  /// See `MetaWearablesDat.dumpDiagnostics`.
  Future<DatDiagnostics> dumpDiagnostics() => _unimplemented('dumpDiagnostics');

  /// See `MetaWearablesDat.requestAndroidPermissions`.
  Future<bool> requestAndroidPermissions() =>
      _unimplemented('requestAndroidPermissions');

  // --- Registration ---------------------------------------------------------------

  /// See `MetaWearablesDat.startRegistration`.
  Future<void> startRegistration() => _unimplemented('startRegistration');

  /// See `MetaWearablesDat.startUnregistration`.
  Future<void> startUnregistration() => _unimplemented('startUnregistration');

  /// See `MetaWearablesDat.handleUrl`.
  Future<bool> handleUrl(String url) => _unimplemented('handleUrl');

  /// See `MetaWearablesDat.getRegistrationState`.
  Future<RegistrationState> getRegistrationState() =>
      _unimplemented('getRegistrationState');

  /// See `MetaWearablesDat.registrationStateStream`.
  Stream<RegistrationState> registrationStateStream() =>
      _unimplemented('registrationStateStream');

  /// See `MetaWearablesDat.registrationErrorStream`.
  Stream<DatError> registrationErrorStream() =>
      _unimplemented('registrationErrorStream');

  /// See `MetaWearablesDat.registrationRequestStream`.
  Stream<RegistrationRequest> registrationRequestStream() =>
      _unimplemented('registrationRequestStream');

  /// Answers a Meta AI-initiated registration request.
  Future<void> answerRegistrationRequest(
    String requestId, {
    required bool accept,
  }) => _unimplemented('answerRegistrationRequest');

  // --- Permissions & navigation -------------------------------------------------

  /// See `MetaWearablesDat.requestPermission`.
  Future<PermissionStatus> requestPermission(Permission permission) =>
      _unimplemented('requestPermission');

  /// See `MetaWearablesDat.checkPermissionStatus`.
  Future<PermissionStatus> checkPermissionStatus(Permission permission) =>
      _unimplemented('checkPermissionStatus');

  /// See `MetaWearablesDat.openFirmwareUpdate`.
  Future<void> openFirmwareUpdate() => _unimplemented('openFirmwareUpdate');

  /// See `MetaWearablesDat.openDatGlassesAppUpdate`.
  Future<void> openDatGlassesAppUpdate() =>
      _unimplemented('openDatGlassesAppUpdate');

  // --- Devices --------------------------------------------------------------------

  /// See `MetaWearablesDat.getDevices`.
  Future<List<DeviceInfo>> getDevices() => _unimplemented('getDevices');

  /// See `MetaWearablesDat.getDevice`.
  Future<DeviceInfo?> getDevice(String deviceUuid) =>
      _unimplemented('getDevice');

  /// See `MetaWearablesDat.getSessionDevice`.
  Future<DeviceInfo?> getSessionDevice() => _unimplemented('getSessionDevice');

  /// See `MetaWearablesDat.devicesStream`.
  Stream<List<DeviceInfo>> devicesStream() => _unimplemented('devicesStream');

  /// Every device-state change for every paired device.
  Stream<DeviceInfo> deviceStateChanges() =>
      _unimplemented('deviceStateChanges');

  /// See `MetaWearablesDat.activeDeviceStream`.
  Stream<DeviceInfo?> activeDeviceStream() =>
      _unimplemented('activeDeviceStream');

  /// See `MetaWearablesDat.compatibilityStream`.
  Stream<DeviceCompatibilityEvent> compatibilityStream() =>
      _unimplemented('compatibilityStream');

  /// See `MetaWearablesDat.deviceSessionStateStream`.
  Stream<DeviceSessionState> deviceSessionStateStream() =>
      _unimplemented('deviceSessionStateStream');

  /// See `MetaWearablesDat.deviceSessionErrorStream`.
  Stream<DeviceSessionError> deviceSessionErrorStream() =>
      _unimplemented('deviceSessionErrorStream');

  // --- Camera ---------------------------------------------------------------------

  /// See `MetaWearablesDat.startStreamSession`.
  Future<int> startStreamSession(
    StreamSessionConfig config, {
    String? deviceUuid,
  }) => _unimplemented('startStreamSession');

  /// See `MetaWearablesDat.stopStreamSession`.
  Future<void> stopStreamSession() => _unimplemented('stopStreamSession');

  /// See `MetaWearablesDat.streamSessionStateStream`.
  Stream<StreamSessionState> streamSessionStateStream() =>
      _unimplemented('streamSessionStateStream');

  /// See `MetaWearablesDat.streamErrorStream`.
  Stream<StreamError> streamErrorStream() =>
      _unimplemented('streamErrorStream');

  /// See `MetaWearablesDat.cameraStateStream`.
  Stream<CameraState> cameraStateStream() =>
      _unimplemented('cameraStateStream');

  /// See `MetaWearablesDat.videoStreamSizeStream`.
  Stream<VideoStreamSize> videoStreamSizeStream() =>
      _unimplemented('videoStreamSizeStream');

  /// See `MetaWearablesDat.videoFramesStream`.
  Stream<VideoFrame> videoFramesStream() => _unimplemented('videoFramesStream');

  /// See `MetaWearablesDat.audioFramesStream`.
  Stream<AudioFrame> audioFramesStream() => _unimplemented('audioFramesStream');

  /// See `MetaWearablesDat.capturePhoto`.
  Future<PhotoResult> capturePhoto({PhotoFormat format = PhotoFormat.jpeg}) =>
      _unimplemented('capturePhoto');

  /// See `MetaWearablesDat.captureHighResPhoto`.
  Future<HighResPhoto> captureHighResPhoto({
    required PhotoResolution resolution,
    required PhotoQuality quality,
  }) => _unimplemented('captureHighResPhoto');

  /// See `MetaWearablesDat.photoTransferProgressStream`.
  Stream<PhotoTransferProgress> photoTransferProgressStream() =>
      _unimplemented('photoTransferProgressStream');

  /// See `MetaWearablesDat.photoStateStream`.
  Stream<PhotoState> photoStateStream() => _unimplemented('photoStateStream');

  /// See `MetaWearablesDat.photoErrorStream`.
  Stream<PhotoError> photoErrorStream() => _unimplemented('photoErrorStream');

  /// See `MetaWearablesDat.enableBackgroundStreaming`.
  Future<void> enableBackgroundStreaming({
    BackgroundNotification? androidNotification,
  }) => _unimplemented('enableBackgroundStreaming');

  /// See `MetaWearablesDat.disableBackgroundStreaming`.
  Future<void> disableBackgroundStreaming() =>
      _unimplemented('disableBackgroundStreaming');

  // --- Display --------------------------------------------------------------------

  /// See `MetaWearablesDat.startDisplaySession`.
  Future<void> startDisplaySession({String? deviceUuid}) =>
      _unimplemented('startDisplaySession');

  /// See `MetaWearablesDat.sendDisplayView`.
  Future<List<String>> sendDisplayView(DisplayView view) =>
      _unimplemented('sendDisplayView');

  /// See `MetaWearablesDat.clearDisplay`.
  Future<void> clearDisplay() => _unimplemented('clearDisplay');

  /// See `MetaWearablesDat.stopDisplayVideo`.
  Future<void> stopDisplayVideo() => _unimplemented('stopDisplayVideo');

  /// See `MetaWearablesDat.stopDisplaySession`.
  Future<void> stopDisplaySession() => _unimplemented('stopDisplaySession');

  /// See `MetaWearablesDat.displayStateStream`.
  Stream<DisplayState> displayStateStream() =>
      _unimplemented('displayStateStream');

  /// See `MetaWearablesDat.displayErrorStream`.
  Stream<DisplayError> displayErrorStream() =>
      _unimplemented('displayErrorStream');

  /// See `MetaWearablesDat.displayWarningStream`.
  Stream<String> displayWarningStream() =>
      _unimplemented('displayWarningStream');

  // --- Experimental capabilities ----------------------------------------------------

  /// See `MetaWearablesDat.startInputs`.
  Future<void> startInputs(
    InputsConfiguration configuration, {
    String? deviceUuid,
  }) => _unimplemented('startInputs');

  /// See `MetaWearablesDat.stopInputs`.
  Future<void> stopInputs() => _unimplemented('stopInputs');

  /// See `MetaWearablesDat.inputEventsStream`.
  Stream<InputEvent> inputEventsStream() => _unimplemented('inputEventsStream');

  /// See `MetaWearablesDat.inputsStateStream`.
  Stream<InputsState> inputsStateStream() =>
      _unimplemented('inputsStateStream');

  /// See `MetaWearablesDat.inputsErrorStream`.
  Stream<InputsError> inputsErrorStream() =>
      _unimplemented('inputsErrorStream');

  /// See `MetaWearablesDat.startMotion`.
  Future<void> startMotion(
    MotionSamplingRate samplingRate, {
    String? deviceUuid,
  }) => _unimplemented('startMotion');

  /// See `MetaWearablesDat.stopMotion`.
  Future<void> stopMotion() => _unimplemented('stopMotion');

  /// See `MetaWearablesDat.motionSamplesStream`.
  Stream<MotionSample> motionSamplesStream() =>
      _unimplemented('motionSamplesStream');

  /// See `MetaWearablesDat.motionStateStream`.
  Stream<MotionState> motionStateStream() =>
      _unimplemented('motionStateStream');

  /// See `MetaWearablesDat.motionErrorStream`.
  Stream<MotionError> motionErrorStream() =>
      _unimplemented('motionErrorStream');

  /// See `MetaWearablesDat.startSpeech`.
  Future<void> startSpeech({String? deviceUuid}) =>
      _unimplemented('startSpeech');

  /// See `MetaWearablesDat.stopSpeech`.
  Future<void> stopSpeech() => _unimplemented('stopSpeech');

  /// See `MetaWearablesDat.transcriptionStream`.
  Stream<TranscriptionResult> transcriptionStream() =>
      _unimplemented('transcriptionStream');

  /// See `MetaWearablesDat.speechStateStream`.
  Stream<SpeechState> speechStateStream() =>
      _unimplemented('speechStateStream');

  /// See `MetaWearablesDat.speechErrorStream`.
  Stream<SpeechError> speechErrorStream() =>
      _unimplemented('speechErrorStream');

  /// See `MetaWearablesDat.startVoiceInvocations`.
  Future<void> startVoiceInvocations({String? deviceUuid}) =>
      _unimplemented('startVoiceInvocations');

  /// See `MetaWearablesDat.stopVoiceInvocations`.
  Future<void> stopVoiceInvocations() => _unimplemented('stopVoiceInvocations');

  /// See `MetaWearablesDat.voiceInvocationsStream`.
  Stream<VoiceInvocation> voiceInvocationsStream() =>
      _unimplemented('voiceInvocationsStream');

  /// See `MetaWearablesDat.voiceInvocationsStateStream`.
  Stream<VoiceInvocationsState> voiceInvocationsStateStream() =>
      _unimplemented('voiceInvocationsStateStream');

  /// See `MetaWearablesDat.voiceInvocationErrorStream`.
  Stream<VoiceInvocationError> voiceInvocationErrorStream() =>
      _unimplemented('voiceInvocationErrorStream');

  /// Answers a voice invocation.
  Future<bool> respondVoiceInvocation(
    String invocationId, {
    required bool success,
    String? actionOutput,
  }) => _unimplemented('respondVoiceInvocation');

  // --- Mock Device Kit ------------------------------------------------------------------

  /// See `MetaWearablesDat.enableMockDevice`.
  Future<void> enableMockDevice({
    required bool initiallyRegistered,
    required bool initialPermissionsGranted,
  }) => _unimplemented('enableMockDevice');

  /// See `MetaWearablesDat.disableMockDevice`.
  Future<void> disableMockDevice() => _unimplemented('disableMockDevice');

  /// See `MetaWearablesDat.isMockDeviceEnabled`.
  Future<bool> isMockDeviceEnabled() => _unimplemented('isMockDeviceEnabled');

  /// See `MetaWearablesDat.pairMockGlasses`.
  Future<DeviceInfo> pairMockGlasses(MockGlassesModel model) =>
      _unimplemented('pairMockGlasses');

  /// See `MetaWearablesDat.pairedMockDevices`.
  Future<List<DeviceInfo>> pairedMockDevices() =>
      _unimplemented('pairedMockDevices');

  /// See `MetaWearablesDat.unpairMockDevice`.
  Future<void> unpairMockDevice(String uuid) =>
      _unimplemented('unpairMockDevice');

  /// See `MetaWearablesDat.mockDevicesStream`.
  Stream<List<DeviceInfo>> mockDevicesStream() =>
      _unimplemented('mockDevicesStream');

  /// Runs a parameterless mock action (`mockPowerOn`, `mockFold`,
  /// `mockCaptouchTap`, ...) on [uuid].
  Future<void> mockAction(String method, String uuid) => _unimplemented(method);

  /// See `MetaWearablesDat.setMockBatteryLevel`.
  Future<void> setMockBatteryLevel(String uuid, int? level) =>
      _unimplemented('setMockBatteryLevel');

  /// See `MetaWearablesDat.setMockChargingState`.
  Future<void> setMockChargingState(String uuid, ChargingState state) =>
      _unimplemented('setMockChargingState');

  /// See `MetaWearablesDat.setMockThermalLevel`.
  Future<void> setMockThermalLevel(String uuid, ThermalLevel level) =>
      _unimplemented('setMockThermalLevel');

  /// See `MetaWearablesDat.setMockCameraFacing`.
  Future<void> setMockCameraFacing(String uuid, CameraFacing facing) =>
      _unimplemented('setMockCameraFacing');

  /// Sets a mock media file (`setMockCameraFeed`, `setMockCapturedImage`,
  /// `setMockCapturedPhoto`).
  Future<void> setMockFile(String method, String uuid, String filePath) =>
      _unimplemented(method);

  /// See `MetaWearablesDat.simulateMockCaptureFailure`.
  Future<void> simulateMockCaptureFailure(String uuid) =>
      _unimplemented('simulateMockCaptureFailure');

  /// See `MetaWearablesDat.setMockPermission`.
  Future<void> setMockPermission(
    Permission permission,
    PermissionStatus status, {
    required bool requestResult,
  }) => _unimplemented('setMockPermission');

  /// Sends a mock input (`args.action`: navUp, select, capture, drag, ...).
  Future<void> mockInput(String uuid, Map<String, Object?> args) =>
      _unimplemented('mockInput');

  /// Drives the mock speech service (`args.action`: source, transcription,
  /// error, completion, locale).
  Future<void> mockSpeech(String uuid, Map<String, Object?> args) =>
      _unimplemented('mockSpeech');

  /// See `MetaWearablesDat.setMockMotionFeed`.
  Future<void> setMockMotionFeed(
    String uuid, {
    List<MotionSample>? samples,
    String? filePath,
    bool loop = true,
  }) => _unimplemented('setMockMotionFeed');

  /// See `MetaWearablesDat.simulateMockVoiceInvocation`.
  Future<String?> simulateMockVoiceInvocation(
    String uuid, {
    bool incomplete = false,
  }) => _unimplemented('simulateMockVoiceInvocation');

  /// See `MetaWearablesDat.startMockTestServer`.
  Future<int> startMockTestServer({int port = 9000}) =>
      _unimplemented('startMockTestServer');

  /// See `MetaWearablesDat.stopMockTestServer`.
  Future<void> stopMockTestServer() => _unimplemented('stopMockTestServer');

  /// See `MetaWearablesDat.sendMockDisplayClick`.
  Future<bool> sendMockDisplayClick(String uuid, String identifier) =>
      _unimplemented('sendMockDisplayClick');
}
