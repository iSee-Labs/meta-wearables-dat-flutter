import 'package:display_access/src/app.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DisplayAccessApp());
}

/// Root of the polished Display Access sample. Mirrors Meta's official iOS and
/// Android "Car Maintenance" Display sample: connect Ray-Ban Display glasses,
/// attach a display session, then drive a declarative tutorial UI (list ->
/// detail -> steps -> video) rendered on the glasses.
class DisplayAccessApp extends StatelessWidget {
  const DisplayAccessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Display Access (Flutter)',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1877F2)),
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
