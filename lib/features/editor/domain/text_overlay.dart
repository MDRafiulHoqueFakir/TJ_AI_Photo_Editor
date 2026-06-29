import 'package:flutter/painting.dart';

/// A draggable text layer over the photo. Position is stored relative to the
/// image (0..1, centre of the text) and [size] is a fraction of the image
/// height, so the same overlay maps correctly to both the on-screen preview and
/// the full-resolution export regardless of scale.
class TextOverlay {
  const TextOverlay({
    required this.id,
    required this.text,
    this.dx = 0.5,
    this.dy = 0.5,
    this.size = 0.08,
    this.color = 0xFFFFFFFF,
    this.bold = true,
    this.sticker = false,
  });

  final String id;
  final String text;
  final double dx;
  final double dy;
  final double size;
  final int color;
  final bool bold;
  final bool sticker; // emoji/sticker layer: no shadow, color ignored by glyph

  TextOverlay copyWith({
    String? text,
    double? dx,
    double? dy,
    double? size,
    int? color,
    bool? bold,
  }) {
    return TextOverlay(
      id: id,
      text: text ?? this.text,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      size: size ?? this.size,
      color: color ?? this.color,
      bold: bold ?? this.bold,
      sticker: sticker,
    );
  }

  TextStyle styleFor(double imageHeight) => TextStyle(
        color: sticker ? null : Color(color),
        fontSize: size * imageHeight,
        fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        height: 1.0,
        shadows: sticker
            ? null
            : const [
                Shadow(blurRadius: 4, color: Color(0x99000000), offset: Offset(0, 1)),
              ],
      );
}

/// Paints overlays onto a canvas of [size] (used at export so the baked text
/// matches the live preview exactly). Shared by preview and export paths.
void paintTextOverlays(Canvas canvas, Size size, List<TextOverlay> overlays) {
  for (final o in overlays) {
    if (o.text.isEmpty) continue;
    final tp = TextPainter(
      text: TextSpan(text: o.text, style: o.styleFor(size.height)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.95);
    final cx = o.dx * size.width;
    final cy = o.dy * size.height;
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }
}
