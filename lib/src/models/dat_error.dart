/// Base class for all errors raised by `meta_wearables_dat_flutter`.
///
/// The plugin maps native [PlatformException]s with known DAT codes to one of
/// the four typed subclasses ([RegistrationError], [PermissionError],
/// [SessionError], [CaptureError]) so host apps can `try` / `on` against the
/// concrete category. Anything the plugin does not recognise is surfaced as
/// the base [DatError].
class DatError implements Exception {
  /// Creates a [DatError].
  const DatError({
    required this.code,
    required this.message,
    this.details,
  });

  /// Machine-readable code, mirroring the upstream SDK's error category.
  final String code;

  /// Human-readable message. Safe to show to developers; not safe to show
  /// to end users without translation.
  final String message;

  /// Optional structured payload that accompanies some errors.
  final Object? details;

  @override
  String toString() => 'DatError(code: $code, message: $message)';
}

/// An error raised by the registration flow
/// ([MetaWearablesDat.startRegistration],
/// [MetaWearablesDat.startUnregistration], [MetaWearablesDat.handleUrl]).
class RegistrationError extends DatError {
  /// Creates a [RegistrationError].
  const RegistrationError({
    required super.code,
    required super.message,
    super.details,
  });

  @override
  String toString() => 'RegistrationError(code: $code, message: $message)';
}

/// An error raised when a permission cannot be requested or has been denied.
///
/// Includes both Android runtime permissions (Bluetooth, Internet) and the
/// Meta-AI-bottom-sheet-driven on-device camera permission.
class PermissionError extends DatError {
  /// Creates a [PermissionError].
  const PermissionError({
    required super.code,
    required super.message,
    super.details,
  });

  @override
  String toString() => 'PermissionError(code: $code, message: $message)';
}

/// An error raised by a streaming session
/// ([MetaWearablesDat.startStreamSession],
/// [MetaWearablesDat.stopStreamSession], etc.).
class SessionError extends DatError {
  /// Creates a [SessionError].
  const SessionError({
    required super.code,
    required super.message,
    super.details,
  });

  @override
  String toString() => 'SessionError(code: $code, message: $message)';
}

/// An error raised by a still-capture call ([MetaWearablesDat.capturePhoto]
/// or [MetaWearablesDat.captureStreamFrame]).
class CaptureError extends DatError {
  /// Creates a [CaptureError].
  const CaptureError({
    required super.code,
    required super.message,
    super.details,
  });

  @override
  String toString() => 'CaptureError(code: $code, message: $message)';
}

/// Well-known error codes used by [DatError.code]. Mirrors the categories
/// emitted by Meta's iOS `StreamSessionError` / `CaptureError` and the
/// Android equivalents.
abstract final class DatErrorCodes {
  /// The registration flow could not be started or completed.
  static const String registration = 'REGISTRATION_ERROR';

  /// A wearable-side permission (e.g. camera) is not granted.
  static const String permission = 'PERMISSION_ERROR';

  /// A streaming session failed to start, was interrupted, or could not
  /// be torn down cleanly.
  static const String session = 'SESSION_ERROR';

  /// A photo or frame capture failed.
  static const String capture = 'CAPTURE_ERROR';

  /// The Android host activity does not extend `FlutterFragmentActivity` /
  /// `ComponentActivity`. Required for the registration deep-link callback
  /// and `Wearables.RequestPermissionContract`.
  static const String missingFragmentActivity = 'MISSING_FRAGMENT_ACTIVITY';
}
