import 'dart:typed_data';
import 'dart:ui' as ui;

import 'adjustment_params.dart';

/// Renders the adjustments shader to a full-resolution [ui.Image] and encodes
/// it. The same shader used for the live proxy preview is replayed here at the
/// source resolution, so what the user sees is exactly what exports — the
/// proxy/full-res split costs nothing in fidelity.
class GpuExporter {
  const GpuExporter(this.program);

  final ui.FragmentProgram program;

  Future<Uint8List?> render(
    ui.Image source,
    AdjustmentParams params, {
    ui.ImageByteFormat format = ui.ImageByteFormat.png,
  }) async {
    final w = source.width;
    final h = source.height;

    final shader = program.fragmentShader()
      ..setFloat(0, w.toDouble())
      ..setFloat(1, h.toDouble())
      ..setImageSampler(0, source);
    params.applyTo(shader, startIndex: 2);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..shader = shader,
    );
    final picture = recorder.endRecording();
    final outImage = await picture.toImage(w, h);
    final data = await outImage.toByteData(format: format);

    picture.dispose();
    outImage.dispose();
    return data?.buffer.asUint8List();
  }
}
