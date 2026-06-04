import 'dart:async';

import 'package:display_access/src/tutorials.dart';
import 'package:flutter/material.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

/// Where the on-glasses Car Maintenance flow currently is.
enum DisplayScreen { list, detail, step, video }

/// Top-level shell. Owns the registration / active-device / display-state
/// subscriptions and drives the declarative Car Maintenance UI on the glasses.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  RegistrationState _registrationState = RegistrationState.unavailable;
  DeviceInfo? _activeDevice;
  bool _permissionsGranted = false;
  DisplayState _displayState = DisplayState.stopped;
  bool _displayActive = false;

  DisplayScreen _screen = DisplayScreen.list;
  CarMaintenanceTutorial? _tutorial;
  int _stepIndex = 0;

  StreamSubscription<RegistrationState>? _regSub;
  StreamSubscription<DeviceInfo?>? _deviceSub;
  StreamSubscription<DisplayState>? _displaySub;

  @override
  void initState() {
    super.initState();
    _regSub = MetaWearablesDat.registrationStateStream().listen((s) {
      if (mounted) setState(() => _registrationState = s);
    });
    _deviceSub = MetaWearablesDat.activeDeviceStream().listen((d) {
      if (mounted) setState(() => _activeDevice = d);
    });
    _displaySub = MetaWearablesDat.displayStateStream().listen((s) {
      if (mounted) setState(() => _displayState = s);
    });
  }

  @override
  void dispose() {
    _regSub?.cancel();
    _deviceSub?.cancel();
    _displaySub?.cancel();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      _toast('Connect failed: ${e.code}');
    }
  }

  Future<void> _disconnect() async {
    try {
      await MetaWearablesDat.startUnregistration();
    } on DatError catch (e) {
      _toast('Disconnect failed: ${e.code}');
    }
  }

  Future<void> _startDisplay() async {
    try {
      await MetaWearablesDat.startDisplaySession();
      if (!mounted) return;
      setState(() {
        _displayActive = true;
        _screen = DisplayScreen.list;
      });
      await _showList();
    } on DatError catch (e) {
      _toast('Display failed: ${e.code}');
    } on Object catch (e) {
      _toast('Display failed: $e');
    }
  }

  Future<void> _stopDisplay() async {
    await MetaWearablesDat.stopDisplaySession();
    if (!mounted) return;
    setState(() {
      _displayActive = false;
      _tutorial = null;
      _screen = DisplayScreen.list;
    });
  }

  Future<void> _send(DisplayView view) async {
    try {
      await MetaWearablesDat.sendDisplayView(view);
    } on DatError catch (e) {
      _toast('Send failed: ${e.code}');
    }
  }

  Future<void> _showList() async {
    setState(() {
      _screen = DisplayScreen.list;
      _tutorial = null;
    });
    await _send(buildTutorialListView(_showDetail));
  }

  Future<void> _showDetail(CarMaintenanceTutorial tutorial) async {
    setState(() {
      _screen = DisplayScreen.detail;
      _tutorial = tutorial;
    });
    await _send(
      buildTutorialDetailView(
        tutorial,
        onBack: _showList,
        onStart: () => _showStep(tutorial, 0),
      ),
    );
  }

  Future<void> _showStep(CarMaintenanceTutorial tutorial, int index) async {
    final clamped = index.clamp(0, tutorial.steps.length - 1);
    setState(() {
      _screen = DisplayScreen.step;
      _tutorial = tutorial;
      _stepIndex = clamped;
    });
    await _send(
      buildTutorialStepView(
        tutorial,
        clamped,
        onPrevious: () {
          if (clamped == 0) {
            unawaited(_showDetail(tutorial));
          } else {
            unawaited(_showStep(tutorial, clamped - 1));
          }
        },
        onNext: () {
          if (clamped == tutorial.steps.length - 1) {
            unawaited(_showList());
          } else {
            unawaited(_showStep(tutorial, clamped + 1));
          }
        },
        onWatchVideo: () => _showVideo(tutorial, clamped),
      ),
    );
  }

  Future<void> _showVideo(CarMaintenanceTutorial tutorial, int index) async {
    setState(() => _screen = DisplayScreen.video);
    await _send(
      buildTutorialVideoView(onEnded: () => _showStep(tutorial, index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isRegistered = _registrationState == RegistrationState.registered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Access'),
        backgroundColor: colors.primaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(
            registrationState: _registrationState,
            activeDevice: _activeDevice,
            permissionsGranted: _permissionsGranted,
            displayState: _displayState,
            screen: _screen,
            tutorialTitle: _tutorial?.title,
            stepIndex: _stepIndex,
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
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed:
                      isRegistered && !_displayActive ? _startDisplay : null,
                  icon: const Icon(Icons.cast_connected),
                  label: const Text('Start display'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _displayActive ? _stopDisplay : null,
                  icon: const Icon(Icons.stop_screen_share),
                  label: const Text('Stop display'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_displayActive) ...[
            Text(
              'On the glasses',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _showList,
              icon: const Icon(Icons.list_alt),
              label: const Text('Show tutorial list'),
            ),
            const SizedBox(height: 12),
            Text(
              'Use the touchpad on the glasses to tap tiles and buttons. '
              'The phone mirrors the active screen above.',
              style: theme.textTheme.bodySmall,
            ),
          ] else
            Text(
              'Connect your Ray-Ban Display glasses, then start a display '
              'session to render the Car Maintenance tutorials.',
              style: theme.textTheme.bodyMedium,
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
    required this.displayState,
    required this.screen,
    required this.tutorialTitle,
    required this.stepIndex,
  });

  final RegistrationState registrationState;
  final DeviceInfo? activeDevice;
  final bool permissionsGranted;
  final DisplayState displayState;
  final DisplayScreen screen;
  final String? tutorialTitle;
  final int stepIndex;

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
              icon:
                  permissionsGranted ? Icons.check_circle : Icons.error_outline,
            ),
            _StatusRow(
              label: 'Display state',
              value: displayState.name,
              icon: displayState == DisplayState.started
                  ? Icons.check_circle
                  : Icons.cast,
            ),
            _StatusRow(
              label: 'Active screen',
              value: screen == DisplayScreen.step
                  ? 'step ${stepIndex + 1}'
                  : screen.name,
              icon: Icons.smart_display_outlined,
            ),
            _StatusRow(
              label: 'Tutorial',
              value: tutorialTitle ?? '—',
              icon: Icons.menu_book_outlined,
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
