import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/edit_node.dart';

/// Live brightness/contrast/saturation. Dragging updates a single live node
/// (no stack spam); the committed value persists on the edit stack so it is
/// undoable and replayable as part of a Recipe.
class AdjustPanel extends ConsumerStatefulWidget {
  const AdjustPanel({super.key});

  @override
  ConsumerState<AdjustPanel> createState() => _AdjustPanelState();
}

class _AdjustPanelState extends ConsumerState<AdjustPanel> {
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;

  void _apply() {
    ref.read(editorControllerProvider.notifier).updateLiveAdjust(
          AdjustNode(
            brightness: _brightness,
            contrast: _contrast,
            saturation: _saturation,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AdjustSlider(
            label: 'Brightness',
            value: _brightness,
            onChanged: (v) {
              setState(() => _brightness = v);
              _apply();
            },
          ),
          _AdjustSlider(
            label: 'Contrast',
            value: _contrast,
            onChanged: (v) {
              setState(() => _contrast = v);
              _apply();
            },
          ),
          _AdjustSlider(
            label: 'Saturation',
            value: _saturation,
            onChanged: (v) {
              setState(() => _saturation = v);
              _apply();
            },
          ),
        ],
      ),
    );
  }
}

class _AdjustSlider extends StatelessWidget {
  const _AdjustSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: -0.5,
            max: 0.5,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            (value * 200).round().toString(),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
