/// Channel names shared by Dart, Swift and Kotlin. `tool/check_channel_parity.dart`
/// verifies that both native bridges register exactly these names.
abstract final class DatChannels {
  /// The method channel.
  static const String method = 'meta_wearables_dat_flutter';

  /// Every method the native bridges handle.
  static const List<String> methods = [
    'getPlatformVersion',
    'dumpDiagnostics',
    'requestAndroidPermissions',
    'getRegistrationState',
    'startRegistration',
    'startUnregistration',
    'handleUrl',
    'continueRegistrationRequest',
    'cancelRegistrationRequest',
    'requestPermission',
    'checkPermissionStatus',
    'openFirmwareUpdate',
    'openDatGlassesAppUpdate',
    'getDevices',
    'getDevice',
    'getSessionDevice',
    'startStreamSession',
    'stopStreamSession',
    'capturePhoto',
    'capturePhotoHq',
    'enableBackgroundStreaming',
    'disableBackgroundStreaming',
    'startDisplaySession',
    'sendDisplayView',
    'clearDisplay',
    'stopDisplayVideo',
    'stopDisplaySession',
    'startInputs',
    'stopInputs',
    'startMotion',
    'stopMotion',
    'startSpeech',
    'stopSpeech',
    'startVoiceInvocations',
    'stopVoiceInvocations',
    'respondVoiceInvocation',
    'enableMockDevice',
    'disableMockDevice',
    'isMockDeviceEnabled',
    'pairMockGlasses',
    'pairedMockDevices',
    'unpairMockDevice',
    'mockPowerOn',
    'mockPowerOff',
    'mockDon',
    'mockDoff',
    'mockFold',
    'mockUnfold',
    'mockCaptouchTap',
    'mockCaptouchTapAndHold',
    'setMockBatteryLevel',
    'setMockChargingState',
    'setMockThermalLevel',
    'setMockCameraFacing',
    'setMockCameraFeed',
    'setMockCapturedImage',
    'setMockCapturedPhoto',
    'simulateMockCaptureFailure',
    'setMockPermission',
    'setMockPermissionRequestResult',
    'mockInput',
    'mockSpeech',
    'setMockMotionFeed',
    'simulateMockVoiceInvocation',
    'startMockTestServer',
    'stopMockTestServer',
    'sendMockDisplayClick',
  ];

  /// Prefix of every event channel.
  static const String eventPrefix = 'meta_wearables_dat_flutter/';

  /// Every event channel name (without [eventPrefix]).
  static const List<String> events = [
    registrationState,
    registrationErrors,
    registrationRequests,
    activeDevice,
    devices,
    deviceState,
    compatibility,
    deviceSessionState,
    deviceSessionErrors,
    streamSessionState,
    streamSessionErrors,
    cameraState,
    videoStreamSize,
    videoFrames,
    audioFrames,
    photoState,
    photoProgress,
    photoErrors,
    displayState,
    displayEvents,
    displayErrors,
    inputsState,
    inputsEvents,
    inputsErrors,
    motionState,
    motionSamples,
    motionErrors,
    speechState,
    speechTranscriptions,
    speechErrors,
    voiceInvocations,
    voiceState,
    voiceErrors,
    mockDevices,
  ];

  /// Registration state changes.
  static const String registrationState = 'registration_state';

  /// Registration errors.
  static const String registrationErrors = 'registration_errors';

  /// Meta AI-initiated registration requests.
  static const String registrationRequests = 'registration_requests';

  /// The auto-selected device.
  static const String activeDevice = 'active_device';

  /// Paired devices.
  static const String devices = 'devices';

  /// Per-device state changes.
  static const String deviceState = 'device_state';

  /// Per-device compatibility verdicts.
  static const String compatibility = 'compatibility';

  /// Device session state.
  static const String deviceSessionState = 'device_session_state';

  /// Device session errors.
  static const String deviceSessionErrors = 'device_session_errors';

  /// Camera stream state.
  static const String streamSessionState = 'stream_session_state';

  /// Camera stream errors.
  static const String streamSessionErrors = 'stream_session_errors';

  /// Camera capability state.
  static const String cameraState = 'camera_state';

  /// Video frame size.
  static const String videoStreamSize = 'video_stream_size';

  /// Opt-in video frames.
  static const String videoFrames = 'video_frames';

  /// Opt-in audio frames.
  static const String audioFrames = 'audio_frames';

  /// High-resolution photo state.
  static const String photoState = 'photo_state';

  /// High-resolution photo transfer progress.
  static const String photoProgress = 'photo_progress';

  /// High-resolution photo errors.
  static const String photoErrors = 'photo_errors';

  /// Display state.
  static const String displayState = 'display_state';

  /// Display taps, clicks, playback events and warnings.
  static const String displayEvents = 'display_events';

  /// Display errors.
  static const String displayErrors = 'display_errors';

  /// Inputs state.
  static const String inputsState = 'inputs_state';

  /// Input events.
  static const String inputsEvents = 'inputs_events';

  /// Inputs errors.
  static const String inputsErrors = 'inputs_errors';

  /// Motion state.
  static const String motionState = 'motion_state';

  /// Motion samples.
  static const String motionSamples = 'motion_samples';

  /// Motion errors.
  static const String motionErrors = 'motion_errors';

  /// Speech state.
  static const String speechState = 'speech_state';

  /// Transcriptions.
  static const String speechTranscriptions = 'speech_transcriptions';

  /// Speech errors.
  static const String speechErrors = 'speech_errors';

  /// Voice invocations.
  static const String voiceInvocations = 'voice_invocations';

  /// Voice invocations stream state.
  static const String voiceState = 'voice_state';

  /// Voice invocation errors.
  static const String voiceErrors = 'voice_errors';

  /// Paired mock devices.
  static const String mockDevices = 'mock_devices';
}
