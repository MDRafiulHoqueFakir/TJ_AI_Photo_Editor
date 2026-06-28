import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'image_engine.dart';

/// Phase-1 pure-Dart implementation of [ImageEngine].
///
/// Correct but not real-time; the editor uses a downscaled proxy for live
/// preview and only runs full-res through here on export. Replace with the
/// FFI/GPU engine in Phase 2 without touching callers.
class DartImageEngine implements ImageEngine {
  const DartImageEngine();

  @override
  Future<Uint8List> applyAdjustments(
    Uint8List source, {
    double brightness = 0,
    double contrast = 0,
    double saturation = 0,
  }) async {
    final image = img.decodeImage(source);
    if (image == null) return source;

    var out = image;
    if (brightness != 0 || contrast != 0 || saturation != 0) {
      out = img.adjustColor(
        out,
        // package:image expects brightness 0..2 (1 = neutral) and
        // contrast/saturation 0..2 (1 = neutral); map our -1..1 range.
        brightness: 1 + brightness,
        contrast: 1 + contrast,
        saturation: 1 + saturation,
      );
    }
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
  }

  @override
  Future<Uint8List> resize(
    Uint8List source, {
    required int width,
    required int height,
  }) async {
    final image = img.decodeImage(source);
    if (image == null) return source;
    final out = img.copyResize(
      image,
      width: width,
      height: height,
      interpolation: img.Interpolation.cubic,
    );
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
  }

  @override
  Future<Uint8List> export(
    Uint8List source, {
    required ExportFormat format,
    int quality = 90,
    bool watermark = true,
  }) async {
    var image = img.decodeImage(source);
    if (image == null) return source;

    if (watermark) {
      image = _stampWatermark(image);
    }

    switch (format) {
      case ExportFormat.jpeg:
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      case ExportFormat.png:
        return Uint8List.fromList(img.encodePng(image));
      case ExportFormat.webp:
        // package:image has no webp encoder; fall back to png for Phase 1.
        return Uint8List.fromList(img.encodePng(image));
    }
  }

  img.Image _stampWatermark(img.Image image) {
    final text = 'TJ Photo Editor';
    img.drawString(
      image,
      text,
      font: img.arial24,
      x: 12,
      y: image.height - 36,
      color: img.ColorRgba8(255, 255, 255, 180),
    );
    return image;
  }
}
