import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_controller.dart';

/// Emoji stickers — tap to drop one on the photo, then drag/resize it. Emojis
/// render as glyphs via the system font, so this needs no bundled assets and
/// works on web + mobile. Stickers reuse the text-overlay layer underneath.
class StickerPanel extends ConsumerWidget {
  const StickerPanel({super.key});

  static const _emojis = [
    '😀', '😎', '🥳', '😍', '🤩', '😂', '🔥', '✨',
    '❤️', '💯', '👍', '🙌', '🎉', '⭐', '🌈', '☀️',
    '🌸', '🍕', '🐶', '🐱', '👑', '💎', '🎵', '⚡',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);
    final selected = state.overlays
        .firstWhereOrNull((o) => o.id == state.selectedOverlayId && o.sticker);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected != null)
            Row(
              children: [
                const SizedBox(width: 8),
                const Text('Size', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: selected.size,
                    min: 0.06,
                    max: 0.4,
                    onChanged: (v) => controller.updateOverlay(
                      selected.id,
                      (o) => o.copyWith(size: v),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => controller.removeOverlay(selected.id),
                ),
              ],
            ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: _emojis.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => controller.addSticker(_emojis[i]),
                child: Container(
                  width: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_emojis[i], style: const TextStyle(fontSize: 24)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
