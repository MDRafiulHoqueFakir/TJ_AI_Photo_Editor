import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_controller.dart';

/// Retouch: skin smoothing + tap-to-heal blemish removal. Smoothing commits a
/// SmoothNode; heal mode lets the user tap blemishes on the photo (each tap is
/// an undoable HealNode). Both stay non-destructive and replay on export.
class RetouchPanel extends ConsumerStatefulWidget {
  const RetouchPanel({super.key});

  @override
  ConsumerState<RetouchPanel> createState() => _RetouchPanelState();
}

class _RetouchPanelState extends ConsumerState<RetouchPanel> {
  double _amount = 0;

  @override
  Widget build(BuildContext context) {
    final healMode = ref.watch(editorControllerProvider.select((s) => s.healMode));
    final healRadius = ref.watch(editorControllerProvider.select((s) => s.healRadius));
    final controller = ref.read(editorControllerProvider.notifier);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 84,
                child: Text('Smooth', style: TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: Slider(
                  value: _amount,
                  onChanged: (v) => setState(() => _amount = v),
                  onChangeEnd: controller.commitSmooth,
                ),
              ),
            ],
          ),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: controller.toggleHeal,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      healMode ? AppColors.primary : AppColors.surfaceHigh,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.healing, size: 18),
                label: Text(healMode ? 'Healing — tap blemishes' : 'Heal'),
              ),
              const SizedBox(width: 12),
              const Text('Size', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: healRadius,
                  min: 0.015,
                  max: 0.08,
                  onChanged: controller.setHealRadius,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
