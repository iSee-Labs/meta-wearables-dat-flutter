---
description: Build a complete Flutter DAT app - registration, streaming, photo capture, recording, mock-device debug menu
globs: example/**, samples/camera_access/**
---

# Sample App Guide (Flutter)

Walks through building a Flutter app that connects to Meta glasses,
streams video, captures photos, records, and exercises the Mock
Device Kit.

Reference: [`samples/camera_access/`](../../samples/camera_access/).

## Architecture

```
samples/camera_access/lib/
├── main.dart                       # bootstrap + MaterialApp
└── src/
    ├── app.dart                    # navigation
    ├── view_models/
    │   ├── wearables_view_model.dart        # registration + devices
    │   └── stream_session_view_model.dart   # streaming + capture
    └── screens/
        ├── home_screen.dart        # registration UI + entry points
        ├── stream_screen.dart      # Texture + capture button
        ├── recording_screen.dart   # videoFramesStream → file
        ├── devices_screen.dart     # paired-device list + compatibility
        ├── settings_sheet.dart     # FPS / quality / codec / background
        └── mock_kit_screen.dart    # Mock Device Kit debug menu
```

## SDK initialization

The plugin self-initializes; just import it in `main.dart`.

```dart
import 'package:flutter/material.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}
```

## Wearables view model

```dart
class WearablesViewModel extends ChangeNotifier {
  RegistrationState registration = RegistrationState.unregistered;
  Device? activeDevice;
  List<Device> devices = [];

  WearablesViewModel() {
    MetaWearablesDat.registrationStateStream().listen((s) {
      registration = s; notifyListeners();
    });
    MetaWearablesDat.activeDeviceStream().listen((d) {
      activeDevice = d; notifyListeners();
    });
    MetaWearablesDat.devicesStream().listen((list) {
      devices = list; notifyListeners();
    });
  }

  Future<void> register() => MetaWearablesDat.startRegistration(
    appId: '0',
    urlScheme: 'mywearablesapp',
  );

  Future<void> unregister() => MetaWearablesDat.startUnregistration();
}
```

## Stream view model

```dart
class StreamSessionViewModel extends ChangeNotifier {
  int? textureId;
  StreamSessionState state = StreamSessionState.stopped;
  Size? videoSize;

  Future<void> start({int fps = 24, VideoCodec codec = VideoCodec.raw}) async {
    textureId = await MetaWearablesDat.startStreamSession(
      fps: fps, videoCodec: codec,
    );
    notifyListeners();
  }

  Future<void> stop() async {
    await MetaWearablesDat.stopStreamSession();
    textureId = null;
    notifyListeners();
  }

  Future<Uint8List> capturePhoto() => MetaWearablesDat.capturePhoto();
}
```

## Stream UI

```dart
class StreamScreen extends StatelessWidget {
  final StreamSessionViewModel vm;
  const StreamScreen(this.vm, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        if (vm.textureId != null)
          Center(child: Texture(textureId: vm.textureId!)),
        Positioned(
          bottom: 32, right: 16,
          child: FloatingActionButton(
            child: const Icon(Icons.camera_alt),
            onPressed: () async {
              final bytes = await vm.capturePhoto();
              await showModalBottomSheet(
                context: context,
                builder: (_) => PhotoSheet(bytes),
              );
            },
          ),
        ),
      ]),
    );
  }
}
```

## Recording

Subscribe to `videoFramesStream` and append payloads to a file:

```dart
final file = File(p.join(dir.path, 'capture.h265'));
final sink = file.openWrite();
final sub = MetaWearablesDat.videoFramesStream().listen((frame) {
  sink.add(frame.bytes);
});
// ...
await sub.cancel();
await sink.close();
```

The plugin emits raw NAL bytes for `VideoCodec.hvc1` (iOS) or
I420 planar bytes for `VideoCodec.raw` on Android. Muxing to mp4 is
the host app's concern (e.g. via `ffmpeg_kit_flutter`).

## Mock-device debug menu

```dart
ElevatedButton(
  child: const Text('Pair Ray-Ban Meta'),
  onPressed: () async {
    await MetaWearablesDat.enableMockDevice();
    await MetaWearablesDat.pairMockRaybanMeta();
  },
),
```

Wire one button per Mock Kit action — that's the layout of
`mock_kit_screen.dart`.

## Allowed dependencies

The sample uses a small list of helpers (`path_provider`, `share_plus`).
Do not add dependencies to the plugin itself.

## Links

- [`samples/camera_access/`](../../samples/camera_access/)
- [`example/`](../../example/) — minimal end-to-end example
