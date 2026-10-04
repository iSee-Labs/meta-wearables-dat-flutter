// Every API on this tab is experimental: Meta does not allow it in apps on
// production release channels.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:glasses_companion/src/selection.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

/// Experimental DAT 1.0 modules: inputs, motion, speech and voice
/// invocations.
class LabTab extends StatefulWidget {
  const LabTab({super.key});

  @override
  State<LabTab> createState() => _LabTabState();
}

class _LabTabState extends State<LabTab> {
  final _log = <String>[];
  final _subs = <StreamSubscription<Object?>>[];
  StreamSubscription<MotionSample>? _motionSub;
  bool _inputs = false;
  bool _motion = false;
  bool _speech = false;
  bool _voice = false;
  MotionSample? _sample;
  String _transcript = '';

  @override
  void initState() {
    super.initState();
    _subs
      ..add(
        MetaWearablesDat.inputEventsStream().listen(
          (e) => _add('input: ${e.runtimeType} from ${e.source.name}'),
        ),
      )
      ..add(
        MetaWearablesDat.transcriptionStream().listen(
          (t) => setState(
            () => _transcript = t.isFinal ? '${t.text} (final)' : t.text,
          ),
        ),
      )
      ..add(MetaWearablesDat.voiceInvocationsStream().listen(_onInvocation))
      ..add(MetaWearablesDat.inputsErrorStream().listen(_error))
      ..add(MetaWearablesDat.motionErrorStream().listen(_error))
      ..add(MetaWearablesDat.speechErrorStream().listen(_error))
      ..add(MetaWearablesDat.voiceInvocationErrorStream().listen(_error));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(_motionSub?.cancel());
    if (_inputs) unawaited(MetaWearablesDat.stopInputs());
    if (_motion) unawaited(MetaWearablesDat.stopMotion());
    if (_speech) unawaited(MetaWearablesDat.stopSpeech());
    if (_voice) unawaited(MetaWearablesDat.stopVoiceInvocations());
    super.dispose();
  }

  void _add(String line) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, line);
      if (_log.length > 50) _log.removeLast();
    });
  }

  void _error(DatError e) => _add('error: ${e.category}/${e.code}');

  Future<void> _onInvocation(VoiceInvocation invocation) async {
    _add('voice: "Hey Meta, open Glasses Companion"');
    // Every invocation must be answered exactly once.
    await invocation.respondSuccess(actionOutput: 'Glasses Companion is open');
  }

  Future<bool> _toggle(
    bool on,
    Future<void> Function() start,
    Future<void> Function() stop,
  ) async {
    try {
      await (on ? start() : stop());
      return on;
    } on DatError catch (e) {
      _error(e);
      return !on;
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = selectedDevice.value;
    final a = _sample?.accelerometer;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: const ListTile(
            leading: Icon(Icons.science),
            title: Text('Experimental'),
            subtitle: Text(
              'These modules work in Developer Mode only and cannot ship on '
              'production release channels.',
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Inputs'),
          subtitle: const Text('Captouch, buttons and Neural Band gestures'),
          value: _inputs,
          onChanged: (on) async {
            final v = await _toggle(
              on,
              () => MetaWearablesDat.startInputs(deviceUUID: device),
              MetaWearablesDat.stopInputs,
            );
            setState(() => _inputs = v);
          },
        ),
        SwitchListTile(
          title: const Text('Motion'),
          subtitle: Text(
            a == null
                ? 'IMU samples at 10 Hz'
                : 'accel ${a.x.toStringAsFixed(2)}, '
                      '${a.y.toStringAsFixed(2)}, ${a.z.toStringAsFixed(2)}',
          ),
          value: _motion,
          onChanged: (on) async {
            final v = await _toggle(
              on,
              () async {
                // Samples are opt-in: subscribe before starting.
                _motionSub = MetaWearablesDat.motionSamplesStream().listen(
                  (s) => setState(() => _sample = s),
                );
                await MetaWearablesDat.startMotion(deviceUUID: device);
              },
              () async {
                await _motionSub?.cancel();
                await MetaWearablesDat.stopMotion();
              },
            );
            setState(() => _motion = v);
          },
        ),
        SwitchListTile(
          title: const Text('Speech'),
          subtitle: Text(
            _transcript.isEmpty ? 'On-glasses transcription' : _transcript,
          ),
          value: _speech,
          onChanged: (on) async {
            final v = await _toggle(on, () async {
              final status = await MetaWearablesDat.requestPermission(
                Permission.microphone,
              );
              if (status != PermissionStatus.granted) {
                throw const DatArgumentError(
                  message: 'Microphone permission is required.',
                );
              }
              await MetaWearablesDat.startSpeech(deviceUUID: device);
            }, MetaWearablesDat.stopSpeech);
            setState(() => _speech = v);
          },
        ),
        SwitchListTile(
          title: const Text('Voice invocations'),
          subtitle: const Text('"Hey Meta, open Glasses Companion"'),
          value: _voice,
          onChanged: (on) async {
            final v = await _toggle(
              on,
              () => MetaWearablesDat.startVoiceInvocations(deviceUUID: device),
              MetaWearablesDat.stopVoiceInvocations,
            );
            setState(() => _voice = v);
          },
        ),
        const Divider(),
        for (final line in _log)
          Text(line, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
