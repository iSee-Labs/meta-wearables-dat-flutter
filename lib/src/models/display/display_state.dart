/// State of the display capability.
enum DisplayState {
  /// Starting.
  starting,

  /// Ready to receive views.
  started,

  /// Stopping.
  stopping,

  /// Stopped (also after the user pressed Back on the glasses).
  stopped;

  /// Parses the wire name; unknown values map to [stopped].
  static DisplayState fromWire(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return stopped;
  }

  /// Parses the integer encoding used before 1.0.
  @Deprecated('State now travels as a string; use fromWire')
  static DisplayState fromInt(int? value) =>
      value != null && value >= 0 && value < values.length
      ? values[value]
      : stopped;
}
