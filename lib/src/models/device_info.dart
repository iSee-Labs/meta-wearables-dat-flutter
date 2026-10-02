import 'package:meta/meta.dart';
import 'package:meta_wearables_dat_flutter/src/models/device_compatibility.dart';

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// Coarse device family, used for filtering (`deviceKinds`).
///
/// For the exact model use [DeviceInfo.type].
enum DeviceKind {
  /// Ray-Ban Meta, including Ray-Ban Meta Optics.
  rayBanMeta,

  /// Meta Ray-Ban Display.
  rayBanDisplay,

  /// Oakley Meta HSTN or Vanguard.
  oakleyMeta,

  /// Meta glasses.
  metaGlasses,

  /// Not reported or not recognised.
  unknown;

  /// Parses the wire name; unknown values map to [unknown].
  static DeviceKind fromRaw(String? raw) => _byName(values, raw, unknown);

  /// The wire name sent to the platform.
  String get wireName => name;
}

/// The exact glasses model reported by the DAT SDK.
enum DeviceType {
  /// Ray-Ban Meta.
  rayBanMeta,

  /// Ray-Ban Meta Optics.
  rayBanMetaOptics,

  /// Oakley Meta HSTN.
  oakleyMetaHSTN,

  /// Oakley Meta Vanguard.
  oakleyMetaVanguard,

  /// Meta Ray-Ban Display.
  metaRayBanDisplay,

  /// Meta glasses.
  metaGlasses,

  /// Not reported or not recognised.
  unknown;

  /// Parses the wire name; unknown values map to [unknown].
  static DeviceType fromWire(Object? raw) => _byName(values, raw, unknown);
}

/// Connection state between the phone and the glasses.
enum LinkState {
  /// Not connected.
  disconnected,

  /// Connecting.
  connecting,

  /// Connected.
  connected,

  /// Not reported.
  unknown;

  /// Parses the wire name; unknown values map to [unknown].
  static LinkState fromWire(Object? raw) => _byName(values, raw, unknown);
}

/// Whether the glasses are charging.
enum ChargingState {
  /// Charging.
  charging,

  /// Not charging.
  notCharging,

  /// Not reported.
  unknown;

  /// Parses the wire name; unknown values map to [unknown].
  static ChargingState fromWire(Object? raw) => _byName(values, raw, unknown);
}

/// Whether the glasses are being worn.
enum DonState {
  /// Being worn.
  donned,

  /// Not being worn.
  doffed,

  /// Not reported.
  unknown;

  /// Parses the wire name; unknown values map to [unknown].
  static DonState fromWire(Object? raw) => _byName(values, raw, unknown);
}

/// Whether the glasses arms (hinges) are open.
enum HingeState {
  /// The arms are open.
  open,

  /// The arms are folded.
  closed,

  /// Not reported.
  unknown;

  /// Parses the wire name; unknown values map to [unknown].
  static HingeState fromWire(Object? raw) => _byName(values, raw, unknown);
}

/// Thermal level of the glasses, in escalating order.
enum ThermalLevel {
  /// Not reported.
  unknown,

  /// No thermal pressure.
  none,

  /// Light thermal pressure.
  light,

  /// Moderate thermal pressure.
  moderate,

  /// Severe thermal pressure: consider reducing the workload.
  severe,

  /// Critical thermal pressure.
  critical,

  /// Thermal emergency.
  emergency,

  /// The glasses are shutting down.
  shutdown;

  /// Parses the wire name; unknown values map to [unknown].
  static ThermalLevel fromWire(Object? raw) => _byName(values, raw, unknown);

  /// True from [moderate] upwards: reduce frame rate or resolution.
  bool get isThrottling => index >= moderate.index;

  /// True from [critical] upwards: stop non-essential work.
  bool get isCritical => index >= critical.index;
}

/// A snapshot of a pair of glasses and its live state.
@immutable
class DeviceInfo {
  /// Creates a [DeviceInfo].
  const DeviceInfo({
    required this.uuid,
    required this.name,
    required this.kind,
    this.type = DeviceType.unknown,
    this.linkState = LinkState.unknown,
    this.compatibility = DeviceCompatibility.unknown,
    this.batteryLevel,
    this.chargingState = ChargingState.unknown,
    this.donState = DonState.unknown,
    this.hingeState = HingeState.unknown,
    this.thermalLevel = ThermalLevel.unknown,
    this.supportsDisplay = false,
    this.isMock = false,
  });

  /// Decodes a platform-channel map. Missing keys fall back to `unknown`.
  factory DeviceInfo.fromMap(Map<Object?, Object?> map) {
    return DeviceInfo(
      uuid: map['uuid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      kind: DeviceKind.fromRaw(map['kind'] as String?),
      type: DeviceType.fromWire(map['deviceType']),
      linkState: LinkState.fromWire(map['linkState']),
      compatibility: DeviceCompatibility.fromRaw(
        map['compatibility'] as String?,
      ),
      batteryLevel: (map['batteryLevel'] as num?)?.toInt(),
      chargingState: ChargingState.fromWire(map['chargingState']),
      donState: DonState.fromWire(map['donState']),
      hingeState: HingeState.fromWire(map['hingeState']),
      thermalLevel: ThermalLevel.fromWire(map['thermalLevel']),
      supportsDisplay: map['supportsDisplay'] as bool? ?? false,
      isMock: map['isMock'] as bool? ?? false,
    );
  }

  /// The SDK device identifier.
  final String uuid;

  /// Display name; falls back to the identifier.
  final String name;

  /// Coarse device family.
  final DeviceKind kind;

  /// Exact model.
  final DeviceType type;

  /// Connection state.
  final LinkState linkState;

  /// Version compatibility between this app's SDK and the glasses.
  final DeviceCompatibility compatibility;

  /// Battery level 0-100, or `null` when unknown.
  final int? batteryLevel;

  /// Charging state.
  final ChargingState chargingState;

  /// Whether the glasses are worn.
  final DonState donState;

  /// Whether the arms are open.
  final HingeState hingeState;

  /// Thermal level.
  final ThermalLevel thermalLevel;

  /// Whether the glasses have a display (Meta Ray-Ban Display).
  final bool supportsDisplay;

  /// Whether this is a Mock Device Kit device.
  final bool isMock;

  /// Whether the glasses are connected.
  bool get isConnected => linkState == LinkState.connected;

  @override
  bool operator ==(Object other) =>
      other is DeviceInfo &&
      other.uuid == uuid &&
      other.name == name &&
      other.kind == kind &&
      other.type == type &&
      other.linkState == linkState &&
      other.compatibility == compatibility &&
      other.batteryLevel == batteryLevel &&
      other.chargingState == chargingState &&
      other.donState == donState &&
      other.hingeState == hingeState &&
      other.thermalLevel == thermalLevel &&
      other.supportsDisplay == supportsDisplay &&
      other.isMock == isMock;

  @override
  int get hashCode => Object.hash(
    uuid,
    name,
    kind,
    type,
    linkState,
    compatibility,
    batteryLevel,
    chargingState,
    donState,
    hingeState,
    thermalLevel,
    supportsDisplay,
    isMock,
  );

  @override
  String toString() =>
      'DeviceInfo(uuid: $uuid, name: $name, type: ${type.name}, '
      'link: ${linkState.name}, battery: ${batteryLevel ?? '?'}, don: ${donState.name}, '
      'thermal: ${thermalLevel.name})';
}
