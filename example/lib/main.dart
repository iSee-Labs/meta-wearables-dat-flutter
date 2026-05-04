import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String? _lastPermissionResult;
  String? _lastError;

  RegistrationState _registrationState = RegistrationState.unavailable;
  DeviceInfo? _activeDevice;

  StreamSubscription<RegistrationState>? _registrationSub;
  StreamSubscription<DeviceInfo?>? _activeDeviceSub;
  StreamSubscription<Uri>? _deepLinkSub;

  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _wireRegistrationStreams();
    _wireDeepLinks();
  }

  @override
  void dispose() {
    _registrationSub?.cancel();
    _activeDeviceSub?.cancel();
    _deepLinkSub?.cancel();
    super.dispose();
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion = await MetaWearablesDat.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }
    if (!mounted) return;
    setState(() {
      _platformVersion = platformVersion;
    });
  }

  void _wireRegistrationStreams() {
    _registrationSub = MetaWearablesDat.registrationStateStream().listen(
      (state) {
        if (!mounted) return;
        setState(() => _registrationState = state);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _lastError = 'registrationStateStream: $e');
      },
    );
    _activeDeviceSub = MetaWearablesDat.activeDeviceStream().listen(
      (device) {
        if (!mounted) return;
        setState(() => _activeDevice = device);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _lastError = 'activeDeviceStream: $e');
      },
    );
  }

  void _wireDeepLinks() {
    _deepLinkSub = _appLinks.uriLinkStream.listen(
      (uri) async {
        try {
          final consumed = await MetaWearablesDat.handleUrl(uri.toString());
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('handleUrl($uri) -> $consumed')),
          );
        } on DatError catch (e) {
          if (!mounted) return;
          setState(() => _lastError = 'handleUrl: ${e.code} ${e.message}');
        }
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _lastError = 'deep link stream: $e');
      },
    );
  }

  Future<void> _requestPermissions() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final granted = await MetaWearablesDat.requestAndroidPermissions();
      if (!mounted) return;
      setState(() => _lastPermissionResult = granted ? 'granted' : 'denied');
      messenger.showSnackBar(
        SnackBar(content: Text('Android permissions: $granted')),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _lastPermissionResult = 'error: ${e.code}');
      messenger.showSnackBar(
        SnackBar(content: Text('Permission error: ${e.code} ${e.message}')),
      );
    }
  }

  Future<void> _connectGlasses() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await MetaWearablesDat.startRegistration();
    } on DatError catch (e) {
      if (!mounted) return;
      setState(() => _lastError = '${e.code}: ${e.message}');
      messenger.showSnackBar(SnackBar(content: Text('Connect failed: ${e.code}')));
    }
  }

  Future<void> _disconnectGlasses() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await MetaWearablesDat.startUnregistration();
    } on DatError catch (e) {
      if (!mounted) return;
      setState(() => _lastError = '${e.code}: ${e.message}');
      messenger.showSnackBar(
        SnackBar(content: Text('Disconnect failed: ${e.code}')),
      );
    }
  }

  Future<void> _requestCameraPermission() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final granted = await MetaWearablesDat.requestCameraPermission();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Camera permission: $granted')),
      );
    } on DatError catch (e) {
      if (!mounted) return;
      setState(() => _lastError = '${e.code}: ${e.message}');
      messenger.showSnackBar(
        SnackBar(content: Text('Camera permission error: ${e.code}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('meta_wearables_dat_flutter example')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Running on: $_platformVersion'),
                const SizedBox(height: 16),
                Text('Registration state: ${_registrationState.name}'),
                Text('Active device: ${_activeDevice?.name ?? 'none'}'),
                const Divider(height: 32),
                FilledButton(
                  onPressed: _requestPermissions,
                  child: const Text('Request Android permissions'),
                ),
                if (_lastPermissionResult != null) ...[
                  const SizedBox(height: 8),
                  Text('Last permission result: $_lastPermissionResult'),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            _registrationState == RegistrationState.registering
                                ? null
                                : _connectGlasses,
                        child: const Text('Connect glasses'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _registrationState == RegistrationState.registered
                                ? _disconnectGlasses
                                : null,
                        child: const Text('Disconnect'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed:
                      _registrationState == RegistrationState.registered
                          ? _requestCameraPermission
                          : null,
                  child: const Text('Request camera permission'),
                ),
                if (_lastError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _lastError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
