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
  Future<Uint8List> crop(
    Uint8List source, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    final image = img.decodeImage(source);
    if (image == null) return source;
    final out = img.copyCrop(image, x: x, y: y, width: width, height: height);
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
  }

  @override
  Future<Uint8List> orient(
    Uint8List source, {
    double degrees = 0,
    bool flipH = false,
  }) async {
    var image = img.decodeImage(source);
    if (image == null) return source;
    if (degrees != 0) image = img.copyRotate(image, angle: degrees);
    if (flipH) image = img.flipHorizontal(image);
    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  @override
  Future<Uint8List> smoothSkin(Uint8List source, {double amount = 0.3}) async {
    final image = img.decodeImage(source);
    if (image == null) return source;
    final a = amount.clamp(0.0, 1.0);
    if (a == 0) return source;

    final radius = (1 + a * 4).round();
    final blurred = img.gaussianBlur(image.clone(), radius: radius);

    // Blend original toward blurred by [a]: out = src*(1-a) + blur*a.
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final s = image.getPixel(x, y);
        final b = blurred.getPixel(x, y);
        image.setPixelRgb(
          x,
          y,
          s.r * (1 - a) + b.r * a,
          s.g * (1 - a) + b.g * a,
          s.b * (1 - a) + b.b * a,
        );
      }
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  @override
  Future<Uint8List> reshapeBody(
    Uint8List source, {
    double slim = 0,
    double stretch = 0,
  }) async {
    final image = img.decodeImage(source);
    if (image == null) return source;
    if (slim == 0 && stretch == 0) return source;

    // Non-uniform scale then center-crop/pad back to the original canvas, so the
    // output keeps the same dimensions while the subject appears slimmer/taller.
    final newW = (image.width * (1 + slim.clamp(-1, 1) * 0.18)).round();
    final newH = (image.height * (1 + stretch.clamp(-1, 1) * 0.18)).round();
    final scaled = img.copyResize(image, width: newW, height: newH);

    final canvas = img.Image(width: image.width, height: image.height);
    img.fill(canvas, color: img.ColorRgb8(0, 0, 0));
    final dx = ((image.width - newW) / 2).round();
    final dy = ((image.height - newH) / 2).round();
    img.compositeImage(canvas, scaled, dstX: dx, dstY: dy);
    return Uint8List.fromList(img.encodeJpg(canvas, quality: 92));
  }

  @override
  Future<Uint8List> replaceBackground(
    Uint8List source, {
    Uint8List? subjectMask,
    required int bgArgb,
  }) async {
    final image = img.decodeImage(source);
    if (image == null) return source;

    final a = (bgArgb >> 24) & 0xFF;
    final r = (bgArgb >> 16) & 0xFF;
    final g = (bgArgb >> 8) & 0xFF;
    final b = bgArgb & 0xFF;
    final mask = subjectMask == null ? null : img.decodeImage(subjectMask);

    if (mask == null) {
      // No ML mask available: produce a flat-background canvas behind a centered
      // copy is out of scope here, so tint the whole canvas (clearly visible
      // placeholder until segmentation lands in Phase 2 native).
      final canvas = img.Image(width: image.width, height: image.height);
      img.fill(canvas, color: img.ColorRgba8(r, g, b, a));
      img.compositeImage(canvas, image, blend: img.BlendMode.alpha);
      return Uint8List.fromList(img.encodeJpg(canvas, quality: 92));
    }

    // Keep subject where mask luminance is high; replace elsewhere with bg color.
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final m = mask.getPixel(x, y).luminanceNormalized;
        if (m < 0.5) image.setPixelRgb(x, y, r, g, b);
      }
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  @override
  Future<Uint8List> frame(
    Uint8List source, {
    required int borderPx,
    required int bottomExtraPx,
    required int colorArgb,
  }) async {
    final image = img.decodeImage(source);
    if (image == null) return source;
    if (borderPx <= 0 && bottomExtraPx <= 0) return source;

    final a = (colorArgb >> 24) & 0xFF;
    final r = (colorArgb >> 16) & 0xFF;
    final g = (colorArgb >> 8) & 0xFF;
    final b = colorArgb & 0xFF;

    final canvas = img.Image(
      width: image.width + borderPx * 2,
      height: image.height + borderPx * 2 + bottomExtraPx,
    );
    img.fill(canvas, color: img.ColorRgba8(r, g, b, a));
    img.compositeImage(canvas, image, dstX: borderPx, dstY: borderPx);
    return Uint8List.fromList(img.encodeJpg(canvas, quality: 95));
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
    const text = 'TJ Photo Editor';
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
