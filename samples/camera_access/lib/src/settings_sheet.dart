import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

/// Editable streaming options.
class StreamSettings {
  const StreamSettings({
    this.fps = 30,
    this.quality = StreamQuality.high,
    this.codec = VideoCodec.raw,
    this.backgroundStreaming = false,
  });

  final int fps;
  final StreamQuality quality;
  final VideoCodec codec;
  final bool backgroundStreaming;

  StreamSettings copyWith({
    int? fps,
    StreamQuality? quality,
    VideoCodec? codec,
    bool? backgroundStreaming,
  }) =>
      StreamSettings(
        fps: fps ?? this.fps,
        quality: quality ?? this.quality,
        codec: codec ?? this.codec,
        backgroundStreaming: backgroundStreaming ?? this.backgroundStreaming,
      );
}

/// Bottom-sheet that lets the user tweak FPS / quality / codec / background.
///
/// Mirrors the official Camera Access sample's `SettingsSheet` so users get
/// a feel for how the DAT SDK responds to runtime configuration changes.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    required this.initial,
    required this.onDisconnect,
    super.key,
  });

  final StreamSettings initial;
  final Future<void> Function() onDisconnect;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late StreamSettings _settings = widget.initial;

  static const _fpsOptions = <int>[2, 7, 15, 24, 30];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAndroid = !kIsWebFake && Platform.isAndroid;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Settings', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _DropdownRow<int>(
              label: 'FPS',
              value: _settings.fps,
              items: [
                for (final fps in _fpsOptions)
                  DropdownMenuItem(value: fps, child: Text('$fps')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _settings = _settings.copyWith(fps: v));
                }
              },
            ),
            const SizedBox(height: 12),
            _DropdownRow<StreamQuality>(
              label: 'Quality',
              value: _settings.quality,
              items: [
                for (final q in StreamQuality.values)
                  DropdownMenuItem(value: q, child: Text(q.name)),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _settings = _settings.copyWith(quality: v));
                }
              },
            ),
            const SizedBox(height: 12),
            _DropdownRow<VideoCodec>(
              label: 'Codec',
              value: _settings.codec,
              items: [
                for (final c in VideoCodec.values)
                  DropdownMenuItem(
                    value: c,
                    enabled: !(isAndroid && c == VideoCodec.hvc1),
                    child: Text(
                      isAndroid && c == VideoCodec.hvc1
                          ? '${c.name} (iOS only)'
                          : c.name,
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v == null) return;
                if (isAndroid && v == VideoCodec.hvc1) return;
                setState(() => _settings = _settings.copyWith(codec: v));
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Background streaming'),
              subtitle: Text(
                isAndroid
                    ? 'Starts a foreground service with a persistent '
                        'notification.'
                    : 'Activates a background audio session.',
              ),
              value: _settings.backgroundStreaming,
              onChanged: (v) => setState(
                () => _settings = _settings.copyWith(backgroundStreaming: v),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop(_settings);
                await widget.onDisconnect();
              },
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect glasses'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_settings),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

/// `kIsWeb` is provided by `package:flutter/foundation.dart`, but pulling
/// that in for a single boolean is overkill. The sample only runs on iOS
/// and Android so this constant is always false.
const bool kIsWebFake = false;

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
