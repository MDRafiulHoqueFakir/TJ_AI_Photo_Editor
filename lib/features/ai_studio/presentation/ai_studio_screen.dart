import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/coming_soon_sheet.dart';
import '../../tryon/presentation/tryon_screen.dart';
import '../application/art_effects.dart';

/// AI Studio. Tools that genuinely run on-device are grouped as "Ready to use";
/// truly generative tools (which need a GPU backend) are grouped separately and
/// honest about it — no fake "coming soon" mixed in with working features.
class AiStudioScreen extends StatelessWidget {
  const AiStudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Studio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header('Ready to use', 'Runs on your device — works offline, no limits.'),
          const SizedBox(height: 12),
          _grid([
            _Tool(Icons.auto_fix_high, 'Auto Enhance', AppColors.accent,
                () => _art(context, ArtStyle.enhance),),
            _Tool(Icons.brush, 'AI Art', AppColors.primary,
                () => _art(context, ArtStyle.sketch),),
            _Tool(Icons.animation, 'Cartoon', AppColors.primary,
                () => _art(context, ArtStyle.cartoon),),
            _Tool(Icons.filter_vintage, 'More styles', AppColors.primary,
                () => _art(context, ArtStyle.popArt),),
          ]),
          const SizedBox(height: 24),
          _header('Cloud AI', 'Generative tools that need an AI backend connected.'),
          const SizedBox(height: 12),
          _grid([
            _Tool(Icons.checkroom, 'Professional Attire', AppColors.proGold,
                () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const TryOnScreen()),
                    ),),
            _Tool(Icons.content_cut, 'Hair Restyle', AppColors.textSecondary,
                () => _cloud(context, 'Hair Restyle',
                    'new AI-generated hairstyles',),),
            _Tool(Icons.auto_awesome, 'Generative Fill', AppColors.textSecondary,
                () => _cloud(context, 'Generative Fill',
                    'replacing/extending parts of a photo',),),
            _Tool(Icons.wallpaper, 'BG Generate', AppColors.textSecondary,
                () => _cloud(context, 'Background Generate',
                    'AI-generated backgrounds',),),
          ]),
        ],
      ),
    );
  }

  void _art(BuildContext context, ArtStyle style) {
    context.push(Routes.aiArt, extra: style);
  }

  void _cloud(BuildContext context, String title, String what) {
    showComingSoon(
      context,
      title: title,
      reason:
          'This generates $what — a job for cloud GPUs. It turns on once the AI '
          'image-generation backend is connected. Meanwhile, the "Ready to use" '
          'tools above and the Editor filters all work right now, on-device.',
    );
  }

  Widget _header(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),),
      ],
    );
  }

  Widget _grid(List<_Tool> tools) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [for (final t in tools) _tile(t)],
    );
  }

  Widget _tile(_Tool t) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: t.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(t.icon, color: t.color, size: 30),
            const SizedBox(height: 10),
            Text(t.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Tool {
  const _Tool(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}
