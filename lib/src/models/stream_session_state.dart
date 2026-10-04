/// State of the camera stream.
enum StreamSessionState {
  /// Not streaming.
  stopped,

  /// Waiting for the glasses (iOS).
  waitingForDevice,

  /// Starting.
  starting,

  /// Frames are flowing.
  streaming,

  /// Paused by the device (captouch tap, glasses taken off).
  paused,

  /// Stopping.
  stopping;

  /// Parses the wire name; unknown values map to [stopped].
  static StreamSessionState fromWire(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return stopped;
  }

  /// Parses the integer encoding used before 1.0.
  @Deprecated('State now travels as a string; use fromWire')
  static StreamSessionState fromInt(int? value) =>
      value != null && value >= 0 && value < values.length
      ? values[value]
      : stopped;
}

/// State of the camera capability that owns the stream.
enum CameraState {
  /// Starting.
  starting,

  /// Started.
  started,

  /// Stopping.
  stopping,

  /// Stopped.
  stopped;

  /// Parses the wire name; unknown values map to [stopped].
  static CameraState fromWire(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return stopped;
  }
}
