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

/// Downscale a [ui.Image] on the GPU so its longest edge is at most
/// [maxLongEdge] (keeps aspect). Returns the same image if it already fits.
/// Used to bound the working image WITHOUT CPU (package:image) decoding, which
/// freezes the tab on web for large photos.
Future<ui.Image> downscaleUiImage(ui.Image src, int maxLongEdge) async {
  final longest = src.width > src.height ? src.width : src.height;
  if (longest <= maxLongEdge) return src;
  final scale = maxLongEdge / longest;
  final w = (src.width * scale).round();
  final h = (src.height * scale).round();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    src,
    ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final out = await picture.toImage(w, h);
  picture.dispose();
  return out;
}

/// Encode a [ui.Image] back to PNG bytes (native, used as the CPU-stack base).
Future<Uint8List?> encodeUiImage(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
