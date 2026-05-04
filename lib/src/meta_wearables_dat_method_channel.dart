import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_platform_interface.dart';
import 'package:meta_wearables_dat_flutter/src/models/dat_error.dart';
import 'package:meta_wearables_dat_flutter/src/models/device_info.dart';
import 'package:meta_wearables_dat_flutter/src/models/registration_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/session_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/video_stream_size.dart';

/// Default [MetaWearablesDatPlatform] implementation that forwards every call
/// across a single `MethodChannel` plus six topic-specific `EventChannel`s.
///
/// Method handlers are added slice by slice (slice 4 onward); until then,
/// every method call surfaces as a `MissingPluginException` from the native
/// stub. Stream getters are pure pass-throughs and emit no events until their
/// stream handlers are wired natively.
class MethodChannelMetaWearablesDat extends MetaWearablesDatPlatform {
  /// Method channel used for request/response calls.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    'meta_wearables_dat_flutter',
  );

  /// Event channel for [registrationStateStream].
  @visibleForTesting
  final EventChannel registrationStateChannel = const EventChannel(
    'meta_wearables_dat_flutter/registration_state',
  );

  /// Event channel for [activeDeviceStream].
  @visibleForTesting
  final EventChannel activeDeviceChannel = const EventChannel(
    'meta_wearables_dat_flutter/active_device',
  );

  /// Event channel for [sessionStateStream].
  @visibleForTesting
  final EventChannel sessionStateChannel = const EventChannel(
    'meta_wearables_dat_flutter/session_state',
  );

  /// Event channel for [sessionErrorStream].
  @visibleForTesting
  final EventChannel sessionErrorsChannel = const EventChannel(
    'meta_wearables_dat_flutter/session_errors',
  );

  /// Event channel for [videoStreamSizeStream].
  @visibleForTesting
  final EventChannel videoStreamSizeChannel = const EventChannel(
    'meta_wearables_dat_flutter/video_stream_size',
  );

  /// Event channel for [mockDevicesStream].
  @visibleForTesting
  final EventChannel mockDevicesChannel = const EventChannel(
    'meta_wearables_dat_flutter/mock_devices',
  );

  // Cached broadcast streams so multiple Dart-side listeners share a single
  // platform-channel subscription.
  Stream<RegistrationState>? _registrationStateStream;
  Stream<DeviceInfo?>? _activeDeviceStream;
  Stream<SessionState>? _sessionStateStream;
  Stream<Object>? _sessionErrorStream;
  Stream<VideoStreamSize>? _videoStreamSizeStream;
  Stream<List<DeviceInfo>>? _mockDevicesStream;

  // --- Diagnostics ----------------------------------------------------------

  @override
  Future<String?> getPlatformVersion() {
    return methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  // --- Permissions ----------------------------------------------------------

  @override
  Future<bool> requestAndroidPermissions() async {
    final granted = await methodChannel.invokeMethod<bool>(
      'requestAndroidPermissions',
    );
    return granted ?? false;
  }

  // --- Registration streams -------------------------------------------------

  @override
  Stream<RegistrationState> registrationStateStream() {
    return _registrationStateStream ??= registrationStateChannel
        .receiveBroadcastStream()
        .map((event) => RegistrationState.fromInt(event as int?));
  }

  @override
  Stream<DeviceInfo?> activeDeviceStream() {
    return _activeDeviceStream ??=
        activeDeviceChannel.receiveBroadcastStream().map((event) {
      if (event == null) return null;
      return DeviceInfo.fromMap(event as Map<Object?, Object?>);
    });
  }

  // --- Streaming streams ----------------------------------------------------

  @override
  Stream<SessionState> sessionStateStream() {
    return _sessionStateStream ??= sessionStateChannel
        .receiveBroadcastStream()
        .map((event) => SessionState.fromInt(event as int?));
  }

  @override
  Stream<Object> sessionErrorStream() {
    return _sessionErrorStream ??=
        sessionErrorsChannel.receiveBroadcastStream().map(_mapSessionError);
  }

  @override
  Stream<VideoStreamSize> videoStreamSizeStream() {
    return _videoStreamSizeStream ??= videoStreamSizeChannel
        .receiveBroadcastStream()
        .map((event) => VideoStreamSize.fromMap(event as Map<Object?, Object?>));
  }

  // --- Mock devices stream --------------------------------------------------

  @override
  Stream<List<DeviceInfo>> mockDevicesStream() {
    return _mockDevicesStream ??=
        mockDevicesChannel.receiveBroadcastStream().map((event) {
      final list = (event as List<Object?>?) ?? const [];
      return list
          .map((e) => DeviceInfo.fromMap(e! as Map<Object?, Object?>))
          .toList(growable: false);
    });
  }

  // --- Helpers --------------------------------------------------------------

  /// Maps a raw event from the `session_errors` channel to a typed
  /// [DatError] subclass, falling back to a base [DatError] for anything
  /// unrecognised.
  static DatError _mapSessionError(Object? event) {
    final map = event as Map<Object?, Object?>? ?? const {};
    final code = map['code'] as String? ?? DatErrorCodes.session;
    final message = map['message'] as String? ?? '';
    final details = map['details'];
    switch (code) {
      case DatErrorCodes.registration:
        return RegistrationError(
          code: code,
          message: message,
          details: details,
        );
      case DatErrorCodes.permission:
        return PermissionError(code: code, message: message, details: details);
      case DatErrorCodes.capture:
        return CaptureError(code: code, message: message, details: details);
      case DatErrorCodes.session:
        return SessionError(code: code, message: message, details: details);
      case _:
        return DatError(code: code, message: message, details: details);
    }
  }
}
