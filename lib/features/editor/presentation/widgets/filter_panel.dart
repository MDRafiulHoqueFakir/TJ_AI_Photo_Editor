import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/color_pipeline/filter_presets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/editor_controller.dart';

/// One-tap style filters with live thumbnails of the current photo. Selecting a
/// preset is GPU-only (a color matrix composed under the tonal adjustments), so
/// it applies instantly and works identically on web and mobile.
class FilterPanel extends ConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(editorControllerProvider.select((s) => s.sourceImage));
    final selectedId = ref.watch(editorControllerProvider.select((s) => s.filterId));
    final controller = ref.read(editorControllerProvider.notifier);

    return Container(
      color: AppColors.surface,
      height: 104,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: FilterPreset.catalog.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final preset = FilterPreset.catalog[i];
          // 'original' is represented by an empty filterId.
          final id = preset.id == 'original' ? '' : preset.id;
          final selected = selectedId == id;
          return GestureDetector(
            onTap: () => controller.selectFilter(id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.divider,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: image == null
                      ? const ColoredBox(color: AppColors.surfaceHigh)
                      : ColorFiltered(
                          colorFilter: ColorFilter.matrix(preset.matrix),
                          child: RawImage(image: image, fit: BoxFit.cover),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  preset.name,
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
}

/// Exposed for callers that want a quick thumbnail without the panel chrome.
Widget filterThumb(ui.Image image, List<double> matrix) => ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: RawImage(image: image, fit: BoxFit.cover),
    );
