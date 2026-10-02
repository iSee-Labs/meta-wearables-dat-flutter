import 'package:flutter/foundation.dart';

/// The device the user picked on the Devices tab, shared by every tab.
///
/// `null` lets the plugin pick the best connected, worn device.
final ValueNotifier<String?> selectedDevice = ValueNotifier<String?>(null);
