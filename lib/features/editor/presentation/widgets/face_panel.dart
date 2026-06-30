import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_controller.dart';

/// Face region tools: position the oval on the face, then slim/widen, brighten,
/// and smooth just that area. Runs on-device. (Auto face-detect will place the
/// oval for you once the face-landmark model is wired.)
class FacePanel extends ConsumerWidget {
  const FacePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(editorControllerProvider);
    final c = ref.read(editorControllerProvider.notifier);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Drag the oval onto the face',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          _row('Slim ↔ Wide', s.faceSlim, -1, 1,
              (v) => c.updateFace(slim: v),),
          _row('Brighten', s.faceBrighten, -1, 1,
              (v) => c.updateFace(brighten: v),),
          _row('Smooth', s.faceSmooth, 0, 1, (v) => c.updateFace(smooth: v)),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
