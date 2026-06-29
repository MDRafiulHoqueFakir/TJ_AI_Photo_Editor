import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A government photo standard. Dimensions in millimetres; pixels derived at the
/// target [dpi] so the output is print-accurate.
class PassportSpec {
  const PassportSpec({
    required this.name,
    required this.widthMm,
    required this.heightMm,
    this.bgLabel = 'White',
    this.dpi = 300,
  });

  final String name;
  final double widthMm;
  final double heightMm;
  final String bgLabel;
  final int dpi;

  int get pxW => (widthMm / 25.4 * dpi).round();
  int get pxH => (heightMm / 25.4 * dpi).round();

  static const catalog = <PassportSpec>[
    PassportSpec(name: 'US Passport / Visa', widthMm: 50.8, heightMm: 50.8),
    PassportSpec(name: 'Bangladesh Passport', widthMm: 45, heightMm: 55),
    PassportSpec(name: 'Canada Passport', widthMm: 50, heightMm: 70),
    PassportSpec(name: 'Europe / Schengen', widthMm: 35, heightMm: 45, bgLabel: 'Light grey'),
    PassportSpec(name: 'Middle East (Gulf)', widthMm: 40, heightMm: 60),
    PassportSpec(name: 'India Passport', widthMm: 35, heightMm: 45),
    PassportSpec(name: 'UK Passport', widthMm: 35, heightMm: 45, bgLabel: 'Cream'),
    PassportSpec(name: 'China Visa', widthMm: 33, heightMm: 48),
  ];
}

/// Produces print-ready passport output in pure Dart (no ML required):
/// center-crops the photo to the exact standard aspect/size, then tiles as many
/// copies as fit onto a 6x4" sheet with cut guides.
///
/// Note: automatic background *removal* needs the on-device segmentation model
/// (Phase 2 native) — this tool crops & lays out; shoot against a plain wall.
abstract class PassportService {
  /// The single ID photo at the spec's exact pixel dimensions.
  static Uint8List buildSingle(Uint8List source, PassportSpec spec) {
    final image = img.decodeImage(source);
    if (image == null) return source;
    final cropped = _centerCropToAspect(image, spec.pxW, spec.pxH);
    final sized = img.copyResize(
      cropped,
      width: spec.pxW,
      height: spec.pxH,
      interpolation: img.Interpolation.cubic,
    );
    return Uint8List.fromList(img.encodePng(sized));
  }

  /// A 6x4 inch print sheet tiled with as many copies as fit, with cut guides.
  static Uint8List buildSheet(Uint8List source, PassportSpec spec) {
    final image = img.decodeImage(source);
    if (image == null) return source;

    final photo = img.copyResize(
      _centerCropToAspect(image, spec.pxW, spec.pxH),
      width: spec.pxW,
      height: spec.pxH,
      interpolation: img.Interpolation.cubic,
    );

    final dpi = spec.dpi;
    final sheetW = 6 * dpi; // landscape 6x4"
    final sheetH = 4 * dpi;
    final margin = (0.12 * dpi).round();
    final gap = (0.06 * dpi).round();

    final sheet = img.Image(width: sheetW, height: sheetH);
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));

    final cols = ((sheetW - 2 * margin + gap) / (spec.pxW + gap)).floor();
    final rows = ((sheetH - 2 * margin + gap) / (spec.pxH + gap)).floor();
    if (cols < 1 || rows < 1) {
      // Photo larger than the sheet — just return the single.
      return Uint8List.fromList(img.encodePng(photo));
    }

    final guide = img.ColorRgb8(200, 200, 200);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final x = margin + c * (spec.pxW + gap);
        final y = margin + r * (spec.pxH + gap);
        img.compositeImage(sheet, photo, dstX: x, dstY: y);
        img.drawRect(
          sheet,
          x1: x,
          y1: y,
          x2: x + spec.pxW - 1,
          y2: y + spec.pxH - 1,
          color: guide,
        );
      }
    }
    return Uint8List.fromList(img.encodePng(sheet));
  }

  static img.Image _centerCropToAspect(img.Image src, int targetW, int targetH) {
    final targetAspect = targetW / targetH;
    final srcAspect = src.width / src.height;
    int cropW, cropH;
    if (srcAspect > targetAspect) {
      cropH = src.height;
      cropW = (src.height * targetAspect).round();
    } else {
      cropW = src.width;
      cropH = (src.width / targetAspect).round();
    }
    final x = ((src.width - cropW) / 2).round();
    final y = ((src.height - cropH) / 2).round();
    return img.copyCrop(src, x: x, y: y, width: cropW, height: cropH);
  }
}
