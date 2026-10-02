// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
import 'package:meta_wearables_dat_flutter/src/error_mapping.dart';

PlatformException _wire(
  String category,
  String caseName, {
  Map<String, Object?> extra = const {},
}) => PlatformException(
  code: category,
  message: 'msg $caseName',
  details: {
    'case': caseName,
    'description': 'msg $caseName',
    'platformCase': 'RAW',
    'platform': 'ios',
    ...extra,
  },
);

void main() {
  group('DatErrorMapper.fromPlatformException', () {
    final cases = <String, (List<Enum>, Type)>{
      DatErrorCodes.registration: (
        RegistrationErrorCase.values,
        RegistrationError,
      ),
      DatErrorCodes.unregistration: (
        UnregistrationErrorCase.values,
        UnregistrationError,
      ),
      DatErrorCodes.handleUrl: (HandleUrlErrorCase.values, HandleUrlError),
      DatErrorCodes.registrationRequest: (
        RegistrationRequestErrorCase.values,
        RegistrationRequestError,
      ),
      DatErrorCodes.permission: (PermissionErrorCase.values, PermissionError),
      DatErrorCodes.navigation: (NavigationErrorCase.values, NavigationError),
      DatErrorCodes.deviceSession: (
        DeviceSessionErrorCase.values,
        DeviceSessionError,
      ),
      DatErrorCodes.stream: (StreamErrorCase.values, StreamError),
      DatErrorCodes.capture: (CaptureErrorCase.values, CaptureError),
      DatErrorCodes.photo: (PhotoErrorCase.values, PhotoError),
      DatErrorCodes.display: (DisplayErrorCase.values, DisplayError),
      DatErrorCodes.inputs: (InputsErrorCase.values, InputsError),
      DatErrorCodes.motion: (MotionErrorCase.values, MotionError),
      DatErrorCodes.speech: (SpeechErrorCase.values, SpeechError),
      DatErrorCodes.voiceInvocation: (
        VoiceInvocationErrorCase.values,
        VoiceInvocationError,
      ),
      DatErrorCodes.mock: (MockDeviceKitErrorCase.values, MockDeviceKitError),
    };

    for (final entry in cases.entries) {
      final (values, type) = entry.value;
      test('${entry.key} decodes every case into $type', () {
        for (final value in values) {
          final error = DatErrorMapper.fromPlatformException(
            _wire(entry.key, value.name),
          );
          expect(error.runtimeType, type);
          expect(error.category, entry.key);
          expect(error.code, value.name);
          expect(error.message, 'msg ${value.name}');
          expect(error.platformCase, 'RAW');
          expect(error.platform, 'ios');
        }
      });

      test('${entry.key} maps an unknown case to unknown', () {
        final error = DatErrorMapper.fromPlatformException(
          _wire(entry.key, 'somethingNew'),
        );
        expect(error.code, 'unknown');
        expect(error.platformCase, 'RAW');
      });
    }

    test('pre-1.0 SESSION_ERROR maps to StreamError', () {
      final error = DatErrorMapper.fromPlatformException(
        _wire('SESSION_ERROR', 'hingesClosed'),
      );
      expect(
        error,
        isA<StreamError>().having(
          (e) => e.reason,
          'reason',
          StreamErrorCase.hingesClosed,
        ),
      );
    });

    test('MISSING_FRAGMENT_ACTIVITY maps to PermissionError', () {
      final error = DatErrorMapper.fromPlatformException(
        PlatformException(
          code: 'MISSING_FRAGMENT_ACTIVITY',
          message: 'needs FlutterFragmentActivity',
        ),
      );
      expect(error, isA<PermissionError>());
      expect(
        (error as PermissionError).reason,
        PermissionErrorCase.missingFragmentActivity,
      );
    });

    test('INVALID_ARGUMENT maps to DatArgumentError', () {
      final error = DatErrorMapper.fromPlatformException(
        PlatformException(
          code: 'INVALID_ARGUMENT',
          message: 'fps must be one of',
        ),
      );
      expect(
        error,
        isA<DatArgumentError>().having(
          (e) => e.code,
          'code',
          'invalidArgument',
        ),
      );
    });

    test('unknown categories become DatPluginError with the case as code', () {
      final error = DatErrorMapper.fromPlatformException(
        _wire('PLUGIN_ERROR', 'wearablesNotConfigured'),
      );
      expect(
        error,
        isA<DatPluginError>().having(
          (e) => e.code,
          'code',
          'wearablesNotConfigured',
        ),
      );
      final notLinked = DatErrorMapper.fromPlatformException(
        _wire('EXPERIMENTAL_NOT_LINKED', 'notLinked'),
      );
      expect((notLinked as DatPluginError).isExperimentalNotLinked, isTrue);
    });

    test('legacy payloads with the case in message still decode', () {
      final error = DatErrorMapper.fromPlatformException(
        PlatformException(
          code: DatErrorCodes.registration,
          message: 'metaAINotInstalled',
        ),
      );
      expect(
        (error as RegistrationError).reason,
        RegistrationErrorCase.metaAINotInstalled,
      );
    });
  });

  group('DatErrorMapper.fromEvent', () {
    test('uses the category from the payload', () {
      final error = DatErrorMapper.fromEvent({
        'code': 'insufficientSDKVersion',
        'category': DatErrorCodes.deviceSession,
        'message': 'update',
        'terminal': true,
        'severity': 'error',
      }, defaultCategory: DatErrorCodes.stream);
      expect(error, isA<DeviceSessionError>());
    });

    test('falls back to the channel category', () {
      final error = DatErrorMapper.fromEvent({
        'code': 'thermalHot',
        'message': 'hot',
      }, defaultCategory: DatErrorCodes.stream);
      expect(
        error,
        isA<StreamError>().having(
          (e) => e.reason,
          'reason',
          StreamErrorCase.thermalHot,
        ),
      );
    });
  });

  group('severity and recovery helpers', () {
    DeviceSessionError session(
      DeviceSessionErrorCase reason, [
      Map<String, Object?> details = const {},
    ]) => DeviceSessionError(reason: reason, message: '', details: details);

    test('insufficientSDKVersion is terminal and asks for a new app build', () {
      final e = session(DeviceSessionErrorCase.insufficientSDKVersion);
      expect(e.isTerminal, isTrue);
      expect(e.isWarning, isFalse);
      expect(e.recoveryAction, DatRecoveryAction.updateHostApp);
    });

    test('dwaOutOfStuRange is a non-blocking warning', () {
      final e = session(DeviceSessionErrorCase.dwaOutOfStuRange);
      expect(e.isTerminal, isFalse);
      expect(e.isWarning, isTrue);
      expect(e.recoveryAction, DatRecoveryAction.suggestUpdate);
    });

    test('version errors map to Meta handling actions', () {
      expect(
        session(
          DeviceSessionErrorCase.datAppOnTheGlassesUpdateRequired,
        ).recoveryAction,
        DatRecoveryAction.openDatGlassesAppUpdate,
      );
      expect(
        session(DeviceSessionErrorCase.dwaUnavailable).recoveryAction,
        DatRecoveryAction.checkMetaAiAndRetry,
      );
      expect(
        session(DeviceSessionErrorCase.noEligibleDevice).recoveryAction,
        DatRecoveryAction.connectGlasses,
      );
    });

    test('stream fatal and warning flags come from details', () {
      const fatal = StreamError(
        reason: StreamErrorCase.videoStreamingError,
        message: '',
        details: {'fatal': true},
      );
      const warning = StreamError(
        reason: StreamErrorCase.rawPausedInBackground,
        message: '',
        details: {'severity': 'warning'},
      );
      expect(fatal.isFatal, isTrue);
      expect(warning.isWarning, isTrue);
      expect(warning.isFatal, isFalse);
    });

    test('a switch over DatError is exhaustive', () {
      String describe(DatError e) => switch (e) {
        RegistrationError() => 'reg',
        UnregistrationError() => 'unreg',
        HandleUrlError() => 'url',
        RegistrationRequestError() => 'req',
        PermissionError() => 'perm',
        NavigationError() => 'nav',
        DeviceSessionError() => 'session',
        StreamError() => 'stream',
        CaptureError() => 'capture',
        PhotoError() => 'photo',
        DisplayError() => 'display',
        InputsError() => 'inputs',
        MotionError() => 'motion',
        SpeechError() => 'speech',
        VoiceInvocationError() => 'voice',
        MockDeviceKitError() => 'mock',
        DatArgumentError() => 'arg',
        DatPluginError() => 'plugin',
      };
      expect(describe(const DatArgumentError(message: 'x')), 'arg');
    });
  });

  group('deprecated getters keep working', () {
    test('RegistrationError', () {
      const e = RegistrationError(
        reason: RegistrationErrorCase.metaAINotInstalled,
        message: '',
      );
      expect(e.isMetaAiNotInstalled, isTrue);
      expect(e.isAlreadyRegistered, isFalse);
    });

    test('UnregistrationError', () {
      const e = UnregistrationError(
        reason: UnregistrationErrorCase.alreadyUnregistered,
        message: '',
      );
      expect(e.isNotRegistered, isTrue);
    });

    test('DeviceSessionError', () {
      const e = DeviceSessionError(
        reason: DeviceSessionErrorCase.datAppOnTheGlassesUpdateRequired,
        message: '',
      );
      expect(e.isDatAppUpdateRequired, isTrue);
      expect(e.isNoEligibleDevice, isFalse);
    });

    test('StreamError (SessionError)', () {
      const e = StreamError(reason: StreamErrorCase.thermalHot, message: '');
      expect(e.isThermalCritical, isTrue);
      expect(e.isHingesClosed, isFalse);
    });

    test('CaptureError', () {
      const e = CaptureError(
        reason: CaptureErrorCase.notStreaming,
        message: '',
      );
      expect(e.isNotStreaming, isTrue);
      expect(e.isCaptureInProgress, isFalse);
    });
  });
}
