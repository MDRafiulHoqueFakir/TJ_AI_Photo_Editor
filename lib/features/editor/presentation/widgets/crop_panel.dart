import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/edit_node.dart';

/// Aspect-ratio crop presets + rotate/flip. Crop geometry is applied by the
/// native engine; here we record intent (aspect) and run orient ops directly.
class CropPanel extends ConsumerWidget {
  const CropPanel({super.key});

  static const _aspects = ['Free', '1:1', '4:5', '9:16', '16:9', '3:4'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(editorControllerProvider.notifier);
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _aspects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(_aspects[i]),
                onPressed: () =>
                    controller.pushNode(CropNode(aspectLabel: _aspects[i])),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _btn(Icons.rotate_left, 'Rotate',
                  () => controller.pushNode(const OrientNode(degrees: -90)),),
              _btn(Icons.flip, 'Flip',
                  () => controller.pushNode(const OrientNode(flipH: true)),),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
