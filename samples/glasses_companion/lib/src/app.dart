import 'dart:async';

import 'package:flutter/material.dart';
import 'package:glasses_companion/src/camera_tab.dart';
import 'package:glasses_companion/src/devices_tab.dart';
import 'package:glasses_companion/src/display_tab.dart';
import 'package:glasses_companion/src/lab_tab.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glasses Companion',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _tab = 0;
  StreamSubscription<RegistrationRequest>? _requests;

  @override
  void initState() {
    super.initState();
    // Meta AI can start a registration on its own (for example from the
    // glasses). The app decides whether to continue it.
    _requests = MetaWearablesDat.registrationRequestStream().listen(
      _onRegistrationRequest,
    );
  }

  @override
  void dispose() {
    unawaited(_requests?.cancel());
    super.dispose();
  }

  Future<void> _onRegistrationRequest(RegistrationRequest request) async {
    final accept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect your glasses?'),
        content: const Text(
          'Meta AI asked to connect this app to your glasses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    try {
      if (accept ?? false) {
        await request.continueRegistration();
      } else {
        await request.cancel();
      }
    } on DatError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration: ${e.code}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [DevicesTab(), CameraTab(), DisplayTab(), LabTab()];
    return Scaffold(
      appBar: AppBar(title: const Text('Glasses Companion')),
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.devices_other),
            label: 'Devices',
          ),
          NavigationDestination(icon: Icon(Icons.videocam), label: 'Camera'),
          NavigationDestination(icon: Icon(Icons.view_quilt), label: 'Display'),
          NavigationDestination(icon: Icon(Icons.science), label: 'Lab'),
        ],
      ),
    );
  }
}
