import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_platform_interface.dart';

/// Registration state of this app with the Meta AI app.
enum RegistrationState {
  /// Registration is not possible (SDK not initialised or Meta AI missing).
  unavailable,

  /// The app can register.
  available,

  /// Registration is in progress.
  registering,

  /// The app is registered.
  registered,

  /// Android: unregistration is in progress.
  unregistering;

  /// Parses the wire name; unknown values map to [unavailable].
  static RegistrationState fromWire(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return unavailable;
  }

  /// Parses the integer encoding used before 1.0.
  @Deprecated('State now travels as a string; use fromWire')
  static RegistrationState fromInt(int? value) => switch (value) {
    1 => available,
    2 => registering,
    3 => registered,
    4 => unregistering,
    _ => unavailable,
  };
}

/// A registration started from the Meta AI app (DAT 1.0).
///
/// Delivered by `MetaWearablesDat.registrationRequestStream()`. Answer it
/// exactly once with [continueRegistration] or [cancel]; unanswered requests
/// expire after five minutes.
class RegistrationRequest {
  /// Creates a [RegistrationRequest].
  RegistrationRequest({
    required this.requestId,
    this.flowId,
    this.protocolVersion,
  });

  /// Decodes a platform-channel map.
  factory RegistrationRequest.fromMap(Map<Object?, Object?> map) =>
      RegistrationRequest(
        requestId: map['requestId'] as String? ?? '',
        flowId: map['flowId'] as String?,
        protocolVersion: (map['protocolVersion'] as num?)?.toInt(),
      );

  /// Plugin-assigned id of this request.
  final String requestId;

  /// Meta's flow id, for diagnostics.
  final String? flowId;

  /// Meta's protocol version, for diagnostics.
  final int? protocolVersion;

  bool _handled = false;

  /// Whether this request was already answered.
  bool get isHandled => _handled;

  /// Accepts the request and continues registration in the Meta AI app.
  ///
  /// Throws a `RegistrationRequestError` on failure, or a [StateError] when
  /// the request was already answered.
  Future<void> continueRegistration() {
    _markHandled();
    return MetaWearablesDatPlatform.instance.answerRegistrationRequest(
      requestId,
      accept: true,
    );
  }

  /// Declines the request.
  Future<void> cancel() {
    _markHandled();
    return MetaWearablesDatPlatform.instance.answerRegistrationRequest(
      requestId,
      accept: false,
    );
  }

  void _markHandled() {
    if (_handled) {
      throw StateError('Registration request $requestId was already answered.');
    }
    _handled = true;
  }

  @override
  String toString() => 'RegistrationRequest($requestId, flowId: $flowId)';
}
