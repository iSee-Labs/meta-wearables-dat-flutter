/// Identifies a paired Meta wearable device.
///
/// Surfaced by [MetaWearablesDat.activeDeviceStream] and consumed by
/// session methods that accept a `deviceUUID` parameter.
class DeviceInfo {
  /// Creates a [DeviceInfo].
  const DeviceInfo({
    required this.uuid,
    required this.name,
    required this.kind,
  });

  /// Constructs a [DeviceInfo] from a platform-channel map.
  ///
  /// Tolerant of missing fields: anything absent falls back to a sensible
  /// default ([DeviceKind.unknown] / empty strings).
  factory DeviceInfo.fromMap(Map<Object?, Object?> map) {
    return DeviceInfo(
      uuid: map['uuid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      kind: DeviceKind.fromRaw(map['kind'] as String?),
    );
  }

  /// Stable per-device identifier assigned by Meta's SDK.
  final String uuid;

  /// Human-readable device name as reported by the SDK.
  final String name;

  /// Coarse-grained device family. Useful for UI and capability gating.
  final DeviceKind kind;

  @override
  String toString() => 'DeviceInfo(uuid: $uuid, name: $name, kind: $kind)';
}

/// Coarse-grained Meta wearable family.
///
/// The native side may report richer model information (e.g. "Ray-Ban Meta
/// Skyler"); we map those to the closest [DeviceKind] for cross-platform
/// consistency. New families should extend this enum in additive releases.
enum DeviceKind {
  /// Ray-Ban Meta (Gen 1 and Gen 2).
  rayBanMeta,

  /// Ray-Ban Display.
  rayBanDisplay,

  /// Oakley Meta (HSTN, Vanguard, ...).
  oakleyMeta,

  /// Anything the SDK reports that the plugin doesn't recognise yet.
  unknown;

  /// Maps a raw kind string from the platform channel to a [DeviceKind].
  static DeviceKind fromRaw(String? raw) {
    switch (raw) {
      case 'rayBanMeta':
        return DeviceKind.rayBanMeta;
      case 'rayBanDisplay':
        return DeviceKind.rayBanDisplay;
      case 'oakleyMeta':
        return DeviceKind.oakleyMeta;
      case _:
        return DeviceKind.unknown;
    }
  }
}
