import 'package:meta_wearables_dat_flutter/src/models/device_info.dart';
import 'package:meta_wearables_dat_flutter/src/models/registration_state.dart';

/// Severity of a [DatFinding].
enum DatFindingSeverity {
  /// Blocks registration or sessions until fixed.
  error,

  /// Likely to cause problems.
  warning,

  /// Informational (for example Developer Mode credentials).
  info;

  /// Parses the wire name; unknown values map to [info].
  static DatFindingSeverity fromWire(Object? raw) => switch (raw) {
    'error' => error,
    'warning' => warning,
    _ => info,
  };
}

/// A configuration problem found by `MetaWearablesDat.dumpDiagnostics()`.
class DatFinding {
  /// Creates a [DatFinding].
  const DatFinding({
    required this.id,
    required this.severity,
    required this.message,
    required this.fix,
  });

  /// Decodes a platform-channel map.
  factory DatFinding.fromMap(Map<Object?, Object?> map) => DatFinding(
    id: map['id'] as String? ?? '',
    severity: DatFindingSeverity.fromWire(map['severity']),
    message: map['message'] as String? ?? '',
    fix: map['fix'] as String? ?? '',
  );

  /// Stable identifier, for example `backgroundMode.external-accessory`.
  final String id;

  /// How serious the finding is.
  final DatFindingSeverity severity;

  /// What is wrong.
  final String message;

  /// How to fix it.
  final String fix;

  @override
  String toString() => '[${severity.name}] $id: $message';
}

/// Snapshot of the plugin's configuration and state, for support and
/// automated checks.
class DatDiagnostics {
  /// Creates a [DatDiagnostics].
  const DatDiagnostics({
    required this.raw,
    required this.platform,
    required this.pluginVersion,
    required this.sdkVersion,
    required this.wearablesConfigured,
    required this.registrationState,
    required this.devices,
    required this.findings,
    required this.resources,
    required this.experimentalModulesLinked,
  });

  /// Decodes a platform-channel map.
  factory DatDiagnostics.fromMap(Map<Object?, Object?> map) {
    Map<String, T> typed<T>(Object? value) =>
        (value as Map<Object?, Object?>? ?? const {}).map(
          (k, v) => MapEntry(k.toString(), v as T),
        );
    return DatDiagnostics(
      raw: _stringKeyed(map),
      platform: map['platform'] as String? ?? '',
      pluginVersion: map['pluginVersion'] as String? ?? '',
      sdkVersion: map['sdkVersion'] as String? ?? '',
      wearablesConfigured: map['wearablesConfigured'] as bool? ?? false,
      registrationState: RegistrationState.fromWire(map['registrationState']),
      devices: (map['devices'] as List<Object?>? ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map(DeviceInfo.fromMap)
          .toList(growable: false),
      findings: (map['findings'] as List<Object?>? ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map(DatFinding.fromMap)
          .toList(growable: false),
      resources: typed<num>(
        map['resources'],
      ).map((k, v) => MapEntry(k, v.toInt())),
      experimentalModulesLinked: typed<bool>(map['experimentalModulesLinked']),
    );
  }

  /// The full payload, including platform-specific keys (`config`,
  /// `configureError`, `sessionDevice`, ...).
  final Map<String, Object?> raw;

  /// `ios` or `android`.
  final String platform;

  /// Plugin version.
  final String pluginVersion;

  /// Meta DAT SDK version the plugin is built against.
  final String sdkVersion;

  /// Whether the SDK is configured (iOS) or initialised (Android).
  final bool wearablesConfigured;

  /// Current registration state.
  final RegistrationState registrationState;

  /// Paired devices.
  final List<DeviceInfo> devices;

  /// Configuration problems.
  final List<DatFinding> findings;

  /// Native resources currently held (textures, listeners, sessions, ...).
  /// All zero when nothing is running.
  final Map<String, int> resources;

  /// Which experimental modules are linked into this build.
  final Map<String, bool> experimentalModulesLinked;

  /// Findings with [DatFindingSeverity.error].
  List<DatFinding> get errors => findings
      .where((f) => f.severity == DatFindingSeverity.error)
      .toList(growable: false);

  /// Whether every resource counter is zero.
  bool get isIdle => resources.values.every((count) => count == 0);
}

Map<String, Object?> _stringKeyed(Map<Object?, Object?> map) => map.map(
  (key, value) => MapEntry(key.toString(), switch (value) {
    final Map<Object?, Object?> m => _stringKeyed(m),
    final List<Object?> l =>
      l.map((e) => e is Map<Object?, Object?> ? _stringKeyed(e) : e).toList(),
    _ => value,
  }),
);
