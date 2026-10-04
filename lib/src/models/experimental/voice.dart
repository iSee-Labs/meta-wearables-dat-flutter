import 'package:meta/meta.dart';
import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_platform_interface.dart';

/// State of the experimental voice invocations stream.
@experimental
enum VoiceInvocationsState {
  /// Starting.
  starting,

  /// Listening for invocations.
  started,

  /// Stopped.
  stopped;

  /// Parses the wire name; unknown values map to [stopped].
  static VoiceInvocationsState fromWire(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return stopped;
  }
}

/// A "Hey Meta" voice request directed at this app.
///
/// Answer every invocation exactly once with [respondSuccess] or
/// [respondFailure]; unanswered invocations are failed when the stream stops.
///
/// **Experimental:** cannot be used in apps on production release channels.
/// Needs the Voice Invocation permission approved in Wearables Developer
/// Center.
@experimental
sealed class VoiceInvocation {
  VoiceInvocation({required this.invocationId, this.deviceUuid});

  /// Decodes a platform-channel map.
  factory VoiceInvocation.fromMap(Map<Object?, Object?> map) =>
      switch (map['type']) {
        _ => LaunchAppInvocation(
          invocationId: map['invocationId'] as String? ?? '',
          deviceUuid: map['deviceUuid'] as String?,
        ),
      };

  /// Plugin-assigned id.
  final String invocationId;

  /// The device that sent the invocation, when reported.
  final String? deviceUuid;

  bool _responded = false;

  /// Whether this invocation was answered.
  bool get isResponded => _responded;

  /// Reports success to the glasses. Returns whether the glasses received it.
  Future<bool> respondSuccess({String? actionOutput}) =>
      _respond(true, actionOutput);

  /// Reports failure to the glasses. Returns whether the glasses received it.
  Future<bool> respondFailure({String? actionOutput}) =>
      _respond(false, actionOutput);

  Future<bool> _respond(bool success, String? actionOutput) {
    if (_responded) {
      throw StateError('Voice invocation $invocationId was already answered.');
    }
    _responded = true;
    return MetaWearablesDatPlatform.instance.respondVoiceInvocation(
      invocationId,
      success: success,
      actionOutput: actionOutput,
    );
  }
}

/// "Hey Meta, open `app`".
@experimental
final class LaunchAppInvocation extends VoiceInvocation {
  /// Creates a [LaunchAppInvocation].
  LaunchAppInvocation({required super.invocationId, super.deviceUuid});
}
