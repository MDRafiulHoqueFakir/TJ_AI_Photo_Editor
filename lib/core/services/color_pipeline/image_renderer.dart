import 'dart:typed_data';
import 'dart:ui' as ui;

import '../gpu/adjustment_params.dart';
import 'color_adjustments.dart';

/// Full-resolution export, cross-platform. Replays the same color-matrix +
/// vignette used in the live preview onto a [ui.PictureRecorder] at source
/// resolution, so preview fidelity == export on web and mobile alike.
abstract class ImageRenderer {
  static Future<Uint8List?> render(
    ui.Image source,
    AdjustmentParams params, {
    List<double>? filterMatrix,
    ui.ImageByteFormat format = ui.ImageByteFormat.png,
  }) async {
    final w = source.width;
    final h = source.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.drawImage(
      source,
      ui.Offset.zero,
      ui.Paint()
        ..colorFilter = composedColorFilter(params, filterMatrix)
        ..filterQuality = ui.FilterQuality.high,
    );

    if (params.vignette > 0) {
      final rect = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
      final shader = ui.Gradient.radial(
        rect.center,
        (w > h ? w : h) / 2 * 0.9,
        [const ui.Color(0x00000000), vignetteColor(params.vignette)],
        [0.55, 1.0],
      );
      canvas.drawRect(rect, ui.Paint()..shader = shader);
    }

    final picture = recorder.endRecording();
    final outImage = await picture.toImage(w, h);
    final data = await outImage.toByteData(format: format);

    picture.dispose();
    outImage.dispose();
    return data?.buffer.asUint8List();
  }
}
