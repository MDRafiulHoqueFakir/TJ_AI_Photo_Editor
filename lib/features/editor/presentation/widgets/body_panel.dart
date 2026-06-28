import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/edit_node.dart';

/// Body reshape: slim/wide and shorter/taller. Live-updates a single node.
class BodyPanel extends ConsumerStatefulWidget {
  const BodyPanel({super.key});

  @override
  ConsumerState<BodyPanel> createState() => _BodyPanelState();
}

class _BodyPanelState extends ConsumerState<BodyPanel> {
  double _slim = 0;
  double _stretch = 0;

  void _apply() {
    ref
        .read(editorControllerProvider.notifier)
        .updateLiveBody(BodyReshapeNode(slim: _slim, stretch: _stretch));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row('Slim ↔ Wide', _slim, (v) {
            setState(() => _slim = v);
            _apply();
          }),
          _row('Shorter ↔ Taller', _stretch, (v) {
            setState(() => _stretch = v);
            _apply();
          }),
        ],
      ),
    );
  }

  Widget _row(String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(value: value, min: -1, max: 1, onChanged: onChanged),
        ),
      ],
    );
  }
}
