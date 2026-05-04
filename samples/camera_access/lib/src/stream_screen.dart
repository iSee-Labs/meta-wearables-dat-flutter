import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

/// Streaming preview screen.
///
/// Pressing "Start" calls `MetaWearablesDat.startStreamSession()` and binds
/// the returned texture id to a [Texture] widget. Pressing "Capture" pulls
/// either a still photo (via `capturePhoto`) or a Dart-side RGBA snapshot
/// (via `captureStreamFrame`) and shows it in a bottom sheet.
class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  int? _textureId;
  SessionState _sessionState = SessionState.stopped;
  VideoStreamSize? _size;
  String? _error;

  StreamSubscription<SessionState>? _stateSub;
  StreamSubscription<Object>? _errorSub;
  StreamSubscription<VideoStreamSize>? _sizeSub;

  @override
  void initState() {
    super.initState();
    _stateSub = MetaWearablesDat.sessionStateStream().listen(
      (s) {
        if (mounted) setState(() => _sessionState = s);
      },
    );
    _errorSub = MetaWearablesDat.sessionErrorStream().listen(
      (e) {
        if (mounted) setState(() => _error = e.toString());
      },
    );
    _sizeSub = MetaWearablesDat.videoStreamSizeStream().listen(
      (s) {
        if (mounted) setState(() => _size = s);
      },
    );
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _errorSub?.cancel();
    _sizeSub?.cancel();
    if (_textureId != null) {
      unawaited(MetaWearablesDat.stopStreamSession());
    }
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final id = await MetaWearablesDat.startStreamSession();
      if (mounted) setState(() => _textureId = id);
    } on DatError catch (e) {
      if (mounted) setState(() => _error = '${e.code}: ${e.message}');
    }
  }

  Future<void> _stop() async {
    try {
      await MetaWearablesDat.stopStreamSession();
      if (mounted) setState(() => _textureId = null);
    } on DatError catch (e) {
      if (mounted) setState(() => _error = '${e.code}: ${e.message}');
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final photo = await MetaWearablesDat.capturePhoto();
      if (!mounted) return;
      _showImageSheet('Photo (${photo.format.name})', photo.bytes);
    } on DatError catch (e) {
      if (mounted) setState(() => _error = '${e.code}: ${e.message}');
    }
  }

  Future<void> _captureFrame() async {
    final id = _textureId;
    if (id == null) return;
    try {
      final frame = await MetaWearablesDat.captureStreamFrame(
        id,
        format: FrameFormat.png,
      );
      if (!mounted || frame == null) return;
      _showImageSheet('Frame (${frame.format.name})', frame.bytes);
    } on DatError catch (e) {
      if (mounted) setState(() => _error = '${e.code}: ${e.message}');
    }
  }

  void _showImageSheet(String title, Uint8List bytes) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(sheetCtx).textTheme.titleMedium),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(sheetCtx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _textureId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Live stream')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: _size?.aspectRatio ?? 9 / 16,
            child: ColoredBox(
              color: Colors.black,
              child: _textureId == null
                  ? const Center(
                      child: Text(
                        'Start streaming to see frames',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : Texture(textureId: _textureId!),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Session: ${_sessionState.name}'
                  "${_size != null ? '   ${_size!.width}x${_size!.height}' : ''}",
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isRunning ? null : _start,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isRunning ? _stop : null,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: isRunning ? _capturePhoto : null,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Photo'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: isRunning ? _captureFrame : null,
                        icon: const Icon(Icons.image),
                        label: const Text('Frame'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
