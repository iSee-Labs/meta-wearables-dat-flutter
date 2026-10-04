// The high-resolution photo button uses an experimental API.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:glasses_companion/src/selection.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

/// Camera preview through a Flutter texture, plus photo capture.
class CameraTab extends StatefulWidget {
  const CameraTab({super.key});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab> {
  int? _textureId;
  VideoStreamSize? _size;
  StreamSessionState _state = StreamSessionState.stopped;
  StreamQuality _quality = StreamQuality.medium;
  Uint8List? _photo;
  String? _status;
  bool _busy = false;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    _subs
      ..add(
        MetaWearablesDat.streamSessionStateStream().listen((s) {
          setState(() {
            _state = s;
            // The device can end the stream (hinges closed, thermal limit):
            // the plugin releases the texture, so drop our reference too.
            if (s == StreamSessionState.stopped) _textureId = null;
          });
        }),
      )
      ..add(
        MetaWearablesDat.videoStreamSizeStream().listen(
          (s) => setState(() => _size = s),
        ),
      )
      ..add(
        MetaWearablesDat.streamErrorStream().listen(
          (e) => setState(() => _status = '${e.code}: ${e.message}'),
        ),
      );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    if (_textureId != null) unawaited(MetaWearablesDat.stopStreamSession());
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
    } on DatError catch (e) {
      setState(() => _status = '${e.category}/${e.code}: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _run(() async {
    final id = await MetaWearablesDat.startStreamSession(
      deviceUUID: selectedDevice.value,
      // hvc1 keeps streaming while the app is in the background on iOS and
      // is decoded to the texture on both platforms.
      config: StreamSessionConfig(
        quality: _quality,
        videoCodec: VideoCodec.hvc1,
      ),
    );
    setState(() => _textureId = id);
  });

  Future<void> _stop() => _run(() async {
    await MetaWearablesDat.stopStreamSession();
    setState(() => _textureId = null);
  });

  Future<void> _photoFromStream() => _run(() async {
    final photo = await MetaWearablesDat.capturePhoto();
    setState(() => _photo = photo.bytes);
  });

  Future<void> _highResPhoto() => _run(() async {
    final photo = await MetaWearablesDat.captureHighResPhoto(
      resolution: PhotoResolution.large,
    );
    setState(() => _photo = photo.bytes);
  });

  @override
  Widget build(BuildContext context) {
    final running = _textureId != null;
    final size = _size;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(
          aspectRatio: size == null || size.height == 0
              ? 9 / 16
              : size.aspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: running
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Texture(textureId: _textureId!),
                  )
                : const Center(
                    child: Icon(Icons.videocam_off, color: Colors.white54),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'State: ${_state.name}'
          '${size == null ? '' : ' · ${size.width}x${size.height}'}',
        ),
        if (_status != null)
          Text(
            _status!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
        SegmentedButton<StreamQuality>(
          segments: [
            for (final q in StreamQuality.values)
              ButtonSegment(value: q, label: Text(q.name)),
          ],
          selected: {_quality},
          onSelectionChanged: running
              ? null
              : (s) => setState(() => _quality = s.single),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : (running ? _stop : _start),
              icon: Icon(running ? Icons.stop : Icons.play_arrow),
              label: Text(running ? 'Stop' : 'Start stream'),
            ),
            OutlinedButton.icon(
              onPressed: running && !_busy ? _photoFromStream : null,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Photo'),
            ),
            OutlinedButton.icon(
              onPressed: running && !_busy ? _highResPhoto : null,
              icon: const Icon(Icons.high_quality),
              label: const Text('High-res photo (experimental)'),
            ),
          ],
        ),
        if (_photo != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_photo!, gaplessPlayback: true),
          ),
        ],
      ],
    );
  }
}
