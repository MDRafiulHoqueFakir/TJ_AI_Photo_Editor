import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_controller.dart';

/// Face region tools. Sliders update locally while dragging (smooth) and only
/// apply the on-device edit on release, so the heavy pixel work runs once per
/// adjustment instead of on every tick.
class FacePanel extends ConsumerStatefulWidget {
  const FacePanel({super.key});

  @override
  ConsumerState<FacePanel> createState() => _FacePanelState();
}

class _FacePanelState extends ConsumerState<FacePanel> {
  double? _slim, _brighten, _smooth; // non-null only while dragging

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(editorControllerProvider);
    final c = ref.read(editorControllerProvider.notifier);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Drag the oval onto the face · slide, then release to apply',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          _row(
            'Slim ↔ Wide',
            _slim ?? s.faceSlim,
            -1,
            1,
            (v) => setState(() => _slim = v),
            (v) {
              setState(() => _slim = null);
              c.updateFace(slim: v);
            },
          ),
          _row(
            'Brighten',
            _brighten ?? s.faceBrighten,
            -1,
            1,
            (v) => setState(() => _brighten = v),
            (v) {
              setState(() => _brighten = null);
              c.updateFace(brighten: v);
            },
          ),
          _row(
            'Smooth',
            _smooth ?? s.faceSmooth,
            0,
            1,
            (v) => setState(() => _smooth = v),
            (v) {
              setState(() => _smooth = null);
              c.updateFace(smooth: v);
            },
          ),
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
    ValueChanged<double> onEnd,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onEnd,
          ),
        ),
      ],
    );
  }
}
