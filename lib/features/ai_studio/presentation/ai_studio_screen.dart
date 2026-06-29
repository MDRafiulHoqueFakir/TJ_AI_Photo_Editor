import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/widgets/coming_soon_sheet.dart';
import '../../../shared/widgets/feature_grid.dart';

class AiStudioScreen extends ConsumerWidget {
  const AiStudioScreen({super.key});

  static const _features = [
    FeatureItem(
      icon: Icons.content_cut,
      label: 'Hair Restyle',
      tier: ToolTier.cloud,
      creditKey: 'hair_restyle',
    ),
    FeatureItem(
      icon: Icons.auto_fix_high,
      label: 'Generative Fill',
      tier: ToolTier.cloud,
      creditKey: 'generative_fill',
    ),
    FeatureItem(
      icon: Icons.brush,
      label: 'AI Art',
      tier: ToolTier.free, // works on-device now
    ),
    FeatureItem(
      icon: Icons.wallpaper,
      label: 'BG Generate',
      tier: ToolTier.cloud,
      creditKey: 'background_generate',
    ),
    FeatureItem(
      icon: Icons.style,
      label: 'Style Presets',
      tier: ToolTier.free,
    ),
  ];

  void _onTap(BuildContext context, WidgetRef ref, FeatureItem item) {
    // Working on-device tools route to real screens.
    if (item.label == 'AI Art') {
      context.push(Routes.aiArt);
      return;
    }
    if (item.label == 'Style Presets') {
      showComingSoon(
        context,
        title: item.label,
        reason:
            'Style presets are live in the Editor — open a photo and tap the Filter tab for Vivid, Mono, Noir, Sepia, Vintage and more.',
      );
      return;
    }
    // Remaining tools are genuinely generative (need the cloud AI backend).
    showComingSoon(
      context,
      title: item.label,
      reason:
          'This is a generative tool (e.g. new hair, fill, background) that runs on cloud GPUs. It turns on once the AI image-generation backend is connected. Meanwhile, try AI Art and the Editor filters — those run fully on-device.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Studio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Generative tools run in the cloud and use credits. Cost is shown on each tile.',
            style: TextStyle(color: Color(0xFF9A9AA8)),
          ),
          const SizedBox(height: 16),
          FeatureGrid(
            items: _features,
            onTap: (item) => _onTap(context, ref, item),
          ),
        ],
      ),
    );
  }
}
