import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

/// Paired-device list driven by `devicesStream()` + `compatibilityStream()`.
///
/// Mirrors the `DevicesScreen` from Meta's official iOS / Android Camera
/// Access samples: one row per paired device, with a per-device
/// compatibility banner ("Your glasses need a firmware update") when
/// the SDK reports anything other than `compatible`.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<DeviceInfo> _devices = const [];
  final Map<String, DeviceCompatibility> _compat = {};

  StreamSubscription<List<DeviceInfo>>? _devicesSub;
  StreamSubscription<DeviceCompatibilityEvent>? _compatSub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final snapshot = await MetaWearablesDat.getDevices();
    if (!mounted) return;
    setState(() => _devices = snapshot);
    _devicesSub = MetaWearablesDat.devicesStream().listen((list) {
      if (!mounted) return;
      setState(() => _devices = list);
    });
    _compatSub = MetaWearablesDat.compatibilityStream().listen((event) {
      if (!mounted) return;
      setState(() => _compat[event.deviceUuid] = event.compatibility);
    });
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    _compatSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      body: _devices.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No paired devices. Pair Ray-Ban Meta glasses through '
                  'Meta AI, or use the Mock Device Kit to simulate one.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                final compat =
                    _compat[device.uuid] ?? DeviceCompatibility.unknown;
                return _DeviceCard(device: device, compatibility: compat);
              },
            ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.compatibility});

  final DeviceInfo device;
  final DeviceCompatibility compatibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: const Icon(Icons.visibility),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, style: theme.textTheme.titleMedium),
                      Text(
                        '${device.kind.name} • ${device.uuid}',
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (compatibility != DeviceCompatibility.compatible) ...[
              const SizedBox(height: 12),
              _CompatibilityBanner(compatibility: compatibility),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompatibilityBanner extends StatelessWidget {
  const _CompatibilityBanner({required this.compatibility});

  final DeviceCompatibility compatibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (text, icon, color) = switch (compatibility) {
      DeviceCompatibility.deviceUpdateRequired => (
          'Update required on the glasses. Open Meta AI to install the '
              'latest firmware.',
          Icons.system_update_alt,
          theme.colorScheme.errorContainer,
        ),
      DeviceCompatibility.sdkUpdateRequired => (
          'Update required in this app. Upgrade '
              '`meta_wearables_dat_flutter` to a newer version.',
          Icons.app_shortcut,
          theme.colorScheme.errorContainer,
        ),
      DeviceCompatibility.unknown => (
          'Compatibility unknown. The SDK has not yet evaluated this '
              'device.',
          Icons.help_outline,
          theme.colorScheme.surfaceContainerHighest,
        ),
      DeviceCompatibility.compatible => (
          'Compatible.',
          Icons.check_circle,
          theme.colorScheme.tertiaryContainer,
        ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
