import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    initPlatformState();
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

  Future<void> _requestPermissions() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final granted = await MetaWearablesDat.requestAndroidPermissions();
      if (!mounted) return;
      setState(() => _lastPermissionResult = granted ? 'granted' : 'denied');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Android permissions: $granted'),
          duration: const Duration(seconds: 2),
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _lastPermissionResult = 'error: ${e.code}');
      messenger.showSnackBar(
        SnackBar(content: Text('Permission error: ${e.code} ${e.message}')),
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
              children: [
                Text('Running on: $_platformVersion'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _requestPermissions,
                  child: const Text('Request Android permissions'),
                ),
                if (_lastPermissionResult != null) ...[
                  const SizedBox(height: 12),
                  Text('Last result: $_lastPermissionResult'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
