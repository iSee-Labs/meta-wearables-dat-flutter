// Decoding tests for every event channel: each stream getter is fed one
// native payload through a mock stream handler and must produce the typed
// Dart value.

// ignore_for_file: experimental_member_use

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
import 'package:meta_wearables_dat_flutter/src/channels.dart';
import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_method_channel.dart';
import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_platform_interface.dart';

const _device = <String, Object?>{
  'uuid': 'dev-1',
  'name': 'Glasses',
  'kind': 'rayBanMeta',
  'deviceType': 'rayBanMeta',
  'linkState': 'connected',
  'compatibility': 'compatible',
  'batteryLevel': 80,
  'chargingState': 'charging',
  'donState': 'donned',
  'hingeState': 'open',
  'thermalLevel': 'severe',
  'supportsDisplay': true,
  'isMock': true,
};

Map<String, Object?> _errorEvent(String category, String code) => {
  'code': code,
  'category': category,
  'message': 'boom',
  'platformCase': code,
  'platform': 'ios',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late MethodChannelMetaWearablesDat platform;

  setUp(() => platform = MethodChannelMetaWearablesDat());

  /// Emits [payload] on [channel] and returns the first decoded value.
  Future<T> decode<T>(String channel, Object? payload, Stream<T> stream) {
    messenger.setMockStreamHandler(
      EventChannel('${DatChannels.eventPrefix}$channel'),
      MockStreamHandler.inline(
        onListen: (arguments, sink) => sink.success(payload),
      ),
    );
    return stream.first;
  }

  /// Emits an error event and returns the decoded error.
  Future<DatError> decodeError(
    String channel,
    String category,
    String code,
    Stream<DatError> stream,
  ) => decode(channel, _errorEvent(category, code), stream);

  group('state channels decode their string wire values', () {
    test('core and camera', () async {
      expect(
        await decode(
          DatChannels.registrationState,
          'registered',
          platform.registrationStateStream(),
        ),
        RegistrationState.registered,
      );
      expect(
        await decode(
          DatChannels.deviceSessionState,
          'started',
          platform.deviceSessionStateStream(),
        ),
        DeviceSessionState.started,
      );
      expect(
        await decode(
          DatChannels.streamSessionState,
          'streaming',
          platform.streamSessionStateStream(),
        ),
        StreamSessionState.streaming,
      );
      expect(
        await decode(
          DatChannels.cameraState,
          'starting',
          platform.cameraStateStream(),
        ),
        CameraState.starting,
      );
      expect(
        await decode(
          DatChannels.photoState,
          'stopped',
          platform.photoStateStream(),
        ),
        PhotoState.stopped,
      );
      expect(
        await decode(
          DatChannels.displayState,
          'started',
          platform.displayStateStream(),
        ),
        DisplayState.started,
      );
    });

    test('experimental', () async {
      expect(
        await decode(
          DatChannels.inputsState,
          'inactive',
          platform.inputsStateStream(),
        ),
        InputsState.inactive,
      );
      expect(
        await decode(
          DatChannels.motionState,
          'stopped',
          platform.motionStateStream(),
        ),
        MotionState.stopped,
      );
      expect(
        await decode(
          DatChannels.speechState,
          'starting',
          platform.speechStateStream(),
        ),
        SpeechState.starting,
      );
      expect(
        await decode(
          DatChannels.voiceState,
          'starting',
          platform.voiceInvocationsStateStream(),
        ),
        VoiceInvocationsState.starting,
      );
    });

    test('unknown wire values fall back instead of throwing', () async {
      expect(
        await decode(
          DatChannels.streamSessionState,
          'warpSpeed',
          platform.streamSessionStateStream(),
        ),
        isA<StreamSessionState>(),
      );
    });
  });

  group('device channels', () {
    test('devices and mock devices decode full snapshots', () async {
      final devices = await decode(DatChannels.devices, [
        _device,
      ], platform.devicesStream());
      expect(devices.single.uuid, 'dev-1');
      expect(devices.single.thermalLevel, ThermalLevel.severe);
      expect(devices.single.thermalLevel.isThrottling, isTrue);
      expect(devices.single.chargingState, ChargingState.charging);
      expect(devices.single.supportsDisplay, isTrue);

      final mocks = await decode(DatChannels.mockDevices, [
        _device,
      ], platform.mockDevicesStream());
      expect(mocks.single.isMock, isTrue);
    });

    test('active device may be null', () async {
      expect(
        await decode(
          DatChannels.activeDevice,
          null,
          platform.activeDeviceStream(),
        ),
        isNull,
      );
      expect(
        (await decode(
          DatChannels.activeDevice,
          _device,
          platform.activeDeviceStream(),
        ))?.uuid,
        'dev-1',
      );
    });

    test('device snapshots are value objects', () async {
      final a = await decode(
        DatChannels.deviceState,
        _device,
        platform.deviceStateChanges(),
      );
      final b = DeviceInfo.fromMap(_device);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('dev-1'));
    });

    test('compatibility events', () async {
      final event = await decode(DatChannels.compatibility, {
        'deviceUuid': 'dev-1',
        'compatibility': 'compatible',
      }, platform.compatibilityStream());
      expect(event.deviceUuid, 'dev-1');
      expect(event.compatibility, DeviceCompatibility.compatible);
    });

    test('registration requests', () async {
      final request = await decode(DatChannels.registrationRequests, {
        'requestId': 'r1',
        'flowId': 'f1',
        'protocolVersion': 2,
      }, platform.registrationRequestStream());
      expect(request.requestId, 'r1');
      expect(request.flowId, 'f1');
      expect(request.protocolVersion, 2);
    });
  });

  group('media channels', () {
    test('video stream size', () async {
      final size = await decode(DatChannels.videoStreamSize, {
        'width': 504,
        'height': 896,
      }, platform.videoStreamSizeStream());
      expect((size.width, size.height), (504, 896));
    });

    test('raw and hvc1 video frames', () async {
      final raw = await decode(DatChannels.videoFrames, {
        'codec': 'raw',
        'pixelFormat': 'i420',
        'width': 2,
        'height': 2,
        'ptsUs': 10,
        'planes': [
          {'bytes': Uint8List(4), 'bytesPerRow': 2, 'width': 2, 'height': 2},
        ],
      }, platform.videoFramesStream());
      expect(raw.codec, VideoCodec.raw);
      expect(raw.planes, hasLength(1));
      expect(raw.ptsUs, 10);

      final hevc = await decode(DatChannels.videoFrames, {
        'codec': 'hvc1',
        'bytes': Uint8List.fromList([0, 0, 0, 1]),
        'width': 720,
        'height': 1280,
        'ptsUs': 20,
        'isKeyframe': false,
        'isCodecConfig': true,
      }, platform.videoFramesStream());
      expect(hevc.codec, VideoCodec.hvc1);
      expect(hevc.isKeyframe, isFalse);
      expect(hevc.isCodecConfig, isTrue);
    });

    test('audio frames', () async {
      final frame = await decode(DatChannels.audioFrames, {
        'bytes': Uint8List(8),
        'ptsUs': 5,
        'sampleRate': 16000,
        'channels': 1,
      }, platform.audioFramesStream());
      expect(frame.sampleRate, 16000);
      expect(frame.bytes, hasLength(8));
    });

    test('photo transfer progress', () async {
      final progress = await decode(DatChannels.photoProgress, {
        'bytesReceived': 50,
        'totalBytes': 200,
      }, platform.photoTransferProgressStream());
      expect(progress.bytesReceived, 50);
      expect(progress.totalBytes, 200);
    });
  });

  group('experimental event channels', () {
    test('input events', () async {
      final event = await decode(DatChannels.inputsEvents, {
        'type': 'capture',
        'source': 'captureButton',
        'pressType': 'shortPress',
        'timestampMs': 1,
      }, platform.inputEventsStream());
      expect(event.source, InputSource.captureButton);
    });

    test('motion samples', () async {
      final sample = await decode(DatChannels.motionSamples, {
        'timestampNs': 7,
        'source': 'glasses',
        'accelerometer': {'x': 1.0, 'y': 2.0, 'z': 3.0},
        'orientation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
      }, platform.motionSamplesStream());
      expect(sample.timestampNs, 7);
      expect(sample.accelerometer?.z, 3.0);
      expect(sample.gyroscope, isNull);
    });

    test('transcriptions', () async {
      final result = await decode(DatChannels.speechTranscriptions, {
        'text': 'hello',
        'isFinal': true,
        'confidence': 0.9,
      }, platform.transcriptionStream());
      expect(result.text, 'hello');
      expect(result.isFinal, isTrue);
    });

    test('voice invocations', () async {
      final invocation = await decode(DatChannels.voiceInvocations, {
        'type': 'launch',
        'invocationId': 'v1',
        'deviceUuid': 'dev-1',
      }, platform.voiceInvocationsStream());
      expect(invocation.invocationId, 'v1');
      expect(invocation.deviceUuid, 'dev-1');
    });
  });

  group('error channels decode typed errors', () {
    final cases = <(String, String, String, Stream<DatError> Function(), Type)>[
      (
        DatChannels.registrationErrors,
        DatErrorCodes.registration,
        'timeout',
        () => platform.registrationErrorStream(),
        RegistrationError,
      ),
      (
        DatChannels.deviceSessionErrors,
        DatErrorCodes.deviceSession,
        'thermalCritical',
        () => platform.deviceSessionErrorStream(),
        DeviceSessionError,
      ),
      (
        DatChannels.streamSessionErrors,
        DatErrorCodes.stream,
        'hingesClosed',
        () => platform.streamErrorStream(),
        StreamError,
      ),
      (
        DatChannels.photoErrors,
        DatErrorCodes.photo,
        'busy',
        () => platform.photoErrorStream(),
        PhotoError,
      ),
      (
        DatChannels.displayErrors,
        DatErrorCodes.display,
        'renderingFailed',
        () => platform.displayErrorStream(),
        DisplayError,
      ),
      (
        DatChannels.inputsErrors,
        DatErrorCodes.inputs,
        'unknown',
        () => platform.inputsErrorStream(),
        InputsError,
      ),
      (
        DatChannels.motionErrors,
        DatErrorCodes.motion,
        'unknown',
        () => platform.motionErrorStream(),
        MotionError,
      ),
      (
        DatChannels.speechErrors,
        DatErrorCodes.speech,
        'unknown',
        () => platform.speechErrorStream(),
        SpeechError,
      ),
      (
        DatChannels.voiceErrors,
        DatErrorCodes.voiceInvocation,
        'unknown',
        () => platform.voiceInvocationErrorStream(),
        VoiceInvocationError,
      ),
    ];

    for (final (channel, category, code, open, type) in cases) {
      test('$channel -> $type', () async {
        final error = await decodeError(channel, category, code, open());
        expect(error.runtimeType, type);
        expect(error.category, category);
        expect(error.code, code);
        expect(error.toString(), contains(code));
      });
    }
  });

  group('MetaWearablesDat.deviceStateStream', () {
    const methods = MethodChannel(DatChannels.method);
    late List<Object?> pushed;

    setUp(() {
      MetaWearablesDatPlatform.instance = platform;
      pushed = [];
      messenger
        ..setMockMethodCallHandler(methods, (call) async {
          if (call.method == 'getDevice') return _device;
          return null;
        })
        ..setMockStreamHandler(
          const EventChannel(
            '${DatChannels.eventPrefix}${DatChannels.deviceState}',
          ),
          MockStreamHandler.inline(
            onListen: (arguments, sink) {
              for (final e in pushed) {
                sink.success(e);
              }
            },
          ),
        );
    });

    tearDown(() => messenger.setMockMethodCallHandler(methods, null));

    test('emits the snapshot first, then filtered live updates', () async {
      pushed = [
        {..._device, 'uuid': 'other', 'batteryLevel': 1},
      ];
      final first = await MetaWearablesDat.deviceStateStream('dev-1').first;
      expect(first.batteryLevel, 80);
    });

    test('a stale snapshot never follows a live update', () async {
      pushed = [
        {..._device, 'batteryLevel': 35},
      ];
      final levels = <int?>[];
      await for (final d in MetaWearablesDat.deviceStateStream('dev-1')) {
        levels.add(d.batteryLevel);
        if (d.batteryLevel == 35) break;
      }
      expect(levels.last, 35);
      expect(levels.where((l) => l == 80).length, lessThanOrEqualTo(1));
      if (levels.length == 2) expect(levels.first, 80);
    });

    test('firstWhere completes (cancel never blocks)', () async {
      pushed = [
        {..._device, 'thermalLevel': 'critical'},
      ];
      final hot = await MetaWearablesDat.deviceStateStream('dev-1')
          .firstWhere((d) => d.thermalLevel == ThermalLevel.critical)
          .timeout(const Duration(seconds: 2));
      expect(hot.thermalLevel, ThermalLevel.critical);
    });
  });

  test('platform errors on a channel surface as typed DatErrors', () async {
    messenger.setMockStreamHandler(
      const EventChannel('${DatChannels.eventPrefix}${DatChannels.devices}'),
      MockStreamHandler.inline(
        onListen: (arguments, sink) => sink.error(
          code: 'PLUGIN_ERROR',
          message: 'not configured',
          details: {'case': 'notConfigured'},
        ),
      ),
    );
    await expectLater(platform.devicesStream().first, throwsA(isA<DatError>()));
  });
}
