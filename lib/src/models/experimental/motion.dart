import 'package:meta/meta.dart';

/// Motion sampling rates. The SDK default is [hz10].
@experimental
enum MotionSamplingRate {
  /// 5 Hz.
  hz5(5),

  /// 10 Hz.
  hz10(10),

  /// 15 Hz.
  hz15(15),

  /// 24 Hz.
  hz24(24),

  /// 30 Hz.
  hz30(30),

  /// 60 Hz.
  hz60(60);

  const MotionSamplingRate(this.value);

  /// Samples per second.
  final int value;
}

/// Device that produced a [MotionSample].
@experimental
enum MotionSource {
  /// The glasses.
  glasses,

  /// The Meta Neural Band.
  neuralBand,

  /// Not reported.
  unknown;

  /// Parses the wire name; unknown values map to [unknown].
  static MotionSource fromWire(Object? raw) => switch (raw) {
    'glasses' => glasses,
    'neuralBand' => neuralBand,
    _ => unknown,
  };
}

/// State of the experimental Motion capability.
@experimental
enum MotionState {
  /// Stopped.
  stopped,

  /// Starting.
  starting,

  /// Delivering samples.
  started,

  /// Stopping.
  stopping,

  /// Android: paused while the session is paused; resumes automatically.
  paused;

  /// Parses the wire name; unknown values map to [stopped].
  static MotionState fromWire(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return stopped;
  }
}

/// A 3D vector.
@experimental
class Vector3 {
  /// Creates a [Vector3].
  const Vector3(this.x, this.y, this.z);

  /// Decodes a platform-channel map.
  static Vector3? fromMap(Object? raw) {
    if (raw is! Map<Object?, Object?>) return null;
    double v(String k) => (raw[k] as num?)?.toDouble() ?? 0;
    return Vector3(v('x'), v('y'), v('z'));
  }

  /// X component.
  final double x;

  /// Y component.
  final double y;

  /// Z component.
  final double z;

  /// Platform-channel encoding.
  Map<String, double> toMap() => {'x': x, 'y': y, 'z': z};
}

/// An orientation quaternion.
@experimental
class Quaternion {
  /// Creates a [Quaternion].
  const Quaternion(this.x, this.y, this.z, this.w);

  /// Decodes a platform-channel map.
  static Quaternion? fromMap(Object? raw) {
    if (raw is! Map<Object?, Object?>) return null;
    double v(String k, [double fallback = 0]) =>
        (raw[k] as num?)?.toDouble() ?? fallback;
    return Quaternion(v('x'), v('y'), v('z'), v('w', 1));
  }

  /// X component.
  final double x;

  /// Y component.
  final double y;

  /// Z component.
  final double z;

  /// W component.
  final double w;

  /// Platform-channel encoding.
  Map<String, double> toMap() => {'x': x, 'y': y, 'z': z, 'w': w};
}

/// One motion sample. Each sensor is optional; for example Ray-Ban Meta
/// has no magnetometer.
///
/// **Experimental:** cannot be used in apps on production release channels.
@experimental
class MotionSample {
  /// Creates a [MotionSample].
  const MotionSample({
    required this.timestampNs,
    this.accelerometer,
    this.gyroscope,
    this.magnetometer,
    this.orientation,
    this.source = MotionSource.glasses,
  });

  /// Decodes a platform-channel map.
  factory MotionSample.fromMap(Map<Object?, Object?> map) => MotionSample(
    timestampNs: (map['timestampNs'] as num?)?.toInt() ?? 0,
    accelerometer: Vector3.fromMap(map['accelerometer']),
    gyroscope: Vector3.fromMap(map['gyroscope']),
    magnetometer: Vector3.fromMap(map['magnetometer']),
    orientation: Quaternion.fromMap(map['orientation']),
    source: MotionSource.fromWire(map['source']),
  );

  /// Sample time in nanoseconds.
  final int timestampNs;

  /// Acceleration in m/s^2.
  final Vector3? accelerometer;

  /// Angular velocity in rad/s.
  final Vector3? gyroscope;

  /// Magnetic field in microtesla.
  final Vector3? magnetometer;

  /// Orientation.
  final Quaternion? orientation;

  /// Producing device.
  final MotionSource source;

  /// Platform-channel encoding (used by the mock motion feed).
  Map<String, Object?> toMap() => {
    'timestampNs': timestampNs,
    if (accelerometer != null) 'accelerometer': accelerometer!.toMap(),
    if (gyroscope != null) 'gyroscope': gyroscope!.toMap(),
    if (magnetometer != null) 'magnetometer': magnetometer!.toMap(),
    if (orientation != null) 'orientation': orientation!.toMap(),
    'source': source == MotionSource.neuralBand ? 'neuralBand' : 'glasses',
  };
}
