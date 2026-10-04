import 'dart:async';

import 'package:flutter/material.dart';
import 'package:glasses_companion/src/selection.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

/// Shows a live status card on Meta Ray-Ban Display glasses.
///
/// The card mirrors the device's battery and thermal state, and its buttons
/// call back into Dart when tapped on the glasses.
class DisplayTab extends StatefulWidget {
  const DisplayTab({super.key});

  @override
  State<DisplayTab> createState() => _DisplayTabState();
}

class _DisplayTabState extends State<DisplayTab> {
  DisplayState _state = DisplayState.stopped;
  int _taps = 0;
  String? _status;
  StreamSubscription<DisplayState>? _stateSub;
  StreamSubscription<DeviceInfo>? _deviceSub;
  DeviceInfo? _device;

  bool get _active =>
      _state == DisplayState.started || _state == DisplayState.starting;

  @override
  void initState() {
    super.initState();
    _stateSub = MetaWearablesDat.displayStateStream().listen((s) {
      setState(() => _state = s);
      if (s == DisplayState.stopped) unawaited(_deviceSub?.cancel());
    });
  }

  @override
  void dispose() {
    unawaited(_stateSub?.cancel());
    unawaited(_deviceSub?.cancel());
    if (_active) unawaited(MetaWearablesDat.stopDisplaySession());
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await MetaWearablesDat.startDisplaySession(
        deviceUUID: selectedDevice.value,
      );
      final uuid =
          selectedDevice.value ??
          (await MetaWearablesDat.getSessionDevice())?.uuid;
      if (uuid != null) {
        // Re-render the card whenever the glasses' state changes.
        _deviceSub = MetaWearablesDat.deviceStateStream(uuid).listen((d) {
          _device = d;
          unawaited(_render());
        });
      }
      await _render();
    } on DatError catch (e) {
      setState(() => _status = '${e.category}/${e.code}: ${e.message}');
    }
  }

  Future<void> _stop() async {
    await _deviceSub?.cancel();
    await MetaWearablesDat.stopDisplaySession();
  }

  DisplayView _view() {
    final d = _device;
    return FlexBox(
      spacing: 12,
      children: [
        FlexBox(
          padding: 24,
          background: FlexBoxBackground.card,
          spacing: 8,
          children: [
            const DisplayText(
              'Glasses Companion',
              style: DisplayTextStyle.heading,
            ),
            DisplayText(
              d == null
                  ? 'Waiting for device state'
                  : 'Battery ${d.batteryLevel ?? '?'}% · '
                        '${d.chargingState == ChargingState.charging ? 'charging' : 'on battery'}',
            ),
            DisplayText(
              'Thermal: ${d?.thermalLevel.name ?? '?'}',
              color: (d?.thermalLevel.isThrottling ?? false)
                  ? DisplayTextColor.secondary
                  : null,
            ),
            DisplayText('Taps: $_taps', style: DisplayTextStyle.meta),
          ],
        ),
        DisplayButtonGroup(
          buttons: [
            DisplayButton(
              label: 'Tap me',
              iconName: DisplayIconName.checkmarkCircle,
              actionRole: DisplayActionRole.primary,
              onClick: () {
                setState(() => _taps++);
                unawaited(_render());
              },
            ),
            DisplayButton(
              label: 'Reset',
              style: DisplayButtonStyle.secondary,
              onClick: () {
                setState(() => _taps = 0);
                unawaited(_render());
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _render() async {
    if (!_active) return;
    try {
      await MetaWearablesDat.sendDisplayView(_view());
    } on DatError catch (e) {
      if (mounted) setState(() => _status = 'Send failed: ${e.code}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Needs Meta Ray-Ban Display glasses (or the "metaRayBanDisplay" '
          'mock model on the Devices tab).',
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.view_quilt),
          title: Text('Display: ${_state.name}'),
          subtitle: Text('Taps from the glasses: $_taps'),
        ),
        if (_status != null)
          Text(
            _status!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _active ? _stop : _start,
              child: Text(_active ? 'Stop display' : 'Start display'),
            ),
            OutlinedButton(
              onPressed: _active ? MetaWearablesDat.clearDisplay : null,
              child: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }
}
