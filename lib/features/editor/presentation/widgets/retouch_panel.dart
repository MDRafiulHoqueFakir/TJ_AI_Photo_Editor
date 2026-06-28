import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/edit_node.dart';

/// Skin smoothing (retouch). Drag commits a SmoothNode on release so it stays
/// undoable and replayable in a Recipe.
class RetouchPanel extends ConsumerStatefulWidget {
  const RetouchPanel({super.key});

  @override
  ConsumerState<RetouchPanel> createState() => _RetouchPanelState();
}

class _RetouchPanelState extends ConsumerState<RetouchPanel> {
  double _amount = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Smooth skin', style: TextStyle(fontSize: 12)),
          ),
          Slider(
            value: _amount,
            onChanged: (v) => setState(() => _amount = v),
            onChangeEnd: (v) => ref
                .read(editorControllerProvider.notifier)
                .pushNode(SmoothNode(amount: v)),
          ),
          const Text(
            'Auto skin-mask retouch lands with on-device ML (Phase 2 native).',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
