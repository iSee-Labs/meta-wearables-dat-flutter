import 'package:flutter/services.dart';
import 'package:meta_wearables_dat_flutter/src/models/dat_error.dart';

/// Decodes platform errors into the typed [DatError] hierarchy.
///
/// Wire shapes:
///  * method calls: `PlatformException(code: CATEGORY, message, details:
///    {case, description, platformCase, platform, ...})`
///  * events: `{code: case, category, message, platformCase, platform, ...}`
abstract final class DatErrorMapper {
  /// Maps a [PlatformException] from a method call.
  static DatError fromPlatformException(PlatformException e) {
    final details = _stringKeyed(e.details);
    final code = details['case'] as String? ?? _legacyCase(e);
    final message = e.message ?? details['description'] as String? ?? '';
    return build(
      e.code,
      code,
      message,
      details['platformCase'] as String?,
      details,
    );
  }

  /// Maps an event-channel error payload. [defaultCategory] is used when the
  /// payload carries no `category`.
  static DatError fromEvent(Object? event, {required String defaultCategory}) {
    final map = _stringKeyed(event);
    return build(
      map['category'] as String? ?? defaultCategory,
      map['code'] as String?,
      map['message'] as String? ?? '',
      map['platformCase'] as String?,
      map,
    );
  }

  /// Builds the typed error for [category] and canonical [code].
  static DatError build(
    String category,
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) {
    switch (category) {
      case DatErrorCodes.registration:
        return RegistrationError.fromWire(code, message, platformCase, details);
      case DatErrorCodes.unregistration:
        return UnregistrationError.fromWire(
          code,
          message,
          platformCase,
          details,
        );
      case DatErrorCodes.handleUrl:
        return HandleUrlError.fromWire(code, message, platformCase, details);
      case DatErrorCodes.registrationRequest:
        return RegistrationRequestError.fromWire(
          code,
          message,
          platformCase,
          details,
        );
      case DatErrorCodes.permission:
        return PermissionError.fromWire(code, message, platformCase, details);
      case 'MISSING_FRAGMENT_ACTIVITY':
        return PermissionError.fromWire(
          'missingFragmentActivity',
          message,
          platformCase,
          details,
        );
      case DatErrorCodes.navigation:
        return NavigationError.fromWire(code, message, platformCase, details);
      case DatErrorCodes.deviceSession:
        return DeviceSessionError.fromWire(
          code,
          message,
          platformCase,
          details,
        );
      case DatErrorCodes.stream:
      case 'SESSION_ERROR':
        return StreamError.fromWire(code, message, platformCase, details);
      case DatErrorCodes.capture:
        return CaptureError.fromWire(code, message, platformCase, details);
      case DatErrorCodes.photo:
        return PhotoError.fromWire(code, message, platformCase, details);
      case DatErrorCodes.display:
        return DisplayError.fromWire(code, message, platformCase, details);
      case DatErrorCodes.inputs:
        return InputsError.fromWire(code, message, platformCase, details);
      case DatErrorCodes.motion:
        return MotionError.fromWire(code, message, platformCase, details);
      case DatErrorCodes.speech:
        return SpeechError.fromWire(code, message, platformCase, details);
      case DatErrorCodes.voiceInvocation:
        return VoiceInvocationError.fromWire(
          code,
          message,
          platformCase,
          details,
        );
      case DatErrorCodes.mock:
        return MockDeviceKitError.fromWire(
          code,
          message,
          platformCase,
          details,
        );
      case DatErrorCodes.invalidArgument:
        return DatArgumentError(message: message, details: details);
      default:
        return DatPluginError(
          code: code ?? 'unknown',
          message: message,
          category: category,
          platformCase: platformCase,
          details: details,
        );
    }
  }

  /// Pre-1.0 natives put the case name in `message`.
  static String? _legacyCase(PlatformException e) {
    final message = e.message;
    if (message == null || message.contains(' ')) return null;
    return message.split('(').first;
  }

  static Map<String, Object?> _stringKeyed(Object? raw) {
    if (raw is! Map) return <String, Object?>{};
    return raw.map(
      (key, value) =>
          MapEntry(key.toString(), value is Map ? _stringKeyed(value) : value),
    );
  }
}
