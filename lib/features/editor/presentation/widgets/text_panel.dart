import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_controller.dart';

/// Controls for text overlays: add, edit text, recolor, resize, bold, delete.
class TextPanel extends ConsumerWidget {
  const TextPanel({super.key});

  static const _swatches = [
    0xFFFFFFFF,
    0xFF000000,
    0xFFFF5C5C,
    0xFFFFC857,
    0xFF7C5CFF,
    0xFF00D9C0,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);
    final selected = state.overlays
        .firstWhereOrNull((o) => o.id == state.selectedOverlayId && !o.sticker);

    if (selected == null) {
      return Container(
        color: AppColors.surface,
        height: 104,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: () => controller.addText('Your text'),
              icon: const Icon(Icons.add),
              label: const Text('Add text'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap a text layer on the photo to edit it.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey(selected.id),
                  initialValue: selected.text,
                  autofocus: false,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Text',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      controller.updateOverlay(selected.id, (o) => o.copyWith(text: v)),
                ),
              ),
              IconButton(
                tooltip: 'Bold',
                icon: Icon(Icons.format_bold,
                    color: selected.bold ? AppColors.primary : AppColors.textSecondary,),
                onPressed: () => controller.updateOverlay(
                    selected.id, (o) => o.copyWith(bold: !o.bold),),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: () => controller.removeOverlay(selected.id),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Size', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: selected.size,
                  min: 0.03,
                  max: 0.2,
                  onChanged: (v) => controller.updateOverlay(
                      selected.id, (o) => o.copyWith(size: v),),
                ),
              ),
              for (final c in _swatches)
                GestureDetector(
                  onTap: () => controller.updateOverlay(
                      selected.id, (o) => o.copyWith(color: c),),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected.color == c
                            ? AppColors.primary
                            : AppColors.divider,
                        width: selected.color == c ? 2 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
