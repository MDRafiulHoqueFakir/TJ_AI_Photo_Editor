import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Phase 1: simple boot. Phase 2 wires RevenueCat + ML runtime init here.
  runApp(const ProviderScope(child: TJPhotoEditorApp()));
}
