import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/text_overlay.dart';

/// Draggable text layers positioned over the image rect ([width]x[height] in
/// logical px). Positions are image-relative (0..1) so they match the export.
class TextLayer extends StatelessWidget {
  const TextLayer({
    super.key,
    required this.width,
    required this.height,
    required this.overlays,
    required this.selectedId,
    required this.onDragDelta,
    required this.onSelect,
  });

  final double width;
  final double height;
  final List<TextOverlay> overlays;
  final String? selectedId;
  final void Function(String id, double ddx, double ddy) onDragDelta;
  final void Function(String? id) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final o in overlays)
            Positioned(
              left: o.dx * width,
              top: o.dy * height,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(o.id),
                  onPanStart: (_) => onSelect(o.id),
                  onPanUpdate: (d) =>
                      onDragDelta(o.id, d.delta.dx / width, d.delta.dy / height),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: selectedId == o.id
                        ? BoxDecoration(
                            border: Border.all(color: AppColors.primary, width: 1.5),
                            borderRadius: BorderRadius.circular(4),
                          )
                        : null,
                    child: Text(
                      o.text,
                      textAlign: TextAlign.center,
                      style: o.styleFor(height),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
