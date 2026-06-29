import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/frame_preset.dart';

/// Frame / border picker. Frames scale with the photo and are baked into the
/// export; selecting one is instant (live preview around the image).
class FramePanel extends ConsumerWidget {
  const FramePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(editorControllerProvider.select((s) => s.frameId));
    final controller = ref.read(editorControllerProvider.notifier);

    return Container(
      color: AppColors.surface,
      height: 104,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: FramePreset.catalog.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final f = FramePreset.catalog[i];
          final id = f.id == 'none' ? '' : f.id;
          final selected = selectedId == id;
          return GestureDetector(
            onTap: () => controller.selectFrame(id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.divider,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: _preview(f),
                ),
                const SizedBox(height: 6),
                Text(
                  f.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Tiny mock of the frame around a grey "photo".
  Widget _preview(FramePreset f) {
    if (f.isNone) {
      return const Icon(Icons.block, size: 20, color: AppColors.textSecondary);
    }
    final bw = f.border * 60;
    return Container(
      color: Color(f.color),
      padding: EdgeInsets.fromLTRB(bw, bw, bw, bw + f.bottomExtra * 60),
      child: const ColoredBox(
        color: Color(0xFF888894),
        child: SizedBox(width: 36, height: 36),
      ),
    );
  }
}
