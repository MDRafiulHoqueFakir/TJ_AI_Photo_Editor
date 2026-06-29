import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/widgets/coming_soon_sheet.dart';
import '../../../shared/widgets/feature_grid.dart';
import '../../subscription/application/entitlement_provider.dart';

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
      tier: ToolTier.cloud,
      creditKey: 'ai_art_prompt',
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
    if (item.tier == ToolTier.cloud) {
      final notifier = ref.read(entitlementProvider.notifier);
      if (!notifier.canAfford(item.creditKey!)) {
        context.push(Routes.paywall);
        return;
      }
    }
    showComingSoon(
      context,
      title: item.label,
      reason: item.tier == ToolTier.cloud
          ? 'This is a generative tool that runs on our cloud GPUs. It unlocks once the AI inference backend is connected — your credits are ready to use.'
          : 'Style presets are live! Open a photo in the Editor and tap the Filter tab to apply Vivid, Mono, Noir, Sepia, Vintage and more.',
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
