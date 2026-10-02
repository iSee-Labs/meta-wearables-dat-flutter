// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';
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
  'chargingState': 'notCharging',
  'donState': 'donned',
  'hingeState': 'open',
  'thermalLevel': 'none',
  'supportsDisplay': false,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late MethodChannelMetaWearablesDat platform;

  Object? reply(MethodCall call) {
    switch (call.method) {
      case 'getPlatformVersion':
        return 'iOS 26.0';
      case 'dumpDiagnostics':
        return {
          'platform': 'ios',
          'pluginVersion': '1.0.0',
          'sdkVersion': '1.0.0',
          'wearablesConfigured': true,
          'registrationState': 'registered',
          'devices': [_device],
          'findings': [
            {
              'id': 'bonjourServices',
              'severity': 'warning',
              'message': 'm',
              'fix': 'f',
            },
          ],
          'resources': {'textures': 0, 'listeners': 0},
          'experimentalModulesLinked': {'inputs': true},
        };
      case 'requestAndroidPermissions':
      case 'handleUrl':
      case 'isMockDeviceEnabled':
      case 'respondVoiceInvocation':
      case 'sendMockDisplayClick':
        return true;
      case 'getRegistrationState':
        return 'registered';
      case 'requestPermission':
      case 'checkPermissionStatus':
        return 'granted';
      case 'getDevices':
      case 'pairedMockDevices':
        return [_device];
      case 'getDevice':
      case 'getSessionDevice':
      case 'pairMockGlasses':
        return _device;
      case 'startStreamSession':
        return 7;
      case 'capturePhoto':
        return {
          'bytes': Uint8List.fromList([0xFF, 0xD8]),
          'format': 'jpeg',
        };
      case 'capturePhotoHq':
        return {
          'bytes': Uint8List.fromList([1, 2, 3]),
          'timestampMs': 1000,
        };
      case 'sendDisplayView':
        return <Object?>['warning'];
      case 'simulateMockVoiceInvocation':
        return 'action-1';
      case 'startMockTestServer':
        return 9000;
      default:
        return null;
    }
  }

  setUp(() {
    calls.clear();
    platform = MethodChannelMetaWearablesDat();
    MetaWearablesDatPlatform.instance = platform;
    messenger.setMockMethodCallHandler(platform.methodChannel, (call) async {
      calls.add(call);
      return reply(call);
    });
  });

  tearDown(
    () => messenger.setMockMethodCallHandler(platform.methodChannel, null),
  );

  Map<Object?, Object?> argsOf(String method) =>
      calls.lastWhere((c) => c.method == method).arguments
          as Map<Object?, Object?>? ??
      const {};

  test(
    'every facade method uses a canonical method name and every canonical method is reachable',
    () async {
      const uuid = 'dev-1';
      await MetaWearablesDat.getPlatformVersion();
      await MetaWearablesDat.dumpDiagnostics();
      await MetaWearablesDat.requestAndroidPermissions();
      await MetaWearablesDat.getRegistrationState();
      await MetaWearablesDat.startRegistration();
      await MetaWearablesDat.startUnregistration();
      await MetaWearablesDat.handleUrl('app://x?metaWearablesAction=1');
      await RegistrationRequest(requestId: 'r1').continueRegistration();
      await RegistrationRequest(requestId: 'r2').cancel();
      await MetaWearablesDat.requestPermission(Permission.camera);
      await MetaWearablesDat.checkPermissionStatus(Permission.microphone);
      await MetaWearablesDat.openFirmwareUpdate();
      await MetaWearablesDat.openDatGlassesAppUpdate();
      await MetaWearablesDat.getDevices();
      await MetaWearablesDat.getDevice(uuid);
      await MetaWearablesDat.getSessionDevice();
      await MetaWearablesDat.startStreamSession();
      await MetaWearablesDat.stopStreamSession();
      await MetaWearablesDat.capturePhoto();
      await MetaWearablesDat.captureHighResPhoto();
      await MetaWearablesDat.enableBackgroundStreaming();
      await MetaWearablesDat.disableBackgroundStreaming();
      await MetaWearablesDat.startDisplaySession();
      await MetaWearablesDat.sendDisplayView(const FlexBox());
      await MetaWearablesDat.clearDisplay();
      await MetaWearablesDat.stopDisplayVideo();
      await MetaWearablesDat.stopDisplaySession();
      await MetaWearablesDat.startInputs();
      await MetaWearablesDat.stopInputs();
      await MetaWearablesDat.startMotion();
      await MetaWearablesDat.stopMotion();
      await MetaWearablesDat.startSpeech();
      await MetaWearablesDat.stopSpeech();
      await MetaWearablesDat.startVoiceInvocations();
      await MetaWearablesDat.stopVoiceInvocations();
      await LaunchAppInvocation(invocationId: 'v1').respondSuccess();
      await MetaWearablesDat.enableMockDevice();
      await MetaWearablesDat.disableMockDevice();
      await MetaWearablesDat.isMockDeviceEnabled();
      await MetaWearablesDat.pairMockGlasses();
      await MetaWearablesDat.pairedMockDevices();
      await MetaWearablesDat.unpairMockDevice(uuid);
      await MetaWearablesDat.mockPowerOn(uuid);
      await MetaWearablesDat.mockPowerOff(uuid);
      await MetaWearablesDat.mockDon(uuid);
      await MetaWearablesDat.mockDoff(uuid);
      await MetaWearablesDat.mockFold(uuid);
      await MetaWearablesDat.mockUnfold(uuid);
      await MetaWearablesDat.mockTap(uuid);
      await MetaWearablesDat.mockTapAndHold(uuid);
      await MetaWearablesDat.setMockBatteryLevel(uuid, 40);
      await MetaWearablesDat.setMockChargingState(uuid, ChargingState.charging);
      await MetaWearablesDat.setMockThermalLevel(uuid, ThermalLevel.severe);
      await MetaWearablesDat.setMockCameraFacing(uuid, CameraFacing.front);
      await MetaWearablesDat.setMockCameraFeed(uuid, '/tmp/a.mp4');
      await MetaWearablesDat.setMockCapturedImage(uuid, '/tmp/a.jpg');
      await MetaWearablesDat.setMockCapturedPhoto(uuid, '/tmp/b.jpg');
      await MetaWearablesDat.simulateMockCaptureFailure(uuid);
      await MetaWearablesDat.setMockPermission(
        Permission.camera,
        PermissionStatus.denied,
      );
      await MetaWearablesDat.setMockPermissionRequestResult(
        Permission.camera,
        PermissionStatus.granted,
      );
      await MetaWearablesDat.mockInputSelect(uuid);
      await MetaWearablesDat.simulateMockTranscription(uuid, 'hello');
      await MetaWearablesDat.setMockMotionFeed(
        uuid,
        samples: const [MotionSample(timestampNs: 1)],
      );
      await MetaWearablesDat.simulateMockVoiceInvocation(uuid);
      await MetaWearablesDat.startMockTestServer();
      await MetaWearablesDat.stopMockTestServer();
      await MetaWearablesDat.sendMockDisplayClick(uuid, '0');

      final invoked = calls.map((c) => c.method).toSet();
      expect(
        invoked.difference(DatChannels.methods.toSet()),
        isEmpty,
        reason: 'non-canonical method names',
      );
      expect(
        DatChannels.methods.toSet().difference(invoked),
        isEmpty,
        reason: 'canonical methods not reachable',
      );
    },
  );

  group('argument shapes', () {
    test(
      'startStreamSession sends fps, quality, codec, kinds and audio',
      () async {
        final id = await MetaWearablesDat.startStreamSession(
          deviceUUID: 'dev-1',
          config: const StreamSessionConfig(
            quality: StreamQuality.high,
            frameRate: StreamFrameRate.fps30,
            videoCodec: VideoCodec.hvc1,
            deviceKinds: {DeviceKind.rayBanMeta},
            audio: AudioStreamConfig(sampleRate: AudioSampleRate.hz48000),
          ),
        );
        expect(id, 7);
        expect(argsOf('startStreamSession'), {
          'deviceUuid': 'dev-1',
          'fps': 30,
          'quality': 'high',
          'videoCodec': 'hvc1',
          'deviceKinds': ['rayBanMeta'],
          'audio': {'sampleRate': 48000, 'channels': 1},
        });
      },
    );

    test('startStreamSession defaults to medium / 24 fps / raw', () async {
      await MetaWearablesDat.startStreamSession();
      expect(argsOf('startStreamSession'), {
        'fps': 24,
        'quality': 'medium',
        'videoCodec': 'raw',
      });
    });

    test(
      'deprecated startStreamSession arguments are converted and validated',
      () async {
        await MetaWearablesDat.startStreamSession(
          fps: 15,
          quality: StreamQuality.low,
        );
        expect(argsOf('startStreamSession')['fps'], 15);
        expect(argsOf('startStreamSession')['quality'], 'low');
        expect(
          () => MetaWearablesDat.startStreamSession(fps: 12),
          throwsA(isA<DatArgumentError>()),
        );
      },
    );

    test('permission, mock and experimental calls send wire names', () async {
      await MetaWearablesDat.requestPermission(Permission.microphone);
      expect(argsOf('requestPermission'), {'permission': 'microphone'});
      await MetaWearablesDat.pairMockGlasses(
        MockGlassesModel.metaRayBanDisplay,
      );
      expect(argsOf('pairMockGlasses'), {'model': 'metaRayBanDisplay'});
      await MetaWearablesDat.setMockThermalLevel('d', ThermalLevel.critical);
      expect(argsOf('setMockThermalLevel'), {'uuid': 'd', 'level': 'critical'});
      await MetaWearablesDat.mockInputNav(
        'd',
        NavDirection.left,
        source: InputSource.neuralBand,
      );
      expect(argsOf('mockInput'), {
        'action': 'navLeft',
        'source': 'neuralBand',
        'uuid': 'd',
      });
      await MetaWearablesDat.startInputs(
        configuration: const InputsConfiguration(
          sources: {InputSource.captouch},
          consumeBack: false,
        ),
      );
      expect(argsOf('startInputs'), {
        'sources': ['captouch'],
        'consumeBack': false,
      });
      await MetaWearablesDat.startMotion(samplingRate: MotionSamplingRate.hz60);
      expect(argsOf('startMotion'), {'samplingRate': 60});
      await MetaWearablesDat.captureHighResPhoto(
        resolution: PhotoResolution.full,
        quality: PhotoQuality.high,
      );
      expect(argsOf('capturePhotoHq'), {
        'resolution': 'full',
        'quality': 'high',
      });
    });

    test('setMockBatteryLevel validates the range before calling native', () {
      expect(
        () => MetaWearablesDat.setMockBatteryLevel('d', 101),
        throwsA(isA<DatArgumentError>()),
      );
    });

    test('sendDisplayView sends the JSON tree and returns warnings', () async {
      final warnings = await MetaWearablesDat.sendDisplayView(
        FlexBox(
          children: [DisplayButton(label: 'Go', onClick: () {})],
        ),
      );
      expect(warnings, ['warning']);
      final view = argsOf('sendDisplayView')['view']! as Map<Object?, Object?>;
      expect(view['type'], 'flexBox');
      expect(
        (view['children']! as List<Object?>).single,
        containsPair('onClickId', 'cb0'),
      );
    });

    test(
      'sendDisplayView rejects nested video players without calling native',
      () async {
        await expectLater(
          MetaWearablesDat.sendDisplayView(
            const FlexBox(children: [VideoPlayer('https://x/v.mp4')]),
          ),
          throwsA(isA<DatArgumentError>()),
        );
        expect(calls.where((c) => c.method == 'sendDisplayView'), isEmpty);
      },
    );

    test(
      'registration requests and voice invocations can be answered only once',
      () async {
        final request = RegistrationRequest(requestId: 'r');
        await request.continueRegistration();
        expect(request.cancel, throwsStateError);
        final invocation = LaunchAppInvocation(invocationId: 'v');
        expect(await invocation.respondFailure(actionOutput: 'busy'), isTrue);
        expect(argsOf('respondVoiceInvocation'), {
          'invocationId': 'v',
          'success': false,
          'actionOutput': 'busy',
        });
        expect(invocation.respondSuccess, throwsStateError);
      },
    );
  });

  group('results', () {
    test('diagnostics, devices and photos decode', () async {
      final diagnostics = await MetaWearablesDat.dumpDiagnostics();
      expect(diagnostics.platform, 'ios');
      expect(diagnostics.registrationState, RegistrationState.registered);
      expect(diagnostics.findings.single.severity, DatFindingSeverity.warning);
      expect(diagnostics.isIdle, isTrue);
      final device = (await MetaWearablesDat.getDevices()).single;
      expect(device.batteryLevel, 80);
      expect(device.donState, DonState.donned);
      final photo = await MetaWearablesDat.capturePhoto();
      expect(photo.format, PhotoFormat.jpeg);
      final hq = await MetaWearablesDat.captureHighResPhoto();
      expect(hq.bytes, [1, 2, 3]);
      expect(hq.timestamp, DateTime.fromMillisecondsSinceEpoch(1000));
    });

    test('platform errors become typed DatErrors', () async {
      messenger.setMockMethodCallHandler(platform.methodChannel, (call) async {
        throw PlatformException(
          code: 'DEVICE_SESSION_ERROR',
          message: 'no glasses',
          details: {'case': 'noEligibleDevice', 'platform': 'android'},
        );
      });
      await expectLater(
        MetaWearablesDat.startStreamSession(),
        throwsA(
          isA<DeviceSessionError>().having(
            (e) => e.reason,
            'reason',
            DeviceSessionErrorCase.noEligibleDevice,
          ),
        ),
      );
    });
  });

  group('event channels', () {
    void mockEvents(String name, List<Object?> events) {
      messenger.setMockStreamHandler(
        EventChannel('${DatChannels.eventPrefix}$name'),
        MockStreamHandler.inline(
          onListen: (args, sink) {
            for (final e in events) {
              sink.success(e);
            }
          },
        ),
      );
    }

    test('state channels decode string values', () async {
      mockEvents(DatChannels.registrationState, [
        'available',
        'registered',
        'bogus',
      ]);
      expect(
        await MetaWearablesDat.registrationStateStream().take(3).toList(),
        [
          RegistrationState.available,
          RegistrationState.registered,
          RegistrationState.unavailable,
        ],
      );
      mockEvents(DatChannels.streamSessionState, [
        'starting',
        'streaming',
        'paused',
      ]);
      expect(
        await MetaWearablesDat.streamSessionStateStream().take(3).toList(),
        [
          StreamSessionState.starting,
          StreamSessionState.streaming,
          StreamSessionState.paused,
        ],
      );
      mockEvents(DatChannels.displayState, ['started']);
      expect(
        await MetaWearablesDat.displayStateStream().first,
        DisplayState.started,
      );
    });

    test('video_stream_size is de-duplicated', () async {
      mockEvents(DatChannels.videoStreamSize, [
        {'width': 720, 'height': 1280},
        {'width': 720, 'height': 1280},
        {'width': 504, 'height': 896},
      ]);
      final sizes = await MetaWearablesDat.videoStreamSizeStream()
          .take(2)
          .toList();
      expect(sizes.map((s) => s.width), [720, 504]);
    });

    test('error channels emit typed errors', () async {
      mockEvents(DatChannels.streamSessionErrors, [
        {
          'code': 'hingesClosed',
          'category': 'STREAM_ERROR',
          'message': 'folded',
        },
      ]);
      final error = await MetaWearablesDat.streamErrorStream().first;
      expect(error.reason, StreamErrorCase.hingesClosed);
    });

    test('deviceStateStream seeds the snapshot then filters by uuid', () async {
      mockEvents(DatChannels.deviceState, [
        {..._device, 'uuid': 'other', 'batteryLevel': 10},
        {..._device, 'batteryLevel': 55},
      ]);
      final updates = await MetaWearablesDat.deviceStateStream(
        'dev-1',
      ).take(2).toList();
      expect(updates.map((d) => d.batteryLevel), [80, 55]);
    });

    test('display callbacks are dispatched by id', () async {
      final tapped = Completer<void>();
      mockEvents(DatChannels.displayEvents, [
        {'callbackId': 'cb0', 'type': 'click'},
      ]);
      await MetaWearablesDat.sendDisplayView(
        FlexBox(
          children: [DisplayButton(label: 'Go', onClick: tapped.complete)],
        ),
      );
      await tapped.future.timeout(const Duration(seconds: 2));
    });

    test('experimental events decode', () async {
      mockEvents(DatChannels.inputsEvents, [
        {
          'type': 'capture',
          'source': 'captureButton',
          'timestampMs': 5,
          'pressType': 'doublePress',
        },
      ]);
      final input = await MetaWearablesDat.inputEventsStream().first;
      expect(
        input,
        isA<CaptureInputEvent>().having(
          (e) => e.pressType,
          'pressType',
          CapturePressType.doublePress,
        ),
      );
      mockEvents(DatChannels.motionSamples, [
        {
          'timestampNs': 9,
          'orientation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
          'source': 'glasses',
        },
      ]);
      final sample = await MetaWearablesDat.motionSamplesStream().first;
      expect(sample.orientation!.w, 1.0);
      expect(sample.accelerometer, isNull);
      mockEvents(DatChannels.speechTranscriptions, [
        {'text': 'hi', 'isFinal': true, 'confidence': -1.0},
      ]);
      final transcription = await MetaWearablesDat.transcriptionStream().first;
      expect(transcription.confidence, isNull);
    });

    test(
      'a native configuration failure surfaces as a DatError on the stream',
      () async {
        messenger.setMockStreamHandler(
          const EventChannel(
            '${DatChannels.eventPrefix}${DatChannels.devices}',
          ),
          MockStreamHandler.inline(
            onListen: (args, sink) {
              sink.error(
                code: 'PLUGIN_ERROR',
                message: 'not configured',
                details: {'case': 'wearablesNotConfigured'},
              );
            },
          ),
        );
        await expectLater(
          MetaWearablesDat.devicesStream().first,
          throwsA(
            isA<DatPluginError>().having(
              (e) => e.code,
              'code',
              'wearablesNotConfigured',
            ),
          ),
        );
      },
    );
  });
}
