// ignore_for_file: experimental_member_use

// End-to-end tests against Meta's DAT 1.0 SDK, driven by Mock Device Kit.
//
//   cd example
//   flutter test integration_test/plugin_test.dart -d <simulator or emulator>

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

import 'mock_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final harness = MockHarness();

  // Mock Device Kit initialises the SDK itself, so the tests do not need
  // the Android runtime permission dialog.

  tearDown(harness.teardown);

  testWidgets('diagnostics report versions and an idle plugin', (tester) async {
    final diagnostics = await MetaWearablesDat.dumpDiagnostics();
    expect(diagnostics.pluginVersion, startsWith('1.0.'));
    expect(diagnostics.sdkVersion, '1.0.0');
    expect(diagnostics.platform, Platform.isIOS ? 'ios' : 'android');
    expect(diagnostics.experimentalModulesLinked['inputs'], isTrue);
    expect(diagnostics.errors, isEmpty, reason: diagnostics.errors.join('\n'));
  });

  testWidgets('mock glasses pair, come online and report device state', (
    tester,
  ) async {
    await harness.enable();
    final uuid = await harness.bringOnline();

    expect(
      await MetaWearablesDat.getRegistrationState(),
      RegistrationState.registered,
    );
    final mocks = await MetaWearablesDat.pairedMockDevices();
    expect(mocks.single.uuid, uuid);
    expect(mocks.single.isMock, isTrue);

    final battery = firstWhere(
      MetaWearablesDat.deviceStateStream(uuid),
      (d) => d.batteryLevel == 35,
    );
    await MetaWearablesDat.setMockBatteryLevel(uuid, 35);
    expect((await battery).batteryLevel, 35);

    final thermal = firstWhere(
      MetaWearablesDat.deviceStateStream(uuid),
      (d) => d.thermalLevel == ThermalLevel.severe,
    );
    await MetaWearablesDat.setMockThermalLevel(uuid, ThermalLevel.severe);
    expect((await thermal).thermalLevel.isThrottling, isTrue);
  });

  testWidgets('mock permissions control the permission status', (tester) async {
    await harness.enable();
    await harness.bringOnline();
    await MetaWearablesDat.setMockPermission(
      Permission.camera,
      PermissionStatus.denied,
    );
    expect(
      await MetaWearablesDat.checkPermissionStatus(Permission.camera),
      PermissionStatus.denied,
    );
    await MetaWearablesDat.setMockPermission(
      Permission.camera,
      PermissionStatus.granted,
    );
    expect(
      await MetaWearablesDat.checkPermissionStatus(Permission.camera),
      PermissionStatus.granted,
    );
  });

  testWidgets('raw stream renders, captures a photo and releases everything', (
    tester,
  ) async {
    await harness.enable();
    final uuid = await harness.bringOnline();
    await MetaWearablesDat.setMockCameraFeed(
      uuid,
      await harness.materialise('assets/mock/mock_feed_h265.mp4'),
    );
    await MetaWearablesDat.setMockCapturedImage(
      uuid,
      await harness.materialise('assets/mock/mock_photo.jpg'),
    );

    final size = MetaWearablesDat.videoStreamSizeStream().first.timeout(
      const Duration(seconds: 30),
    );
    final textureId = await MetaWearablesDat.startStreamSession(
      config: const StreamSessionConfig(quality: StreamQuality.low),
    );
    expect(textureId, greaterThanOrEqualTo(0));
    expect((await size).width, greaterThan(0));

    final diagnostics = await MetaWearablesDat.dumpDiagnostics();
    expect(diagnostics.resources['textures'], 1);
    expect(diagnostics.resources['deviceSessions'], 1);
    expect((await MetaWearablesDat.getSessionDevice())?.uuid, uuid);

    final photo = await MetaWearablesDat.capturePhoto();
    expect(photo.bytes, isNotEmpty);

    await MetaWearablesDat.stopStreamSession();
    final after = await MetaWearablesDat.dumpDiagnostics();
    expect(after.resources['textures'], 0);
    expect(after.resources['deviceSessions'], 0);
  });

  testWidgets('hvc1 frames are delivered on videoFramesStream', (tester) async {
    await harness.enable();
    final uuid = await harness.bringOnline();
    await MetaWearablesDat.setMockCameraFeed(
      uuid,
      await harness.materialise('assets/mock/mock_feed_h265.mp4'),
    );
    final frame = MetaWearablesDat.videoFramesStream()
        .firstWhere((f) => !f.isCodecConfig)
        .timeout(const Duration(seconds: 30));
    await MetaWearablesDat.startStreamSession(
      config: const StreamSessionConfig(videoCodec: VideoCodec.hvc1),
    );
    final first = await frame;
    expect(first.codec, VideoCodec.hvc1);
    expect(first.bytes, isNotEmpty);
  });

  testWidgets('folding the glasses stops the stream', (tester) async {
    await harness.enable();
    final uuid = await harness.bringOnline();
    await MetaWearablesDat.setMockCameraFeed(
      uuid,
      await harness.materialise('assets/mock/mock_feed_h265.mp4'),
    );
    await MetaWearablesDat.startStreamSession();
    final stopped = firstWhere(
      MetaWearablesDat.streamSessionStateStream(),
      (s) => s == StreamSessionState.stopped,
      timeout: const Duration(seconds: 30),
    );
    await MetaWearablesDat.mockFold(uuid);
    await stopped;
    await waitFor(
      () async =>
          (await MetaWearablesDat.dumpDiagnostics()).resources['textures'] == 0,
      reason: 'texture not released after fold',
    );
  });

  testWidgets('display session on Meta Ray-Ban Display', (tester) async {
    await harness.enable();
    final uuid = await harness.bringOnline(MockGlassesModel.metaRayBanDisplay);
    expect((await MetaWearablesDat.getDevice(uuid))?.supportsDisplay, isTrue);

    await MetaWearablesDat.startDisplaySession(deviceUUID: uuid);
    var clicks = 0;
    final warnings = await MetaWearablesDat.sendDisplayView(
      FlexBox(
        spacing: 8,
        children: [
          const DisplayText(
            'Integration test',
            style: DisplayTextStyle.heading,
          ),
          const DisplayIcon(DisplayIconName.checkmarkCircle),
          DisplayButtonGroup(
            buttons: [
              DisplayButton(
                label: 'OK',
                actionRole: DisplayActionRole.primary,
                onClick: () => clicks++,
              ),
            ],
          ),
        ],
      ),
    );
    expect(warnings, isEmpty);
    expect(clicks, 0);
    // Meta does not document the identifier format of MockDisplayKit
    // clicks, so only acceptance is asserted here.
    expect(await MetaWearablesDat.sendMockDisplayClick(uuid, '0'), isTrue);
    expect(
      await firstWhere(
        MetaWearablesDat.displayStateStream(),
        (s) => s == DisplayState.started,
      ),
      DisplayState.started,
    );
    await MetaWearablesDat.clearDisplay();
    await MetaWearablesDat.stopDisplaySession();
  });

  testWidgets(
    'experimental inputs, motion, speech and voice through mock services',
    (tester) async {
      await harness.enable();
      final uuid = await harness.bringOnline(
        MockGlassesModel.metaRayBanDisplay,
      );

      // Inputs
      await MetaWearablesDat.startInputs();
      await firstWhere(
        MetaWearablesDat.inputsStateStream(),
        (s) => s == InputsState.active,
      );
      final select = firstWhere(
        MetaWearablesDat.inputEventsStream(),
        (e) => e is SelectInputEvent,
      );
      await MetaWearablesDat.mockInputSelect(uuid);
      await select;

      // Motion
      await MetaWearablesDat.setMockMotionFeed(
        uuid,
        samples: [
          for (var i = 0; i < 20; i++)
            MotionSample(
              timestampNs: i * 100000000,
              accelerometer: const Vector3(0, 0, 9.81),
              orientation: const Quaternion(0, 0, 0, 1),
            ),
        ],
      );
      final sample = MetaWearablesDat.motionSamplesStream().first.timeout(
        const Duration(seconds: 20),
      );
      await MetaWearablesDat.startMotion();
      expect((await sample).accelerometer, isNotNull);

      // Speech
      await MetaWearablesDat.setMockPermission(
        Permission.microphone,
        PermissionStatus.granted,
      );
      await MetaWearablesDat.setMockSpeechSource(
        uuid,
        MockSpeechSource.injected,
      );
      await MetaWearablesDat.startSpeech();
      await firstWhere(
        MetaWearablesDat.speechStateStream(),
        (s) => s == SpeechState.started,
      );
      final transcript = firstWhere(
        MetaWearablesDat.transcriptionStream(),
        (t) => t.text == 'hello glasses',
      );
      var received = false;
      unawaited(transcript.then((_) => received = true));
      // The mock only accepts injections once its recogniser is listening,
      // which can trail the `started` state slightly.
      await waitFor(() async {
        if (!received) {
          await MetaWearablesDat.simulateMockTranscription(
            uuid,
            'hello glasses',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return received;
      }, reason: 'transcription never arrived');
      expect((await transcript).isFinal, isTrue);

      // Voice
      await MetaWearablesDat.startVoiceInvocations(deviceUUID: uuid);
      final invocation = MetaWearablesDat.voiceInvocationsStream().first
          .timeout(const Duration(seconds: 30));
      var invoked = false;
      unawaited(invocation.then((_) => invoked = true));
      // The voice channel connects asynchronously after start; the mock
      // returns null until a client is connected.
      await waitFor(
        () async {
          if (!invoked) {
            await MetaWearablesDat.simulateMockVoiceInvocation(uuid);
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return invoked;
        },
        reason: 'voice invocation never arrived',
        timeout: const Duration(seconds: 30),
      );
      final launch = await invocation;
      expect(launch, isA<LaunchAppInvocation>());
      await launch.respondSuccess();
    },
  );
}
