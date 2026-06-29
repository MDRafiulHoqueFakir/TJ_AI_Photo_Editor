import 'dart:typed_data';
import 'dart:ui' as ui;

import '../domain/collage_layout.dart';

/// Renders the collage to a square image at full resolution using the same
/// cover-fit math as the preview, so the export matches what the user sees.
/// Uses dart:ui (PictureRecorder) → works on web and mobile alike.
abstract class CollageRenderer {
  static Future<Uint8List?> render({
    required CollageLayout layout,
    required Map<int, ui.Image> images,
    required int size,
    required double spacing,
    required int bgArgb,
  }) async {
    final s = size.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, s, s),
      ui.Paint()..color = ui.Color(bgArgb),
    );

    final gap = spacing * s;
    for (var i = 0; i < layout.cells.length; i++) {
      final image = images[i];
      if (image == null) continue;
      final c = layout.cells[i];
      final dest = ui.Rect.fromLTRB(c.left * s, c.top * s, c.right * s, c.bottom * s)
          .deflate(gap / 2);
      if (dest.width <= 0 || dest.height <= 0) continue;
      final src = _coverSrc(
        image.width.toDouble(),
        image.height.toDouble(),
        dest.width / dest.height,
      );
      canvas.drawImageRect(
        image,
        src,
        dest,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
    }

    final picture = recorder.endRecording();
    final out = await picture.toImage(size, size);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    out.dispose();
    return data?.buffer.asUint8List();
  }

  /// Center-crop source rect so the image covers [destAspect] without distortion.
  static ui.Rect _coverSrc(double iw, double ih, double destAspect) {
    final imgAspect = iw / ih;
    if (imgAspect > destAspect) {
      final sw = ih * destAspect;
      return ui.Rect.fromLTWH((iw - sw) / 2, 0, sw, ih);
    } else {
      final sh = iw / destAspect;
      return ui.Rect.fromLTWH(0, (ih - sh) / 2, iw, sh);
    }
  }
}
