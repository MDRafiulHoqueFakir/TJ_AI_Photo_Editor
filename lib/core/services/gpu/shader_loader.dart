import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loads the adjustments fragment program once and caches it. Compiling a
/// FragmentProgram is not free, so we do it a single time at startup and reuse
/// the program for every frame (a fresh `fragmentShader()` per paint is cheap).
final adjustmentsProgramProvider = FutureProvider<ui.FragmentProgram>((_) {
  return ui.FragmentProgram.fromAsset('shaders/adjustments.frag');
});

/// Decode encoded bytes (JPEG/PNG) into a GPU-resident [ui.Image] once, so the
/// live preview samples a texture instead of re-decoding every frame.
Future<ui.Image> decodeUiImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}
