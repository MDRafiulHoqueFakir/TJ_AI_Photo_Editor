import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/gpu/adjustment_params.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/editor_controller.dart';

/// Live tonal controls. Every change updates [AdjustmentParams] in the
/// controller; the GPU re-runs the fragment shader — no CPU pixel work, so
/// dragging stays at frame rate even on large images.
class AdjustPanel extends ConsumerWidget {
  const AdjustPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(editorControllerProvider.select((s) => s.adjust));
    final controller = ref.read(editorControllerProvider.notifier);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _slider('Brightness', p.brightness,
              (v) => controller.updateAdjust(p.copyWith(brightness: v)),),
          _slider('Contrast', p.contrast,
              (v) => controller.updateAdjust(p.copyWith(contrast: v)),),
          _slider('Saturation', p.saturation,
              (v) => controller.updateAdjust(p.copyWith(saturation: v)),),
          _slider('Exposure', p.exposure,
              (v) => controller.updateAdjust(p.copyWith(exposure: v)),),
          _slider('Warmth', p.warmth,
              (v) => controller.updateAdjust(p.copyWith(warmth: v)),),
          _slider('Vignette', p.vignette,
              (v) => controller.updateAdjust(p.copyWith(vignette: v)),
              min: 0,),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: controller.resetAdjust,
              child: const Text('Reset'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    ValueChanged<double> onChanged, {
    double min = -0.5,
  }) {
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(value: value, min: min, max: 0.5, onChanged: onChanged),
        ),
        SizedBox(
          width: 32,
          child: Text(
            (value * 200).round().toString(),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
