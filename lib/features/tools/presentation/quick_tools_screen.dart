import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/feature_grid.dart';

class QuickToolsScreen extends ConsumerWidget {
  const QuickToolsScreen({super.key});

  static const _features = [
    FeatureItem(icon: Icons.cleaning_services, label: 'Object Remover', tier: ToolTier.free),
    FeatureItem(icon: Icons.layers_clear, label: 'BG Remover', tier: ToolTier.free),
    FeatureItem(icon: Icons.high_quality, label: 'Upscale 2x', tier: ToolTier.free),
    FeatureItem(icon: Icons.four_k, label: 'Upscale 4K', tier: ToolTier.cloud, creditKey: 'upscale_4k'),
    FeatureItem(icon: Icons.blur_on, label: 'Denoise', tier: ToolTier.pro),
    FeatureItem(icon: Icons.hdr_on, label: 'HDR', tier: ToolTier.pro),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FeatureGrid(
            items: _features,
            onTap: (item) => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${item.label}: see build roadmap phase.')),
            ),
          ),
        ],
      ),
    );
  }
}
