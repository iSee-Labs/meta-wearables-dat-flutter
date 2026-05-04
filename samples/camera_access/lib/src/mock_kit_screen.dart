import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

/// Mock Device Kit playground.
///
/// Mirrors the iOS / Android sample: enable the kit, pair a Ray-Ban Meta
/// mock, then exercise power, don, and camera-feed setters from the UI.
class MockKitScreen extends StatefulWidget {
  const MockKitScreen({super.key});

  @override
  State<MockKitScreen> createState() => _MockKitScreenState();
}

class _MockKitScreenState extends State<MockKitScreen> {
  bool _enabled = false;
  List<DeviceInfo> _devices = const [];
  StreamSubscription<List<DeviceInfo>>? _devicesSub;

  @override
  void initState() {
    super.initState();
    _devicesSub = MetaWearablesDat.mockDevicesStream().listen((list) {
      if (mounted) setState(() => _devices = list);
    });
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    super.dispose();
  }

  Future<void> _enable() async {
    await MetaWearablesDat.enableMockDevice();
    if (mounted) setState(() => _enabled = true);
  }

  Future<void> _disable() async {
    await MetaWearablesDat.disableMockDevice();
    if (mounted) setState(() => _enabled = false);
  }

  Future<void> _pair() async {
    await MetaWearablesDat.pairMockRayBanMeta();
  }

  Future<void> _unpair(String uuid) async {
    await MetaWearablesDat.unpairMockDevice(uuid);
  }

  Future<void> _powerOn(String uuid) async {
    await MetaWearablesDat.mockPowerOn(uuid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Powered on')),
    );
  }

  Future<void> _don(String uuid) async {
    await MetaWearablesDat.mockDon(uuid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Donned')),
    );
  }

  Future<void> _setFront(String uuid) async {
    await MetaWearablesDat.setMockCameraFacing(uuid, CameraFacing.front);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Camera facing: front')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mock Device Kit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mock kit',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Switch(
                        value: _enabled,
                        onChanged: (v) => v ? _enable() : _disable(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _enabled ? _pair : null,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Pair Ray-Ban Meta'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No mock devices paired yet')),
            )
          else
            ..._devices.map(
              (d) => Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.smart_toy_outlined),
                        title: Text(d.name),
                        subtitle: Text(d.uuid),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _unpair(d.uuid),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _powerOn(d.uuid),
                            child: const Text('Power on'),
                          ),
                          OutlinedButton(
                            onPressed: () => _don(d.uuid),
                            child: const Text('Don'),
                          ),
                          OutlinedButton(
                            onPressed: () => _setFront(d.uuid),
                            child: const Text('Camera: front'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
