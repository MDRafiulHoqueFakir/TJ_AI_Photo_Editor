import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A draggable / resizable free-crop rectangle drawn over the image rect
/// ([width] x [height] logical px). [rect] is in image fractions (0..1);
/// changes are reported back via [onChanged]. Drag the body to move, the four
/// corner handles to resize. A minimum size is enforced.
class CropOverlay extends StatelessWidget {
  const CropOverlay({
    super.key,
    required this.width,
    required this.height,
    required this.rect,
    required this.onChanged,
    this.onChangeEnd,
    this.ellipse = false,
  });

  final double width;
  final double height;
  final Rect rect; // fractions 0..1
  final ValueChanged<Rect> onChanged;
  final VoidCallback? onChangeEnd; // fired when a drag finishes (commit point)
  final bool ellipse; // draw as an oval (face region) instead of a rectangle

  static const _min = 0.08; // min crop size as a fraction

  @override
  Widget build(BuildContext context) {
    final l = rect.left * width;
    final t = rect.top * height;
    final r = rect.right * width;
    final b = rect.bottom * height;

    void moveBy(double dx, double dy) {
      final fdx = dx / width, fdy = dy / height;
      var nl = rect.left + fdx, nt = rect.top + fdy;
      nl = nl.clamp(0.0, 1 - rect.width);
      nt = nt.clamp(0.0, 1 - rect.height);
      onChanged(Rect.fromLTWH(nl, nt, rect.width, rect.height));
    }

    void resizeCorner(double dx, double dy, {required bool left, required bool top}) {
      final fdx = dx / width, fdy = dy / height;
      var nl = rect.left, nt = rect.top, nr = rect.right, nb = rect.bottom;
      if (left) {
        nl = (rect.left + fdx).clamp(0.0, rect.right - _min);
      } else {
        nr = (rect.right + fdx).clamp(rect.left + _min, 1.0);
      }
      if (top) {
        nt = (rect.top + fdy).clamp(0.0, rect.bottom - _min);
      } else {
        nb = (rect.bottom + fdy).clamp(rect.top + _min, 1.0);
      }
      onChanged(Rect.fromLTRB(nl, nt, nr, nb));
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // Dim outside the crop region.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DimPainter(Rect.fromLTRB(l, t, r, b), ellipse),
              ),
            ),
          ),
          // Frame (draggable to move).
          Positioned(
            left: l,
            top: t,
            width: r - l,
            height: b - t,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (d) => moveBy(d.delta.dx, d.delta.dy),
              onPanEnd: (_) => onChangeEnd?.call(),
              child: Container(
                decoration: BoxDecoration(
                  shape: ellipse ? BoxShape.circle : BoxShape.rectangle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ),
          _handle(l, t, (d) => resizeCorner(d.dx, d.dy, left: true, top: true)),
          _handle(r, t, (d) => resizeCorner(d.dx, d.dy, left: false, top: true)),
          _handle(l, b, (d) => resizeCorner(d.dx, d.dy, left: true, top: false)),
          _handle(r, b, (d) => resizeCorner(d.dx, d.dy, left: false, top: false)),
        ],
      ),
    );
  }

  Widget _handle(double cx, double cy, ValueChanged<Offset> onDrag) {
    const s = 26.0;
    return Positioned(
      left: cx - s / 2,
      top: cy - s / 2,
      width: s,
      height: s,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => onDrag(d.delta),
        onPanEnd: (_) => onChangeEnd?.call(),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _DimPainter extends CustomPainter {
  _DimPainter(this.hole, this.ellipse);
  final Rect hole;
  final bool ellipse;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final full = Path()..addRect(Offset.zero & size);
    final inner = Path()..addOval(hole);
    final innerPath = ellipse ? inner : (Path()..addRect(hole));
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, innerPath),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DimPainter old) =>
      old.hole != hole || old.ellipse != ellipse;
}
