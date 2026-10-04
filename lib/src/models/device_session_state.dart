/// State of the device session shared by camera, display and the
/// experimental capabilities.
enum DeviceSessionState {
  /// Created, not started.
  idle,

  /// Connecting to the glasses.
  starting,

  /// Running.
  started,

  /// Paused by the device (for example the glasses were taken off).
  paused,

  /// Stopping.
  stopping,

  /// Stopped. A new session is created on the next start.
  stopped;

  /// Parses the wire name; unknown values map to [idle].
  static DeviceSessionState fromWire(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return idle;
  }

  /// Parses the integer encoding used before 1.0.
  @Deprecated('State now travels as a string; use fromWire')
  static DeviceSessionState fromInt(int? value) =>
      value != null && value >= 0 && value < values.length
      ? values[value]
      : idle;
}
