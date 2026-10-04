import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:meta_wearables_dat_flutter/src/channels.dart';
import 'package:meta_wearables_dat_flutter/src/error_mapping.dart';
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
import 'package:meta_wearables_dat_flutter/src/models/high_res_photo.dart';
import 'package:meta_wearables_dat_flutter/src/models/mock.dart';
import 'package:meta_wearables_dat_flutter/src/models/permission.dart';
import 'package:meta_wearables_dat_flutter/src/models/photo_result.dart';
import 'package:meta_wearables_dat_flutter/src/models/registration_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/stream_config.dart';
import 'package:meta_wearables_dat_flutter/src/models/stream_session_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/video_frame.dart';
import 'package:meta_wearables_dat_flutter/src/models/video_stream_size.dart';

/// [MetaWearablesDatPlatform] implemented over platform channels.
class MethodChannelMetaWearablesDat extends MetaWearablesDatPlatform {
  /// The method channel.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(DatChannels.method);

  final Map<String, Stream<Object?>> _streams = {};

  /// The broadcast stream of event channel [name]. Each channel has one
  /// native subscription, shared by every Dart listener; the native side
  /// stops producing when the last listener cancels.
  @visibleForTesting
  Stream<Object?> events(String name) => _streams.putIfAbsent(
    name,
    () => EventChannel('${DatChannels.eventPrefix}$name')
        .receiveBroadcastStream()
        .handleError((Object error) {
          if (error is PlatformException) {
            throw DatErrorMapper.fromPlatformException(error);
          }
          // ignore: only_throw_errors
          throw error;
        }),
  );

  /// Shared display callback table; replaced on every `sendDisplayView`.
  DisplayCallbackTable _displayCallbacks = DisplayCallbackTable();
  // Long-lived: dispatches every display callback for the plugin's lifetime.
  // ignore: cancel_subscriptions
  StreamSubscription<Object?>? _displayEventsSubscription;
  final StreamController<String> _displayWarnings =
      StreamController<String>.broadcast();

  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await methodChannel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw DatErrorMapper.fromPlatformException(e);
    }
  }

  Future<T> _require<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    final value = await _invoke<T>(method, arguments);
    if (value == null) {
      throw DatPluginError(
        code: 'nullResult',
        message: '$method returned no value.',
      );
    }
    return value;
  }

  static Map<Object?, Object?> _map(Object? value) =>
      value as Map<Object?, Object?>? ?? const {};

  static List<DeviceInfo> _devices(Object? value) =>
      (value as List<Object?>? ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map(DeviceInfo.fromMap)
          .toList(growable: false);

  Stream<T> _errors<T extends DatError>(String channel, String category) =>
      events(channel)
          .map(
            (event) =>
                DatErrorMapper.fromEvent(event, defaultCategory: category),
          )
          .where((error) => error is T)
          .cast<T>();

  // --- Platform & diagnostics ---------------------------------------------------

  @override
  Future<String?> getPlatformVersion() => _invoke<String>('getPlatformVersion');

  @override
  Future<DatDiagnostics> dumpDiagnostics() async => DatDiagnostics.fromMap(
    _map(await _invoke<Map<Object?, Object?>>('dumpDiagnostics')),
  );

  @override
  Future<bool> requestAndroidPermissions() async =>
      await _invoke<bool>('requestAndroidPermissions') ?? false;

  // --- Registration ---------------------------------------------------------------

  @override
  Future<void> startRegistration() => _invoke<void>('startRegistration');

  @override
  Future<void> startUnregistration() => _invoke<void>('startUnregistration');

  @override
  Future<bool> handleUrl(String url) async =>
      await _invoke<bool>('handleUrl', {'url': url}) ?? false;

  @override
  Future<RegistrationState> getRegistrationState() async =>
      RegistrationState.fromWire(await _invoke<String>('getRegistrationState'));

  @override
  Stream<RegistrationState> registrationStateStream() =>
      events(DatChannels.registrationState).map(RegistrationState.fromWire);

  @override
  Stream<DatError> registrationErrorStream() => _errors<DatError>(
    DatChannels.registrationErrors,
    DatErrorCodes.registration,
  );

  @override
  Stream<RegistrationRequest> registrationRequestStream() => events(
    DatChannels.registrationRequests,
  ).map((e) => RegistrationRequest.fromMap(_map(e)));

  @override
  Future<void> answerRegistrationRequest(
    String requestId, {
    required bool accept,
  }) => _invoke<void>(
    accept ? 'continueRegistrationRequest' : 'cancelRegistrationRequest',
    {'requestId': requestId},
  );

  // --- Permissions & navigation -------------------------------------------------

  @override
  Future<PermissionStatus> requestPermission(Permission permission) async =>
      PermissionStatus.fromWire(
        await _invoke<String>('requestPermission', {
          'permission': permission.name,
        }),
      );

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      PermissionStatus.fromWire(
        await _invoke<String>('checkPermissionStatus', {
          'permission': permission.name,
        }),
      );

  @override
  Future<void> openFirmwareUpdate() => _invoke<void>('openFirmwareUpdate');

  @override
  Future<void> openDatGlassesAppUpdate() =>
      _invoke<void>('openDatGlassesAppUpdate');

  // --- Devices --------------------------------------------------------------------

  @override
  Future<List<DeviceInfo>> getDevices() async =>
      _devices(await _invoke<List<Object?>>('getDevices'));

  @override
  Future<DeviceInfo?> getDevice(String deviceUuid) async {
    final map = await _invoke<Map<Object?, Object?>>('getDevice', {
      'deviceUuid': deviceUuid,
    });
    return map == null ? null : DeviceInfo.fromMap(map);
  }

  @override
  Future<DeviceInfo?> getSessionDevice() async {
    final map = await _invoke<Map<Object?, Object?>>('getSessionDevice');
    return map == null ? null : DeviceInfo.fromMap(map);
  }

  @override
  Stream<List<DeviceInfo>> devicesStream() =>
      events(DatChannels.devices).map(_devices);

  @override
  Stream<DeviceInfo> deviceStateChanges() =>
      events(DatChannels.deviceState).map((e) => DeviceInfo.fromMap(_map(e)));

  @override
  Stream<DeviceInfo?> activeDeviceStream() => events(
    DatChannels.activeDevice,
  ).map((e) => e == null ? null : DeviceInfo.fromMap(_map(e)));

  @override
  Stream<DeviceCompatibilityEvent> compatibilityStream() => events(
    DatChannels.compatibility,
  ).map((e) => DeviceCompatibilityEvent.fromMap(_map(e)));

  @override
  Stream<DeviceSessionState> deviceSessionStateStream() =>
      events(DatChannels.deviceSessionState).map(DeviceSessionState.fromWire);

  @override
  Stream<DeviceSessionError> deviceSessionErrorStream() =>
      _errors<DeviceSessionError>(
        DatChannels.deviceSessionErrors,
        DatErrorCodes.deviceSession,
      );

  // --- Camera ---------------------------------------------------------------------

  @override
  Future<int> startStreamSession(
    StreamSessionConfig config, {
    String? deviceUuid,
  }) =>
      _require<int>('startStreamSession', config.toMap(deviceUuid: deviceUuid));

  @override
  Future<void> stopStreamSession() => _invoke<void>('stopStreamSession');

  @override
  Stream<StreamSessionState> streamSessionStateStream() =>
      events(DatChannels.streamSessionState).map(StreamSessionState.fromWire);

  @override
  Stream<StreamError> streamErrorStream() => _errors<StreamError>(
    DatChannels.streamSessionErrors,
    DatErrorCodes.stream,
  );

  @override
  Stream<CameraState> cameraStateStream() =>
      events(DatChannels.cameraState).map(CameraState.fromWire);

  @override
  Stream<VideoStreamSize> videoStreamSizeStream() =>
      events(DatChannels.videoStreamSize)
          .map((e) => VideoStreamSize.fromMap(_map(e)))
          .distinct((a, b) => a.width == b.width && a.height == b.height);

  @override
  Stream<VideoFrame> videoFramesStream() =>
      events(DatChannels.videoFrames).map((e) => VideoFrame.fromMap(_map(e)));

  @override
  Stream<AudioFrame> audioFramesStream() =>
      events(DatChannels.audioFrames).map((e) => AudioFrame.fromMap(_map(e)));

  @override
  Future<PhotoResult> capturePhoto({
    PhotoFormat format = PhotoFormat.jpeg,
  }) async {
    final map = await _require<Map<Object?, Object?>>('capturePhoto', {
      'format': format.name,
    });
    return PhotoResult(
      bytes: map['bytes']! as Uint8List,
      format: map['format'] == 'heic' ? PhotoFormat.heic : PhotoFormat.jpeg,
    );
  }

  @override
  Future<HighResPhoto> captureHighResPhoto({
    required PhotoResolution resolution,
    required PhotoQuality quality,
  }) async => HighResPhoto.fromMap(
    await _require<Map<Object?, Object?>>('capturePhotoHq', {
      'resolution': resolution.name,
      'quality': quality.name,
    }),
  );

  @override
  Stream<PhotoTransferProgress> photoTransferProgressStream() => events(
    DatChannels.photoProgress,
  ).map((e) => PhotoTransferProgress.fromMap(_map(e)));

  @override
  Stream<PhotoState> photoStateStream() =>
      events(DatChannels.photoState).map(PhotoState.fromWire);

  @override
  Stream<PhotoError> photoErrorStream() =>
      _errors<PhotoError>(DatChannels.photoErrors, DatErrorCodes.photo);

  @override
  Future<void> enableBackgroundStreaming({
    BackgroundNotification? androidNotification,
  }) => _invoke<void>('enableBackgroundStreaming', {
    if (androidNotification != null)
      'androidNotification': androidNotification.toMap(),
  });

  @override
  Future<void> disableBackgroundStreaming() =>
      _invoke<void>('disableBackgroundStreaming');

  // --- Display --------------------------------------------------------------------

  void _ensureDisplayEvents() {
    _displayEventsSubscription ??= events(DatChannels.displayEvents).listen((
      event,
    ) {
      final map = _map(event);
      if (map['type'] == 'warning') {
        _displayWarnings.add(map['message'] as String? ?? '');
        return;
      }
      _displayCallbacks.dispatch(map);
    }, onError: (Object _) {});
  }

  @override
  Future<void> startDisplaySession({String? deviceUuid}) {
    _ensureDisplayEvents();
    return _invoke<void>('startDisplaySession', {
      if (deviceUuid != null) 'deviceUuid': deviceUuid,
    });
  }

  @override
  Future<List<String>> sendDisplayView(DisplayView view) async {
    final fatal = view.validate().where((issue) => issue.isFatal).toList();
    if (fatal.isNotEmpty) {
      throw DatArgumentError(message: fatal.map((i) => i.message).join(' '));
    }
    _ensureDisplayEvents();
    final table = DisplayCallbackTable();
    final json = view.toJson(table);
    _displayCallbacks = table;
    final warnings = await _invoke<List<Object?>>('sendDisplayView', {
      'view': json,
    });
    return (warnings ?? const []).whereType<String>().toList(growable: false);
  }

  @override
  Future<void> clearDisplay() => _invoke<void>('clearDisplay');

  @override
  Future<void> stopDisplayVideo() => _invoke<void>('stopDisplayVideo');

  @override
  Future<void> stopDisplaySession() async {
    await _invoke<void>('stopDisplaySession');
    _displayCallbacks = DisplayCallbackTable();
  }

  @override
  Stream<DisplayState> displayStateStream() =>
      events(DatChannels.displayState).map(DisplayState.fromWire);

  @override
  Stream<DisplayError> displayErrorStream() =>
      _errors<DisplayError>(DatChannels.displayErrors, DatErrorCodes.display);

  @override
  Stream<String> displayWarningStream() {
    _ensureDisplayEvents();
    return _displayWarnings.stream;
  }

  // --- Experimental capabilities ----------------------------------------------------

  @override
  Future<void> startInputs(
    InputsConfiguration configuration, {
    String? deviceUuid,
  }) => _invoke<void>('startInputs', {
    ...configuration.toMap(),
    if (deviceUuid != null) 'deviceUuid': deviceUuid,
  });

  @override
  Future<void> stopInputs() => _invoke<void>('stopInputs');

  @override
  Stream<InputEvent> inputEventsStream() =>
      events(DatChannels.inputsEvents).map((e) => InputEvent.fromMap(_map(e)));

  @override
  Stream<InputsState> inputsStateStream() =>
      events(DatChannels.inputsState).map(InputsState.fromWire);

  @override
  Stream<InputsError> inputsErrorStream() =>
      _errors<InputsError>(DatChannels.inputsErrors, DatErrorCodes.inputs);

  @override
  Future<void> startMotion(
    MotionSamplingRate samplingRate, {
    String? deviceUuid,
  }) => _invoke<void>('startMotion', {
    'samplingRate': samplingRate.value,
    if (deviceUuid != null) 'deviceUuid': deviceUuid,
  });

  @override
  Future<void> stopMotion() => _invoke<void>('stopMotion');

  @override
  Stream<MotionSample> motionSamplesStream() => events(
    DatChannels.motionSamples,
  ).map((e) => MotionSample.fromMap(_map(e)));

  @override
  Stream<MotionState> motionStateStream() =>
      events(DatChannels.motionState).map(MotionState.fromWire);

  @override
  Stream<MotionError> motionErrorStream() =>
      _errors<MotionError>(DatChannels.motionErrors, DatErrorCodes.motion);

  @override
  Future<void> startSpeech({String? deviceUuid}) => _invoke<void>(
    'startSpeech',
    {if (deviceUuid != null) 'deviceUuid': deviceUuid},
  );

  @override
  Future<void> stopSpeech() => _invoke<void>('stopSpeech');

  @override
  Stream<TranscriptionResult> transcriptionStream() => events(
    DatChannels.speechTranscriptions,
  ).map((e) => TranscriptionResult.fromMap(_map(e)));

  @override
  Stream<SpeechState> speechStateStream() =>
      events(DatChannels.speechState).map(SpeechState.fromWire);

  @override
  Stream<SpeechError> speechErrorStream() =>
      _errors<SpeechError>(DatChannels.speechErrors, DatErrorCodes.speech);

  @override
  Future<void> startVoiceInvocations({String? deviceUuid}) => _invoke<void>(
    'startVoiceInvocations',
    {if (deviceUuid != null) 'deviceUuid': deviceUuid},
  );

  @override
  Future<void> stopVoiceInvocations() => _invoke<void>('stopVoiceInvocations');

  @override
  Stream<VoiceInvocation> voiceInvocationsStream() => events(
    DatChannels.voiceInvocations,
  ).map((e) => VoiceInvocation.fromMap(_map(e)));

  @override
  Stream<VoiceInvocationsState> voiceInvocationsStateStream() =>
      events(DatChannels.voiceState).map(VoiceInvocationsState.fromWire);

  @override
  Stream<VoiceInvocationError> voiceInvocationErrorStream() =>
      _errors<VoiceInvocationError>(
        DatChannels.voiceErrors,
        DatErrorCodes.voiceInvocation,
      );

  @override
  Future<bool> respondVoiceInvocation(
    String invocationId, {
    required bool success,
    String? actionOutput,
  }) async =>
      await _invoke<bool>('respondVoiceInvocation', {
        'invocationId': invocationId,
        'success': success,
        if (actionOutput != null) 'actionOutput': actionOutput,
      }) ??
      false;

  // --- Mock Device Kit ------------------------------------------------------------------

  @override
  Future<void> enableMockDevice({
    required bool initiallyRegistered,
    required bool initialPermissionsGranted,
  }) => _invoke<void>('enableMockDevice', {
    'initiallyRegistered': initiallyRegistered,
    'initialPermissionsGranted': initialPermissionsGranted,
  });

  @override
  Future<void> disableMockDevice() => _invoke<void>('disableMockDevice');

  @override
  Future<bool> isMockDeviceEnabled() async =>
      await _invoke<bool>('isMockDeviceEnabled') ?? false;

  @override
  Future<DeviceInfo> pairMockGlasses(MockGlassesModel model) async =>
      DeviceInfo.fromMap(
        await _require<Map<Object?, Object?>>('pairMockGlasses', {
          'model': model.name,
        }),
      );

  @override
  Future<List<DeviceInfo>> pairedMockDevices() async =>
      _devices(await _invoke<List<Object?>>('pairedMockDevices'));

  @override
  Future<void> unpairMockDevice(String uuid) =>
      _invoke<void>('unpairMockDevice', {'uuid': uuid});

  @override
  Stream<List<DeviceInfo>> mockDevicesStream() =>
      events(DatChannels.mockDevices).map(_devices);

  @override
  Future<void> mockAction(String method, String uuid) =>
      _invoke<void>(method, {'uuid': uuid});

  @override
  Future<void> setMockBatteryLevel(String uuid, int? level) =>
      _invoke<void>('setMockBatteryLevel', {'uuid': uuid, 'level': level});

  @override
  Future<void> setMockChargingState(String uuid, ChargingState state) =>
      _invoke<void>('setMockChargingState', {
        'uuid': uuid,
        'state': state.name,
      });

  @override
  Future<void> setMockThermalLevel(String uuid, ThermalLevel level) =>
      _invoke<void>('setMockThermalLevel', {'uuid': uuid, 'level': level.name});

  @override
  Future<void> setMockCameraFacing(String uuid, CameraFacing facing) =>
      _invoke<void>('setMockCameraFacing', {
        'uuid': uuid,
        'facing': facing.value,
      });

  @override
  Future<void> setMockFile(String method, String uuid, String filePath) =>
      _invoke<void>(method, {'uuid': uuid, 'filePath': filePath});

  @override
  Future<void> simulateMockCaptureFailure(String uuid) =>
      _invoke<void>('simulateMockCaptureFailure', {'uuid': uuid});

  @override
  Future<void> setMockPermission(
    Permission permission,
    PermissionStatus status, {
    required bool requestResult,
  }) => _invoke<void>(
    requestResult ? 'setMockPermissionRequestResult' : 'setMockPermission',
    {'permission': permission.name, 'status': status.name},
  );

  @override
  Future<void> mockInput(String uuid, Map<String, Object?> args) =>
      _invoke<void>('mockInput', {...args, 'uuid': uuid});

  @override
  Future<void> mockSpeech(String uuid, Map<String, Object?> args) =>
      _invoke<void>('mockSpeech', {...args, 'uuid': uuid});

  @override
  Future<void> setMockMotionFeed(
    String uuid, {
    List<MotionSample>? samples,
    String? filePath,
    bool loop = true,
  }) => _invoke<void>('setMockMotionFeed', {
    'uuid': uuid,
    if (filePath != null) 'filePath': filePath,
    if (samples != null)
      'samples': samples.map((s) => s.toMap()).toList(growable: false),
    'loop': loop,
  });

  @override
  Future<String?> simulateMockVoiceInvocation(
    String uuid, {
    bool incomplete = false,
  }) => _invoke<String>('simulateMockVoiceInvocation', {
    'uuid': uuid,
    'incomplete': incomplete,
  });

  @override
  Future<int> startMockTestServer({int port = 9000}) =>
      _require<int>('startMockTestServer', {'port': port});

  @override
  Future<void> stopMockTestServer() => _invoke<void>('stopMockTestServer');

  @override
  Future<bool> sendMockDisplayClick(String uuid, String identifier) async =>
      await _invoke<bool>('sendMockDisplayClick', {
        'uuid': uuid,
        'identifier': identifier,
      }) ??
      false;
}
