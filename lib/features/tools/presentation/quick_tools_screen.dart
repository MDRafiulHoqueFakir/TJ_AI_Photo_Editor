import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/widgets/coming_soon_sheet.dart';
import '../../../shared/widgets/feature_grid.dart';
import '../../subscription/application/entitlement_provider.dart';

class QuickToolsScreen extends ConsumerStatefulWidget {
  const QuickToolsScreen({super.key});

  @override
  ConsumerState<QuickToolsScreen> createState() => _QuickToolsScreenState();
}

class _QuickToolsScreenState extends ConsumerState<QuickToolsScreen> {
  bool _busy = false;

  static const _features = [
    FeatureItem(icon: Icons.cleaning_services, label: 'Object Remover', tier: ToolTier.free),
    FeatureItem(icon: Icons.layers_clear, label: 'BG Remover', tier: ToolTier.free),
    FeatureItem(icon: Icons.high_quality, label: 'Upscale 2x', tier: ToolTier.free),
    FeatureItem(icon: Icons.four_k, label: 'Upscale 4K', tier: ToolTier.cloud, creditKey: 'upscale_4k'),
    FeatureItem(icon: Icons.blur_on, label: 'Denoise', tier: ToolTier.pro),
    FeatureItem(icon: Icons.hdr_on, label: 'HDR', tier: ToolTier.pro),
  ];

  Future<void> _onTap(FeatureItem item) async {
    switch (item.label) {
      case 'Upscale 2x':
        await _upscale2x();
      case 'Object Remover':
      case 'BG Remover':
        showComingSoon(
          context,
          title: item.label,
          reason:
              'This runs on-device once the segmentation / inpainting model is bundled with the app — no internet required.',
        );
      case 'Upscale 4K':
        if (!ref.read(entitlementProvider.notifier).canAfford(item.creditKey!)) {
          context.push(Routes.paywall);
          return;
        }
        showComingSoon(
          context,
          title: item.label,
          reason: 'Cloud super-resolution unlocks when the AI backend is connected.',
        );
      default:
        showComingSoon(
          context,
          title: item.label,
          reason: 'A Pro on-device effect that is being finalized.',
        );
    }
  }

  /// Real, working 2x upscale via high-quality cubic resampling (pure Dart).
  Future<void> _upscale2x() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Unsupported image');
      final up = img.copyResize(
        image,
        width: image.width * 2,
        height: image.height * 2,
        interpolation: img.Interpolation.cubic,
      );
      final out = Uint8List.fromList(img.encodePng(up));
      await FileSaver.instance.saveFile(
        name: 'tj_upscaled_${DateTime.now().millisecondsSinceEpoch}',
        bytes: out,
        fileExtension: 'png',
        mimeType: MimeType.png,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upscaled to ${up.width}×${up.height}. Saved.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Tools')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FeatureGrid(items: _features, onTap: _onTap),
            ],
          ),
          if (_busy)
            const ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
