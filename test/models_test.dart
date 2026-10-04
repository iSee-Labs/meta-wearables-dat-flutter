import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

void main() {
  test('DeviceInfo decodes every field and tolerates missing keys', () {
    final full = DeviceInfo.fromMap(const {
      'uuid': 'a',
      'name': 'Glasses',
      'kind': 'rayBanDisplay',
      'deviceType': 'metaRayBanDisplay',
      'linkState': 'connected',
      'compatibility': 'deviceUpdateRequired',
      'batteryLevel': 42,
      'chargingState': 'charging',
      'donState': 'doffed',
      'hingeState': 'closed',
      'thermalLevel': 'severe',
      'supportsDisplay': true,
      'isMock': true,
    });
    expect(full.type, DeviceType.metaRayBanDisplay);
    expect(full.kind, DeviceKind.rayBanDisplay);
    expect(full.compatibility, DeviceCompatibility.deviceUpdateRequired);
    expect(full.batteryLevel, 42);
    expect(full.chargingState, ChargingState.charging);
    expect(full.hingeState, HingeState.closed);
    expect(full.thermalLevel.isThrottling, isTrue);
    expect(full.thermalLevel.isCritical, isFalse);
    expect(full.supportsDisplay, isTrue);
    expect(full.isConnected, isTrue);

    final sparse = DeviceInfo.fromMap(const {'uuid': 'b'});
    expect(sparse.batteryLevel, isNull);
    expect(sparse.type, DeviceType.unknown);
    expect(sparse.linkState, LinkState.unknown);
    expect(sparse, DeviceInfo.fromMap(const {'uuid': 'b'}));
  });

  test('state enums decode wire strings with safe fallbacks', () {
    expect(DeviceSessionState.fromWire('paused'), DeviceSessionState.paused);
    expect(DeviceSessionState.fromWire(3), DeviceSessionState.idle);
    expect(CameraState.fromWire('started'), CameraState.started);
    expect(
      RegistrationState.fromWire('unregistering'),
      RegistrationState.unregistering,
    );
    expect(PermissionStatus.fromWire('granted').isGranted, isTrue);
    expect(PermissionStatus.fromWire(null), PermissionStatus.denied);
    expect(
      DisplayPlaybackEventType.fromWire('playing'),
      DisplayPlaybackEventType.started,
    );
    expect(
      DisplayPlaybackEventType.fromWire('ended'),
      DisplayPlaybackEventType.ended,
    );
  });

  test('StreamFrameRate only accepts SDK frame rates', () {
    expect(StreamFrameRate.fromFps(24), StreamFrameRate.fps24);
    expect(() => StreamFrameRate.fromFps(60), throwsArgumentError);
    expect(StreamQuality.fpsValues, StreamFrameRate.values.map((r) => r.value));
  });

  test('VideoFrame decodes raw I420, NV12 planes and hvc1', () {
    final i420 = VideoFrame.fromMap({
      'codec': 'raw',
      'pixelFormat': 'i420',
      'bytes': Uint8List(6),
      'width': 2,
      'height': 2,
      'ptsUs': 10,
      'isKeyframe': true,
    });
    expect(i420.pixelFormat, VideoPixelFormat.i420);
    final nv12 = VideoFrame.fromMap({
      'codec': 'raw',
      'pixelFormat': 'nv12',
      'bytes': Uint8List(6),
      'planes': [
        {'bytes': Uint8List(4), 'bytesPerRow': 2, 'width': 2, 'height': 2},
        {'bytes': Uint8List(2), 'bytesPerRow': 2, 'width': 1, 'height': 1},
      ],
      'width': 2,
      'height': 2,
    });
    expect(nv12.planes, hasLength(2));
    expect(nv12.planes.first.bytesPerRow, 2);
    final hevc = VideoFrame.fromMap({
      'codec': 'hvc1',
      'pixelFormat': 'i420',
      'bytes': Uint8List(3),
      'isKeyframe': false,
      'isCodecConfig': true,
    });
    expect(hevc.codec, VideoCodec.hvc1);
    expect(hevc.pixelFormat, VideoPixelFormat.unknown);
    expect(hevc.isCodecConfig, isTrue);
  });

  test('photo and audio models', () {
    const progress = PhotoTransferProgress(bytesReceived: 50, totalBytes: 200);
    expect(progress.fraction, 0.25);
    expect(
      const PhotoTransferProgress(bytesReceived: 5, totalBytes: 0).fraction,
      0,
    );
    final audio = AudioFrame.fromMap({'bytes': Uint8List(4), 'ptsUs': 1});
    expect(audio.bytes, hasLength(4));
  });

  test('BackgroundNotification serialises optional icon', () {
    const n = BackgroundNotification(
      title: 't',
      text: 'x',
      channelId: 'c',
      channelName: 'n',
    );
    expect(n.toMap().containsKey('iconResourceName'), isFalse);
  });

  test('MotionSample round-trips through toMap/fromMap', () {
    const sample = MotionSample(
      timestampNs: 7,
      accelerometer: Vector3(1, 2, 3),
      orientation: Quaternion(0, 0, 0, 1),
      source: MotionSource.neuralBand,
    );
    final decoded = MotionSample.fromMap(sample.toMap());
    expect(decoded.accelerometer!.z, 3);
    expect(decoded.source, MotionSource.neuralBand);
  });
}
