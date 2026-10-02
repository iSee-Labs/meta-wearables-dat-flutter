import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:glasses_companion/src/mock_setup.dart';
import 'package:glasses_companion/src/selection.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

/// Registration, the paired-device picker and live device state.
class DevicesTab extends StatefulWidget {
  const DevicesTab({super.key});

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  RegistrationState _registration = RegistrationState.unavailable;
  List<DeviceInfo> _devices = const [];
  DatDiagnostics? _diagnostics;
  MockGlassesModel _mockModel = MockGlassesModel.rayBanMeta;
  bool _busy = false;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    _subs
      ..add(
        MetaWearablesDat.registrationStateStream().listen(
          (s) => setState(() => _registration = s),
        ),
      )
      ..add(
        MetaWearablesDat.devicesStream().listen(
          (d) => setState(() => _devices = d),
        ),
      );
    unawaited(_refreshDiagnostics());
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  Future<void> _refreshDiagnostics() async {
    final d = await MetaWearablesDat.dumpDiagnostics();
    if (mounted) setState(() => _diagnostics = d);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on DatError catch (e) {
      _toast('${e.category}/${e.code}: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final registered = _registration == RegistrationState.registered;
    final findings = _diagnostics?.findings ?? const <DatFinding>[];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: Icon(registered ? Icons.link : Icons.link_off),
            title: Text('Registration: ${_registration.name}'),
            subtitle: const Text('Connect this app to Meta AI.'),
            trailing: FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      if (Platform.isAndroid) {
                        await MetaWearablesDat.requestAndroidPermissions();
                      }
                      await (registered
                          ? MetaWearablesDat.startUnregistration()
                          : MetaWearablesDat.startRegistration());
                    }),
              child: Text(registered ? 'Disconnect' : 'Connect'),
            ),
          ),
        ),
        if (findings.isNotEmpty)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ExpansionTile(
              leading: const Icon(Icons.rule),
              title: Text('${findings.length} configuration findings'),
              children: [
                for (final f in findings)
                  ListTile(
                    dense: true,
                    title: Text('[${f.severity.name}] ${f.message}'),
                    subtitle: Text(f.fix),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text('Glasses', style: Theme.of(context).textTheme.titleMedium),
        if (_devices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No glasses yet. Pair them in Meta AI, or start mock glasses below.',
            ),
          ),
        ValueListenableBuilder(
          valueListenable: selectedDevice,
          builder: (context, selected, _) => RadioGroup<String?>(
            groupValue: selected,
            onChanged: (v) => selectedDevice.value = v,
            child: Column(
              children: [
                const RadioListTile<String?>(
                  value: null,
                  title: Text('Automatic'),
                  subtitle: Text('Best connected, worn device'),
                ),
                for (final d in _devices)
                  RadioListTile<String?>(
                    value: d.uuid,
                    title: Text(d.name.isEmpty ? d.uuid : d.name),
                    subtitle: Text(
                      '${d.type.name} · ${d.linkState.name}'
                      '${d.isMock ? ' · mock' : ''}',
                    ),
                  ),
              ],
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: selectedDevice,
          builder: (context, selected, _) {
            final uuid =
                selected ?? (_devices.isEmpty ? null : _devices.first.uuid);
            if (uuid == null) return const SizedBox.shrink();
            return _DeviceStateCard(key: ValueKey(uuid), uuid: uuid);
          },
        ),
        const SizedBox(height: 16),
        Text('Mock Device Kit', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButton<MockGlassesModel>(
                isExpanded: true,
                value: _mockModel,
                items: [
                  for (final m in MockGlassesModel.values)
                    DropdownMenuItem(value: m, child: Text(m.name)),
                ],
                onChanged: (m) => setState(() => _mockModel = m!),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final uuid = await startMockGlasses(_mockModel);
                      selectedDevice.value = uuid;
                    }),
              child: const Text('Add mock'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      selectedDevice.value = null;
                      await stopMockGlasses();
                    }),
              child: const Text('Remove all'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Live battery, charging, thermal, wear and hinge state of one device,
/// update actions, and Mock Device Kit controls for mock devices.
class _DeviceStateCard extends StatelessWidget {
  const _DeviceStateCard({required this.uuid, super.key});

  final String uuid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeviceInfo>(
      stream: MetaWearablesDat.deviceStateStream(uuid),
      builder: (context, snapshot) {
        final d = snapshot.data;
        if (d == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }
        final theme = Theme.of(context);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name.isEmpty ? d.uuid : d.name,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(
                      Icons.battery_std,
                      d.batteryLevel == null ? '?' : '${d.batteryLevel}%',
                    ),
                    _chip(Icons.power, d.chargingState.name),
                    _chip(
                      Icons.thermostat,
                      d.thermalLevel.name,
                      warn: d.thermalLevel.isThrottling,
                    ),
                    _chip(Icons.face, d.donState.name),
                    _chip(Icons.door_front_door, d.hingeState.name),
                    _chip(Icons.bluetooth, d.linkState.name),
                    _chip(Icons.verified, d.compatibility.name),
                  ],
                ),
                if (d.thermalLevel.isThrottling)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'The glasses are hot. Lower the stream quality or pause '
                      'until they cool down.',
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: MetaWearablesDat.openFirmwareUpdate,
                      icon: const Icon(Icons.system_update),
                      label: const Text('Firmware update'),
                    ),
                    OutlinedButton.icon(
                      onPressed: MetaWearablesDat.openDatGlassesAppUpdate,
                      icon: const Icon(Icons.update),
                      label: const Text('Glasses app update'),
                    ),
                  ],
                ),
                if (d.isMock) _MockControls(device: d),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(IconData icon, String label, {bool warn = false}) => Chip(
    avatar: Icon(icon, size: 18, color: warn ? Colors.deepOrange : null),
    label: Text(label),
  );
}

class _MockControls extends StatelessWidget {
  const _MockControls({required this.device});

  final DeviceInfo device;

  @override
  Widget build(BuildContext context) {
    final uuid = device.uuid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text('Simulate', style: Theme.of(context).textTheme.labelLarge),
        Slider(
          value: (device.batteryLevel ?? 100).toDouble(),
          max: 100,
          divisions: 20,
          label: 'Battery ${device.batteryLevel ?? 100}%',
          onChanged: (v) =>
              MetaWearablesDat.setMockBatteryLevel(uuid, v.round()),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DropdownButton<ThermalLevel>(
              value: device.thermalLevel == ThermalLevel.unknown
                  ? ThermalLevel.none
                  : device.thermalLevel,
              items: [
                for (final t in ThermalLevel.values)
                  if (t != ThermalLevel.unknown)
                    DropdownMenuItem(
                      value: t,
                      child: Text('Thermal: ${t.name}'),
                    ),
              ],
              onChanged: (t) => MetaWearablesDat.setMockThermalLevel(uuid, t!),
            ),
            FilterChip(
              label: const Text('Charging'),
              selected: device.chargingState == ChargingState.charging,
              onSelected: (on) => MetaWearablesDat.setMockChargingState(
                uuid,
                on ? ChargingState.charging : ChargingState.notCharging,
              ),
            ),
            FilterChip(
              label: const Text('Worn'),
              selected: device.donState == DonState.donned,
              onSelected: (on) => on
                  ? MetaWearablesDat.mockDon(uuid)
                  : MetaWearablesDat.mockDoff(uuid),
            ),
            FilterChip(
              label: const Text('Open'),
              selected: device.hingeState != HingeState.closed,
              onSelected: (on) => on
                  ? MetaWearablesDat.mockUnfold(uuid)
                  : MetaWearablesDat.mockFold(uuid),
            ),
          ],
        ),
      ],
    );
  }
}
