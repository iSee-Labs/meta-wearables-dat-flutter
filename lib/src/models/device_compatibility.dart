/// Version compatibility between this app's DAT SDK and the glasses.
enum DeviceCompatibility {
  /// Compatible.
  compatible,

  /// The glasses firmware must be updated
  /// (`MetaWearablesDat.openFirmwareUpdate`).
  deviceUpdateRequired,

  /// This app must be rebuilt with a newer SDK.
  sdkUpdateRequired,

  /// Not reported yet.
  unknown;

  /// Parses the wire name; unknown values map to [unknown].
  static DeviceCompatibility fromRaw(String? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return unknown;
  }
}

/// A compatibility verdict for one device.
class DeviceCompatibilityEvent {
  /// Creates a [DeviceCompatibilityEvent].
  const DeviceCompatibilityEvent({
    required this.deviceUuid,
    required this.compatibility,
  });

  /// Decodes a platform-channel map.
  factory DeviceCompatibilityEvent.fromMap(Map<Object?, Object?> map) {
    return DeviceCompatibilityEvent(
      deviceUuid: map['deviceUuid'] as String? ?? '',
      compatibility: DeviceCompatibility.fromRaw(
        map['compatibility'] as String?,
      ),
    );
  }

  /// The device the verdict is for.
  final String deviceUuid;

  /// The verdict.
  final DeviceCompatibility compatibility;

  @override
  String toString() =>
      'DeviceCompatibilityEvent(deviceUuid: $deviceUuid, compatibility: ${compatibility.name})';
}
