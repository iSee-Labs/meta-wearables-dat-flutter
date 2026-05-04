/// State of an active streaming session.
///
/// Surfaced by [MetaWearablesDat.sessionStateStream]. Mirrors the underlying
/// `StreamSessionState` from Meta's DAT SDKs.
enum SessionState {
  /// No session is active.
  stopped(0),

  /// The session has been requested but the SDK is still waiting for the
  /// device to be ready (e.g. paired but not yet connected).
  waitingForDevice(1),

  /// The session has been opened and is configuring the stream.
  starting(2),

  /// Frames are flowing.
  streaming(3),

  /// The session is paused. Pauses can be initiated by the SDK (thermal,
  /// hinges closed, app backgrounded) and may not be triggerable from the
  /// host app on every device generation.
  paused(4),

  /// The session is being torn down.
  stopping(5);

  const SessionState(this.value);

  /// The integer used on the platform channel.
  final int value;

  /// Maps a platform-channel integer to a [SessionState].
  static SessionState fromInt(int? value) {
    switch (value) {
      case 0:
        return SessionState.stopped;
      case 1:
        return SessionState.waitingForDevice;
      case 2:
        return SessionState.starting;
      case 3:
        return SessionState.streaming;
      case 4:
        return SessionState.paused;
      case 5:
        return SessionState.stopping;
      case _:
        return SessionState.stopped;
    }
  }
}
