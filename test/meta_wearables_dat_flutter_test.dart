import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_method_channel.dart';
import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _UnoverriddenPlatform extends MetaWearablesDatPlatform
    with MockPlatformInterfaceMixin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('models', () {
    test('DeviceInfo can be constructed and round-tripped through fromMap', () {
      const direct = DeviceInfo(
        uuid: 'abc',
        name: 'Ray-Ban Meta',
        kind: DeviceKind.rayBanMeta,
      );
      expect(direct.uuid, 'abc');
      expect(direct.kind, DeviceKind.rayBanMeta);

      final parsed = DeviceInfo.fromMap(<Object?, Object?>{
        'uuid': 'abc',
        'name': 'Ray-Ban Meta',
        'kind': 'rayBanMeta',
      });
      expect(parsed.uuid, 'abc');
      expect(parsed.kind, DeviceKind.rayBanMeta);
    });

    test('Enums map cleanly to and from platform-channel ints / strings', () {
      expect(RegistrationState.fromInt(3), RegistrationState.registered);
      expect(SessionState.fromInt(3), SessionState.streaming);
      expect(StreamQuality.high.width, 720);
      expect(StreamQuality.high.height, 1280);
      expect(StreamQuality.fpsValues, contains(30));
      expect(DeviceKind.fromRaw('unknown_value'), DeviceKind.unknown);
      expect(CameraFacing.front.value, 'front');
    });

    test('DatError subclasses preserve code and message', () {
      const err = SessionError(code: 'X', message: 'boom');
      expect(err, isA<DatError>());
      expect(err.code, 'X');
      expect(err.toString(), contains('SessionError'));
      expect(err.toString(), contains('boom'));
    });

    test('FrameData and PhotoResult hold their bytes', () {
      final frame = FrameData(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 4,
        height: 4,
        format: FrameFormat.rawRgba,
      );
      expect(frame.bytes.length, 3);
      expect(frame.format, FrameFormat.rawRgba);

      final photo = PhotoResult(
        bytes: Uint8List.fromList([0xff, 0xd8]),
        format: PhotoFormat.jpeg,
      );
      expect(photo.format, PhotoFormat.jpeg);
    });

    test('VideoStreamSize parses platform-channel maps', () {
      final size = VideoStreamSize.fromMap(<Object?, Object?>{
        'width': 720,
        'height': 1280,
      });
      expect(size.width, 720);
      expect(size.height, 1280);
      expect(size.toString(), 'VideoStreamSize(720x1280)');
    });
  });

  group('platform interface', () {
    test('default instance is the MethodChannel implementation', () {
      expect(
        MetaWearablesDatPlatform.instance,
        isInstanceOf<MethodChannelMetaWearablesDat>(),
      );
    });

    test('unimplemented members throw UnimplementedError', () {
      MetaWearablesDatPlatform.instance = _UnoverriddenPlatform();
      addTearDown(() {
        MetaWearablesDatPlatform.instance = MethodChannelMetaWearablesDat();
      });

      expect(
        MetaWearablesDat.requestAndroidPermissions,
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        MetaWearablesDat.startRegistration,
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => MetaWearablesDat.handleUrl('x'),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        MetaWearablesDat.startStreamSession,
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        MetaWearablesDat.capturePhoto,
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        MetaWearablesDat.enableMockDevice,
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
