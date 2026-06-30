import 'dart:math' as math;
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
  Future<Uint8List> fitWithin(Uint8List source, {required int maxLongEdge}) async {
    final image = img.decodeImage(source);
    if (image == null) return source;
    final longest = image.width > image.height ? image.width : image.height;
    if (longest <= maxLongEdge) return source;
    final scale = maxLongEdge / longest;
    final out = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.average,
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

    // Flat raw-byte blend (no per-pixel objects): out = src*(1-a) + blur*a.
    final src = image.getBytes(order: img.ChannelOrder.rgba);
    final blur = blurred.getBytes(order: img.ChannelOrder.rgba);
    final inv = 1 - a;
    for (var i = 0; i < src.length; i += 4) {
      src[i] = (src[i] * inv + blur[i] * a).toInt();
      src[i + 1] = (src[i + 1] * inv + blur[i + 1] * a).toInt();
      src[i + 2] = (src[i + 2] * inv + blur[i + 2] * a).toInt();
    }
    final out = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: src.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
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

    final w = image.width;
    final h = image.height;
    // Non-uniform squeeze/expand: slim<0 narrows (thinner), stretch>0 heightens.
    var newW = (w * (1 + slim.clamp(-1.0, 1.0) * 0.18)).round();
    var newH = (h * (1 + stretch.clamp(-1.0, 1.0) * 0.18)).round();
    newW = newW < 1 ? 1 : newW;
    newH = newH < 1 ? 1 : newH;
    var scaled = img.copyResize(image, width: newW, height: newH);

    // Cover-fit back to (w, h) so the frame is filled — no black bars.
    final coverScale = math.max(w / newW, h / newH);
    if (coverScale > 1.0) {
      scaled = img.copyResize(
        scaled,
        width: (newW * coverScale).ceil(),
        height: (newH * coverScale).ceil(),
      );
    }
    final cx = ((scaled.width - w) / 2).round().clamp(0, scaled.width - w);
    final cy = ((scaled.height - h) / 2).round().clamp(0, scaled.height - h);
    final out = img.copyCrop(scaled, x: cx, y: cy, width: w, height: h);
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
  }

  @override
  Future<Uint8List> cropToAspect(Uint8List source, {required double ratio}) async {
    final image = img.decodeImage(source);
    if (image == null) return source;
    final w = image.width;
    final h = image.height;
    final current = w / h;
    int cw, ch;
    if (current > ratio) {
      ch = h;
      cw = (h * ratio).round();
    } else {
      cw = w;
      ch = (w / ratio).round();
    }
    cw = cw.clamp(1, w);
    ch = ch.clamp(1, h);
    final out = img.copyCrop(
      image,
      x: ((w - cw) / 2).round(),
      y: ((h - ch) / 2).round(),
      width: cw,
      height: ch,
    );
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
  }

  @override
  Future<Uint8List> cropToRect(
    Uint8List source, {
    required double left,
    required double top,
    required double width,
    required double height,
  }) async {
    final image = img.decodeImage(source);
    if (image == null) return source;
    final x = (left * image.width).round().clamp(0, image.width - 1);
    final y = (top * image.height).round().clamp(0, image.height - 1);
    final w = (width * image.width).round().clamp(1, image.width - x);
    final h = (height * image.height).round().clamp(1, image.height - y);
    final out = img.copyCrop(image, x: x, y: y, width: w, height: h);
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
  }

  @override
  Future<Uint8List> denoise(Uint8List source, {double amount = 0.5}) async {
    final image = img.decodeImage(source);
    if (image == null) return source;
    final a = amount.clamp(0.0, 1.0);
    if (a == 0) return source;
    // Blur slightly, then blend back to keep edges — a light denoise.
    final radius = (1 + a * 2).round();
    final blurred = img.gaussianBlur(image.clone(), radius: radius);
    final blend = 0.6 * a;
    final inv = 1 - blend;
    final src = image.getBytes(order: img.ChannelOrder.rgba);
    final blur = blurred.getBytes(order: img.ChannelOrder.rgba);
    for (var i = 0; i < src.length; i += 4) {
      src[i] = (src[i] * inv + blur[i] * blend).toInt();
      src[i + 1] = (src[i + 1] * inv + blur[i + 1] * blend).toInt();
      src[i + 2] = (src[i + 2] * inv + blur[i + 2] * blend).toInt();
    }
    final out = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: src.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
  }

  @override
  Future<Uint8List> hdr(Uint8List source, {double amount = 0.6}) async {
    final image = img.decodeImage(source);
    if (image == null) return source;
    final a = amount.clamp(0.0, 1.0);
    var out = img.normalize(image.clone(), min: 0, max: 255);
    out = img.adjustColor(out, contrast: 1 + 0.25 * a, saturation: 1 + 0.2 * a);
    // Local-contrast pop via unsharp-like convolution.
    out = img.convolution(out, filter: [0, -1, 0, -1, 5, -1, 0, -1, 0], div: 1);
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
  }

  @override
  Future<Uint8List> upscale(Uint8List source, {int factor = 2}) async {
    final image = img.decodeImage(source);
    if (image == null) return source;
    final out = img.copyResize(
      image,
      width: image.width * factor,
      height: image.height * factor,
      interpolation: img.Interpolation.cubic,
    );
    return Uint8List.fromList(img.encodePng(out));
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
  Future<Uint8List> heal(
    Uint8List source, {
    required double dx,
    required double dy,
    required double radius,
  }) async {
    final image = img.decodeImage(source);
    if (image == null) return source;

    final minSide = image.width < image.height ? image.width : image.height;
    final r = (radius * minSide).clamp(2.0, minSide.toDouble());
    final cx = dx * image.width;
    final cy = dy * image.height;

    // Average colour of the ring [r .. 1.8r] = clean skin around the blemish.
    var sr = 0.0, sg = 0.0, sb = 0.0, n = 0;
    final outer = r * 1.8;
    final x0 = (cx - outer).floor().clamp(0, image.width - 1);
    final x1 = (cx + outer).ceil().clamp(0, image.width - 1);
    final y0 = (cy - outer).floor().clamp(0, image.height - 1);
    final y1 = (cy + outer).ceil().clamp(0, image.height - 1);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final d = _dist(x - cx, y - cy);
        if (d >= r && d <= outer) {
          final p = image.getPixel(x, y);
          sr += p.r;
          sg += p.g;
          sb += p.b;
          n++;
        }
      }
    }
    if (n == 0) return source;
    final ar = sr / n, ag = sg / n, ab = sb / n;

    // Feathered fill: full inside r, fading to 0 by 1.4r.
    final feather = r * 1.4;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final d = _dist(x - cx, y - cy);
        if (d > feather) continue;
        final t = d <= r ? 1.0 : (feather - d) / (feather - r);
        final p = image.getPixel(x, y);
        image.setPixelRgb(
          x,
          y,
          p.r * (1 - t) + ar * t,
          p.g * (1 - t) + ag * t,
          p.b * (1 - t) + ab * t,
        );
      }
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 95));
  }

  double _dist(num a, num b) => math.sqrt(a * a + b * b);

  @override
  Future<Uint8List> faceAdjust(
    Uint8List source, {
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    double brighten = 0,
    double smooth = 0,
    double slim = 0,
  }) async {
    final image = img.decodeImage(source);
    if (image == null) return source;
    if (brighten == 0 && smooth == 0 && slim == 0) return source;

    final w = image.width;
    final h = image.height;
    final centerX = cx * w;
    final centerY = cy * h;
    final radX = (rx * w).clamp(1.0, w.toDouble());
    final radY = (ry * h).clamp(1.0, h.toDouble());

    final blurred = smooth > 0
        ? img.gaussianBlur(image.clone(), radius: (1 + smooth * 4).round())
        : null;

    // Raw byte buffers: sample from src, write to out (no per-pixel objects).
    final srcB = image.getBytes(order: img.ChannelOrder.rgba);
    final outB = Uint8List.fromList(srcB);
    final blurB = blurred?.getBytes(order: img.ChannelOrder.rgba);

    final x0 = (centerX - radX * 1.4).floor().clamp(0, w - 1);
    final x1 = (centerX + radX * 1.4).ceil().clamp(0, w - 1);
    final y0 = (centerY - radY * 1.4).floor().clamp(0, h - 1);
    final y1 = (centerY + radY * 1.4).ceil().clamp(0, h - 1);

    for (var y = y0; y <= y1; y++) {
      final rowBase = y * w;
      for (var x = x0; x <= x1; x++) {
        final nx = (x - centerX) / radX;
        final ny = (y - centerY) / radY;
        final d = math.sqrt(nx * nx + ny * ny);
        if (d > 1.4) continue;
        final mask = d <= 1.0 ? 1.0 : (1.4 - d) / 0.4; // feathered edge

        // slim<0 = thinner (sample wider), slim>0 = wider (sample narrower).
        var sx = x.toDouble();
        if (slim != 0) sx = centerX + (x - centerX) * (1 - slim * 0.6 * mask);
        final sxi = sx.round().clamp(0, w - 1);
        final si = (rowBase + sxi) * 4;
        var r = srcB[si].toDouble();
        var g = srcB[si + 1].toDouble();
        var b = srcB[si + 2].toDouble();

        if (blurB != null) {
          final t = smooth * mask * 0.85;
          r = r * (1 - t) + blurB[si] * t;
          g = g * (1 - t) + blurB[si + 1] * t;
          b = b * (1 - t) + blurB[si + 2] * t;
        }
        if (brighten != 0) {
          final add = brighten * 60 * mask;
          r += add;
          g += add;
          b += add;
        }
        final oi = (rowBase + x) * 4;
        outB[oi] = r.clamp(0, 255).toInt();
        outB[oi + 1] = g.clamp(0, 255).toInt();
        outB[oi + 2] = b.clamp(0, 255).toInt();
      }
    }
    final out = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: outB.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return Uint8List.fromList(img.encodeJpg(out, quality: 92));
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
