import 'package:camera_access/src/app.dart';
import 'package:flutter/material.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

void main() {
  runApp(const CameraAccessApp());
}

/// Root of the polished sample. Mirrors Meta's CameraAccess sample on iOS
/// and Android: home screen lists "Connect glasses", "Stream", and
/// "MockDeviceKit"; each route showcases a slice of the plugin API.
class CameraAccessApp extends StatelessWidget {
  const CameraAccessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Access (Flutter)',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1877F2),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1877F2),
          brightness: Brightness.dark,
        ),
      ),
      home: const App(),
    );
  }
}

/// Re-exported for convenience so consumers can find the type without
/// digging into `lib/src/`.
typedef MetaPlugin = MetaWearablesDat;
