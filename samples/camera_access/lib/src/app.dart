import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:camera_access/src/mock_kit_screen.dart';
import 'package:camera_access/src/stream_screen.dart';
import 'package:flutter/material.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

/// Top-level shell. Owns the registration / active-device subscriptions
/// shared across screens and exposes the latest values via [InheritedWidget]
/// so child screens stay declarative.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AppLinks _appLinks = AppLinks();

  RegistrationState _registrationState = RegistrationState.unavailable;
  DeviceInfo? _activeDevice;
  bool _permissionsGranted = false;
  bool _cameraPermissionGranted = false;

  StreamSubscription<RegistrationState>? _regSub;
  StreamSubscription<DeviceInfo?>? _deviceSub;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _regSub = MetaWearablesDat.registrationStateStream().listen((s) {
      if (mounted) setState(() => _registrationState = s);
    });
    _deviceSub = MetaWearablesDat.activeDeviceStream().listen((d) {
      if (mounted) setState(() => _activeDevice = d);
    });
    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      MetaWearablesDat.handleUrl(uri.toString());
    });
  }

  @override
  void dispose() {
    _regSub?.cancel();
    _deviceSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final granted = await MetaWearablesDat.requestAndroidPermissions();
    if (!mounted) return;
    setState(() => _permissionsGranted = granted);
  }

  Future<void> _connect() async {
    try {
      await MetaWearablesDat.startRegistration();
    } on DatError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connect failed: ${e.code}')),
      );
    }
  }

  Future<void> _disconnect() async {
    try {
      await MetaWearablesDat.startUnregistration();
    } on DatError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect failed: ${e.code}')),
      );
    }
  }

  Future<void> _requestCameraPermission() async {
    try {
      final granted = await MetaWearablesDat.requestCameraPermission();
      if (!mounted) return;
      setState(() => _cameraPermissionGranted = granted);
    } on DatError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera permission failed: ${e.code}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isRegistered = _registrationState == RegistrationState.registered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Access'),
        backgroundColor: colors.primaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(
            registrationState: _registrationState,
            activeDevice: _activeDevice,
            permissionsGranted: _permissionsGranted,
            cameraPermissionGranted: _cameraPermissionGranted,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _requestPermissions,
            icon: const Icon(Icons.bluetooth),
            label: const Text('Request Bluetooth / Internet'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isRegistered ? null : _connect,
                  icon: const Icon(Icons.link),
                  label: const Text('Connect glasses'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isRegistered ? _disconnect : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: isRegistered ? _requestCameraPermission : null,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Request camera permission'),
          ),
          const SizedBox(height: 24),
          _NavigationTile(
            icon: Icons.videocam_outlined,
            title: 'Live stream',
            subtitle: 'Render frames in a Texture widget; capture stills.',
            enabled: isRegistered && _cameraPermissionGranted,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const StreamScreen()),
            ),
          ),
          _NavigationTile(
            icon: Icons.devices_other_outlined,
            title: 'Mock Device Kit',
            subtitle:
                'Develop without hardware: pair, power, don, set feeds.',
            enabled: true,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const MockKitScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.registrationState,
    required this.activeDevice,
    required this.permissionsGranted,
    required this.cameraPermissionGranted,
  });

  final RegistrationState registrationState;
  final DeviceInfo? activeDevice;
  final bool permissionsGranted;
  final bool cameraPermissionGranted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Status', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'Registration',
              value: registrationState.name,
              icon: registrationState == RegistrationState.registered
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
            ),
            _StatusRow(
              label: 'Active device',
              value: activeDevice?.name ?? '—',
              icon: Icons.smart_toy_outlined,
            ),
            _StatusRow(
              label: 'BT / Internet',
              value: permissionsGranted ? 'granted' : 'not granted',
              icon: permissionsGranted
                  ? Icons.check_circle
                  : Icons.error_outline,
            ),
            _StatusRow(
              label: 'Camera permission',
              value: cameraPermissionGranted ? 'granted' : 'not granted',
              icon: cameraPermissionGranted
                  ? Icons.check_circle
                  : Icons.error_outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        enabled: enabled,
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
