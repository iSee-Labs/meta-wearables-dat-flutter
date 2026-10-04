import 'package:meta/meta.dart';

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// Where an input came from.
@experimental
enum InputSource {
  /// Glasses touchpad.
  captouch,

  /// Meta Neural Band.
  neuralBand,

  /// Capture button.
  captureButton,

  /// Action button.
  actionButton,

  /// Meta Neural Band drag.
  neuralBandDrag,

  /// Not recognised.
  unknown;

  /// Parses the wire name; unknown values map to [unknown].
  static InputSource fromWire(Object? raw) => _byName(values, raw, unknown);
}

/// Direction of a navigation input.
@experimental
enum NavDirection {
  /// Up.
  up,

  /// Down.
  down,

  /// Left.
  left,

  /// Right.
  right,

  /// Not recognised.
  unknown;

  /// Parses the wire name; unknown values map to [unknown].
  static NavDirection fromWire(Object? raw) => _byName(values, raw, unknown);
}

/// How the capture button was pressed.
@experimental
enum CapturePressType {
  /// Short press.
  shortPress,

  /// Press and hold.
  hold,

  /// Double press.
  doublePress,

  /// Not recognised.
  unknown;

  /// Parses the wire name; unknown values map to [unknown].
  static CapturePressType fromWire(Object? raw) =>
      _byName(values, raw, unknown);
}

/// Phase of a drag input.
@experimental
enum DragAction {
  /// Finger down.
  down,

  /// Moving.
  move,

  /// Finger up.
  up,

  /// Not recognised.
  unknown;

  /// Parses the wire name; unknown values map to [unknown].
  static DragAction fromWire(Object? raw) => _byName(values, raw, unknown);
}

/// State of the experimental Inputs capability.
@experimental
enum InputsState {
  /// Not active.
  inactive,

  /// Activating.
  activating,

  /// Delivering events.
  active,

  /// Deactivating.
  deactivating;

  /// Parses the wire name; unknown values map to [inactive].
  static InputsState fromWire(Object? raw) => _byName(values, raw, inactive);
}

/// Settings for `MetaWearablesDat.startInputs`.
@experimental
class InputsConfiguration {
  /// Creates an [InputsConfiguration]. An empty [sources] set means all
  /// sources.
  const InputsConfiguration({
    this.sources = const <InputSource>{},
    this.consumeBack = true,
  });

  /// Sources to receive events from.
  final Set<InputSource> sources;

  /// Whether Back events are delivered to the app instead of the system.
  final bool consumeBack;

  /// Platform-channel encoding.
  Map<String, Object?> toMap() => {
    'sources': sources
        .where((s) => s != InputSource.unknown)
        .map((s) => s.name)
        .toList(growable: false),
    'consumeBack': consumeBack,
  };
}

/// An input from the glasses or the Meta Neural Band.
///
/// **Experimental:** cannot be used in apps on production release channels.
@experimental
sealed class InputEvent {
  const InputEvent({required this.source, required this.timestampMs});

  /// Decodes a platform-channel map.
  factory InputEvent.fromMap(Map<Object?, Object?> map) {
    final source = InputSource.fromWire(map['source']);
    final ts = (map['timestampMs'] as num?)?.toInt() ?? 0;
    double d(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return switch (map['type']) {
      'nav' => NavInputEvent(
        direction: NavDirection.fromWire(map['direction']),
        source: source,
        timestampMs: ts,
      ),
      'select' => SelectInputEvent(source: source, timestampMs: ts),
      'back' => BackInputEvent(source: source, timestampMs: ts),
      'button' => ButtonInputEvent(source: source, timestampMs: ts),
      'capture' => CaptureInputEvent(
        pressType: CapturePressType.fromWire(map['pressType']),
        source: source,
        timestampMs: ts,
      ),
      'drag' => DragInputEvent(
        action: DragAction.fromWire(map['dragAction']),
        x: d('x'),
        y: d('y'),
        dx: d('dx'),
        dy: d('dy'),
        source: source,
        timestampMs: ts,
      ),
      _ => UnknownInputEvent(source: source, timestampMs: ts),
    };
  }

  /// Where the input came from.
  final InputSource source;

  /// Event time in milliseconds.
  final int timestampMs;
}

/// Navigation (swipe) input.
@experimental
final class NavInputEvent extends InputEvent {
  /// Creates a [NavInputEvent].
  const NavInputEvent({
    required this.direction,
    required super.source,
    required super.timestampMs,
  });

  /// Direction.
  final NavDirection direction;
}

/// Select (tap) input.
@experimental
final class SelectInputEvent extends InputEvent {
  /// Creates a [SelectInputEvent].
  const SelectInputEvent({required super.source, required super.timestampMs});
}

/// Back input. Not yet delivered by real glasses.
@experimental
final class BackInputEvent extends InputEvent {
  /// Creates a [BackInputEvent].
  const BackInputEvent({required super.source, required super.timestampMs});
}

/// Action-button input.
@experimental
final class ButtonInputEvent extends InputEvent {
  /// Creates a [ButtonInputEvent].
  const ButtonInputEvent({required super.source, required super.timestampMs});
}

/// Capture-button input.
@experimental
final class CaptureInputEvent extends InputEvent {
  /// Creates a [CaptureInputEvent].
  const CaptureInputEvent({
    required this.pressType,
    required super.source,
    required super.timestampMs,
  });

  /// How the button was pressed.
  final CapturePressType pressType;
}

/// Drag input from the Meta Neural Band.
@experimental
final class DragInputEvent extends InputEvent {
  /// Creates a [DragInputEvent].
  const DragInputEvent({
    required this.action,
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required super.source,
    required super.timestampMs,
  });

  /// Phase of the drag.
  final DragAction action;

  /// Position x.
  final double x;

  /// Position y.
  final double y;

  /// Delta x since the previous event.
  final double dx;

  /// Delta y since the previous event.
  final double dy;
}

/// An input type this plugin version does not recognise.
@experimental
final class UnknownInputEvent extends InputEvent {
  /// Creates an [UnknownInputEvent].
  const UnknownInputEvent({required super.source, required super.timestampMs});
}
