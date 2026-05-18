import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera_access/src/settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Streaming preview screen.
///
/// Mirrors the structure of Meta's official Camera Access iOS / Android
/// samples: a `Texture` preview at the top, a status row, a SettingsSheet
/// for FPS / quality / codec / background-streaming, and a row of action
/// buttons (Photo / Frame / Record).
class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  int? _textureId;
  StreamSessionState _sessionState = StreamSessionState.stopped;
  VideoStreamSize? _size;
  String? _error;
  StreamSettings _settings = const StreamSettings();
  bool _starting = false;

  StreamSubscription<StreamSessionState>? _stateSub;
  StreamSubscription<Object>? _errorSub;
  StreamSubscription<VideoStreamSize>? _sizeSub;
  StreamSubscription<VideoFrame>? _framesSub;

  IOSink? _recordingSink;
  String? _recordingPath;
  int _recordedFrames = 0;

  @override
  void initState() {
    super.initState();
    _stateSub = MetaWearablesDat.streamSessionStateStream().listen(
      (s) {
        if (mounted) setState(() => _sessionState = s);
      },
    );
    _errorSub = MetaWearablesDat.streamSessionErrorStream().listen(
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
    _framesSub?.cancel();
    unawaited(_recordingSink?.close());
    if (_textureId != null) {
      unawaited(MetaWearablesDat.stopStreamSession());
    }
    super.dispose();
  }

  bool get _isRunning => _textureId != null;
  bool get _isRecording => _recordingSink != null;

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      // Pick the first paired device explicitly. The plugin's Android
      // path used to fall through to `AutoDeviceSelector` when no
      // `deviceUUID` was passed, which Meta's Android SDK 0.6.0
      // rejects with `noEligibleDevice` even after a successful
      // registration handshake (the auto-selector requires don-sensor
      // signal that may not be present right after pairing). Pinning
      // `SpecificDeviceSelector` matches what the iOS bridge has
      // always done and avoids the gap; the plugin v0.1.6+ does this
      // pinning itself, but we keep the explicit call here as a
      // belt-and-suspenders for older plugin versions and as a
      // self-documenting example.
      final devices = await MetaWearablesDat.getDevices();
      final id = await MetaWearablesDat.startStreamSession(
        deviceUUID: devices.isNotEmpty ? devices.first.uuid : null,
        fps: _settings.fps,
        quality: _settings.quality,
        videoCodec: _settings.codec,
      );
      if (!mounted) return;
      setState(() => _textureId = id);
      if (_settings.backgroundStreaming) {
        await _enableBackground();
      }
    } on DatError catch (e) {
      if (mounted) setState(() => _error = '${e.code}: ${e.message}');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stop() async {
    try {
      await _stopRecording();
      if (_settings.backgroundStreaming) {
        await MetaWearablesDat.disableBackgroundStreaming();
      }
      await MetaWearablesDat.stopStreamSession();
      if (mounted) setState(() => _textureId = null);
    } on DatError catch (e) {
      if (mounted) setState(() => _error = '${e.code}: ${e.message}');
    }
  }

  Future<void> _enableBackground() async {
    final notification = Platform.isAndroid
        ? const BackgroundNotification(
            title: 'Camera Access',
            text: 'Streaming from Meta Wearables in the background',
            channelId: 'camera_access_background',
            channelName: 'Background streaming',
          )
        : null;
    await MetaWearablesDat.enableBackgroundStreaming(
      androidNotification: notification,
    );
  }

  Future<void> _capturePhoto() async {
    try {
      final photo = await MetaWearablesDat.capturePhoto();
      if (!mounted) return;
      _showPhotoSheet(photo);
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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final isHevc = _settings.codec == VideoCodec.hvc1;
    final ext = isHevc ? 'h265' : 'yuv';
    final path = '${dir.path}/meta_recording_$ts.$ext';
    final file = File(path);
    final sink = file.openWrite();
    setState(() {
      _recordingSink = sink;
      _recordingPath = path;
      _recordedFrames = 0;
    });
    _framesSub = MetaWearablesDat.videoFramesStream().listen((frame) {
      final s = _recordingSink;
      if (s == null) return;
      s.add(frame.bytes);
      _recordedFrames++;
      if (_recordedFrames % 30 == 0 && mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _stopRecording() async {
    await _framesSub?.cancel();
    _framesSub = null;
    final sink = _recordingSink;
    final path = _recordingPath;
    _recordingSink = null;
    if (sink == null) return;
    await sink.flush();
    await sink.close();
    if (!mounted || path == null) return;
    setState(() {
      _recordingPath = null;
    });
    final note = _settings.codec == VideoCodec.hvc1
        ? 'Raw HEVC NAL stream (.h265). Not yet wrapped in mp4.'
        : 'Raw I420 frames (.yuv). Not yet wrapped in mp4.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved $_recordedFrames frames to $path.\n$note'),
        action: SnackBarAction(
          label: 'Share',
          onPressed: () => unawaited(Share.shareXFiles([XFile(path)])),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _openSettings() async {
    final next = await showModalBottomSheet<StreamSettings>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SettingsSheet(
        initial: _settings,
        onDisconnect: () async {
          try {
            await MetaWearablesDat.startUnregistration();
          } on DatError catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Disconnect failed: ${e.code}')),
            );
          }
        },
      ),
    );
    if (next != null && mounted) {
      setState(() => _settings = next);
    }
  }

  void _showImageSheet(String title, Uint8List bytes) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: Theme.of(sheetCtx).textTheme.titleMedium),
            const SizedBox(height: 12),
            Flexible(
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

  void _showPhotoSheet(PhotoResult photo) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Photo (${photo.format.name})',
              style: Theme.of(sheetCtx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Image.memory(photo.bytes, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                    onPressed: () async {
                      final dir = await getTemporaryDirectory();
                      final ts = DateTime.now().millisecondsSinceEpoch;
                      final ext = photo.format.name;
                      final path = '${dir.path}/meta_photo_$ts.$ext';
                      await File(path).writeAsBytes(photo.bytes);
                      await Share.shareXFiles([XFile(path)]);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live stream'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Flexible(
            child: AspectRatio(
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
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Session: '
                  '${_starting ? "connecting…" : _sessionState.name} • '
                  '${_settings.fps} fps • '
                  '${_settings.quality.name} • ${_settings.codec.name}'
                  "${_size != null ? ' • ${_size!.width}x${_size!.height}' : ''}",
                ),
                if (_isRecording) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Recording • $_recordedFrames frames written',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_isRunning || _starting) ? null : _start,
                        icon: _starting
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_starting ? 'Connecting…' : 'Start'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isRunning ? _stop : null,
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
                        onPressed: _isRunning ? _capturePhoto : null,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Photo'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _isRunning ? _captureFrame : null,
                        icon: const Icon(Icons.image),
                        label: const Text('Frame'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _isRunning ? _toggleRecording : null,
                        icon: Icon(
                          _isRecording
                              ? Icons.stop_circle_outlined
                              : Icons.fiber_manual_record,
                        ),
                        label: Text(_isRecording ? 'Stop rec' : 'Record'),
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
