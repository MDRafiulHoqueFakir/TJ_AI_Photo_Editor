import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../editor/application/editor_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _pickAndEdit(BuildContext context, WidgetRef ref) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes(); // XFile API: works on web + native
    await ref.read(editorControllerProvider.notifier).loadImage(bytes);
    if (context.mounted) context.push(Routes.editor, extra: picked.path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TJ Photo Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium, color: AppColors.proGold),
            onPressed: () => context.push(Routes.paywall),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(onTap: () => _pickAndEdit(context, ref)),
          const SizedBox(height: 24),
          const Text(
            'Quick start',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _Tile(
                icon: Icons.auto_awesome,
                label: 'AI Studio',
                subtitle: 'Hair · Art · Fill',
                onTap: () => context.push(Routes.aiStudio),
              ),
              _Tile(
                icon: Icons.handyman,
                label: 'Quick Tools',
                subtitle: 'Remove · Upscale',
                onTap: () => context.push(Routes.quickTools),
              ),
              _Tile(
                icon: Icons.badge,
                label: 'Passport',
                subtitle: 'ID photo maker',
                onTap: () => context.push(Routes.passport),
              ),
              _Tile(
                icon: Icons.grid_view,
                label: 'Collage',
                subtitle: 'Combine photos',
                onTap: () => context.push(Routes.collage),
              ),
              _Tile(
                icon: Icons.photo_library,
                label: 'Edit Photo',
                subtitle: 'Open from gallery',
                onTap: () => _pickAndEdit(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          gradient: AppColors.premiumGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 40, color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Start editing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Import a photo to begin',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
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
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
