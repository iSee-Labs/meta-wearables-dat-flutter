// Model edge cases: every input event variant, legacy integer decoders,
// deprecated error shims, recovery actions and value formatting.

// ignore_for_file: deprecated_member_use_from_same_package, experimental_member_use

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
import 'package:meta_wearables_dat_flutter/src/error_mapping.dart';

DatError _error(String category, String code) =>
    DatErrorMapper.build(category, code, 'm', code, const {});

void main() {
  group('InputEvent.fromMap', () {
    InputEvent event(Map<String, Object?> map) =>
        InputEvent.fromMap({'source': 'captouch', 'timestampMs': 3, ...map});

    test('decodes every variant', () {
      expect(
        (event({'type': 'nav', 'direction': 'up'}) as NavInputEvent).direction,
        isA<NavDirection>(),
      );
      expect(event({'type': 'select'}), isA<SelectInputEvent>());
      expect(event({'type': 'back'}), isA<BackInputEvent>());
      expect(event({'type': 'button'}), isA<ButtonInputEvent>());
      final drag =
          event({
                'type': 'drag',
                'dragAction': 'move',
                'x': 1,
                'y': 2,
                'dx': 0.5,
                'dy': -0.5,
              })
              as DragInputEvent;
      expect((drag.x, drag.y, drag.dx, drag.dy), (1.0, 2.0, 0.5, -0.5));
      expect(drag.action, isA<DragAction>());
      final unknown = event({'type': 'telepathy'});
      expect(unknown, isA<UnknownInputEvent>());
      expect(unknown.source, InputSource.captouch);
      expect(unknown.timestampMs, 3);
    });

    test('unknown enum values fall back to unknown', () {
      expect(NavDirection.fromWire('sideways'), NavDirection.unknown);
      expect(DragAction.fromWire(null), DragAction.unknown);
    });
  });

  group('legacy integer state decoders', () {
    test('map ordinals and clamp out-of-range values', () {
      expect(RegistrationState.fromInt(3), RegistrationState.registered);
      expect(RegistrationState.fromInt(4), RegistrationState.unregistering);
      expect(RegistrationState.fromInt(2), RegistrationState.registering);
      expect(RegistrationState.fromInt(1), RegistrationState.available);
      expect(StreamSessionState.fromInt(0), StreamSessionState.values.first);
      expect(StreamSessionState.fromInt(99), isA<StreamSessionState>());
      expect(DeviceSessionState.fromInt(0), DeviceSessionState.values.first);
      expect(DeviceSessionState.fromInt(-1), isA<DeviceSessionState>());
      expect(DisplayState.fromInt(0), DisplayState.values.first);
      expect(DisplayState.fromInt(null), isA<DisplayState>());
    });
  });

  group('recovery actions', () {
    test('device session errors', () {
      DatRecoveryAction action(String code) =>
          (_error(DatErrorCodes.deviceSession, code) as DeviceSessionError)
              .recoveryAction;
      expect(
        action('datAppOnTheGlassesUpdateRequired'),
        DatRecoveryAction.openDatGlassesAppUpdate,
      );
      expect(action('dwaOutOfStuRange'), DatRecoveryAction.suggestUpdate);
      expect(action('startTimeout'), DatRecoveryAction.connectGlasses);
      expect(action('sessionIdle'), DatRecoveryAction.none);
    });

    test('stream and permission errors', () {
      DatRecoveryAction stream(String code) =>
          (_error(DatErrorCodes.stream, code) as StreamError).recoveryAction;
      expect(stream('permissionDenied'), DatRecoveryAction.grantPermission);
      expect(stream('hingesClosed'), DatRecoveryAction.connectGlasses);
      expect(stream('deviceNotFound'), DatRecoveryAction.connectGlasses);
      expect(stream('thermalHot'), DatRecoveryAction.none);

      final permission =
          _error(DatErrorCodes.permission, 'noDevice') as PermissionError;
      expect(permission.recoveryAction, DatRecoveryAction.connectGlasses);
      expect(
        (_error(DatErrorCodes.permission, 'internalError') as PermissionError)
            .recoveryAction,
        DatRecoveryAction.none,
      );
      expect(
        _error(DatErrorCodes.plugin, 'x').recoveryAction,
        DatRecoveryAction.none,
      );
    });
  });

  group('deprecated error getters keep working', () {
    test('stream', () {
      final e =
          _error(DatErrorCodes.stream, 'deviceNotConnected') as StreamError;
      expect(e.isDeviceDisconnected, isTrue);
      expect(e.isPermissionDenied, isFalse);
      expect(e.isTimeout, isFalse);
      expect(e.isInternalError, isFalse);
      expect(
        (_error(DatErrorCodes.stream, 'videoStreamingError') as StreamError)
            .isVideoStreamingError,
        isTrue,
      );
    });

    test('device session', () {
      final e =
          _error(DatErrorCodes.deviceSession, 'sessionIdle')
              as DeviceSessionError;
      expect(e.isSessionIdle, isTrue);
      expect(e.isSessionAlreadyStopped, isFalse);
      expect(e.isSessionAlreadyExists, isFalse);
      expect(e.isCapabilityAlreadyActive, isFalse);
      expect(e.isCapabilityNotFound, isFalse);
      expect(e.isUnexpectedError, isFalse);
    });

    test('registration, url, permission and capture', () {
      final reg =
          _error(DatErrorCodes.registration, 'networkUnavailable')
              as RegistrationError;
      expect(reg.isNetworkUnavailable, isTrue);
      expect(reg.isConfigurationInvalid, isFalse);
      expect(
        (_error(DatErrorCodes.handleUrl, 'invalidUrl') as HandleUrlError)
            .isInvalidUrl,
        isTrue,
      );
      final perm =
          _error(DatErrorCodes.permission, 'missingFragmentActivity')
              as PermissionError;
      expect(perm.isMissingFragmentActivity, isTrue);
      final capture =
          _error(DatErrorCodes.capture, 'captureFailed') as CaptureError;
      expect(capture.isCaptureFailed, isTrue);
      expect(capture.isDeviceDisconnected, isFalse);
    });
  });

  group('formatting and helpers', () {
    test('toString and derived values', () {
      expect(
        const VideoStreamSize(width: 720, height: 1280).toString(),
        'VideoStreamSize(720x1280)',
      );
      expect(
        const VideoStreamSize(width: 720, height: 1280).aspectRatio,
        closeTo(0.5625, 1e-9),
      );
      expect(const VideoStreamSize(width: 1, height: 0).aspectRatio, 0);
      expect(
        DeviceCompatibilityEvent.fromMap(const {
          'deviceUuid': 'd',
          'compatibility': 'compatible',
        }).toString(),
        contains('compatible'),
      );
      expect(
        RegistrationRequest.fromMap(const {'requestId': 'r'}).toString(),
        contains('r'),
      );
      expect(Permission.camera.value, 'camera');
      expect(PermissionStatus.granted.value, 'granted');
    });

    test('diagnostics findings', () {
      final diagnostics = DatDiagnostics.fromMap(const {
        'platform': 'android',
        'findings': [
          {'id': 'a', 'severity': 'error', 'message': 'bad', 'fix': 'f'},
          {'id': 'b', 'severity': 'warning', 'message': 'meh', 'fix': 'f'},
        ],
      });
      expect(diagnostics.errors.single.id, 'a');
      expect(diagnostics.findings.last.toString(), '[warning] b: meh');
    });

    test('bgra video frames', () {
      final frame = VideoFrame.fromMap(const {
        'codec': 'raw',
        'pixelFormat': 'bgra',
        'width': 1,
        'height': 1,
      });
      expect(frame.pixelFormat, VideoPixelFormat.bgra);
    });
  });
}
