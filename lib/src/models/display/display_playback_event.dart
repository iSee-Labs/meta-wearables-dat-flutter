/// Video playback transitions reported for a `VideoPlayer`.
enum DisplayPlaybackEventType {
  /// Playback started.
  started('started'),

  /// Android: playback paused.
  paused('paused'),

  /// Playback reached the end.
  ended('ended'),

  /// Playback was stopped.
  stopped('stopped'),

  /// Playback failed.
  error('error'),

  /// Not recognised.
  unknown('unknown');

  const DisplayPlaybackEventType(this.wireName);

  /// The wire name.
  final String wireName;

  /// Former name of [started].
  @Deprecated('Use started')
  static const DisplayPlaybackEventType playing = started;

  /// Parses the wire name; `playing` (pre-1.0) maps to [started].
  static DisplayPlaybackEventType fromWire(String? wire) {
    if (wire == 'playing') return started;
    for (final value in values) {
      if (value.wireName == wire) return value;
    }
    return unknown;
  }
}

/// A playback event for the `VideoPlayer` on screen.
class DisplayPlaybackEvent {
  /// Creates a [DisplayPlaybackEvent].
  const DisplayPlaybackEvent({required this.type});

  /// Decodes a `display_events` map.
  factory DisplayPlaybackEvent.fromMap(Map<Object?, Object?> map) =>
      DisplayPlaybackEvent(
        type: DisplayPlaybackEventType.fromWire(map['event'] as String?),
      );

  /// What happened.
  final DisplayPlaybackEventType type;

  @override
  String toString() => 'DisplayPlaybackEvent(${type.wireName})';
}
