import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/dart_image_engine.dart';
import '../../../core/services/image_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/coming_soon_sheet.dart';
import '../../../shared/widgets/feature_grid.dart';

/// Quick one-shot tools. The on-device ones (upscale, denoise, HDR) run for
/// real; object/background removal need the segmentation model and say so.
class QuickToolsScreen extends ConsumerStatefulWidget {
  const QuickToolsScreen({super.key});

  @override
  ConsumerState<QuickToolsScreen> createState() => _QuickToolsScreenState();
}

class _QuickToolsScreenState extends ConsumerState<QuickToolsScreen> {
  bool _busy = false;
  final ImageEngine _engine = const DartImageEngine();

  static const _features = [
    FeatureItem(icon: Icons.high_quality, label: 'Upscale 2x', tier: ToolTier.free),
    FeatureItem(icon: Icons.four_k, label: 'Upscale 4x', tier: ToolTier.free),
    FeatureItem(icon: Icons.blur_on, label: 'Denoise', tier: ToolTier.free),
    FeatureItem(icon: Icons.hdr_on, label: 'HDR', tier: ToolTier.free),
    FeatureItem(icon: Icons.cleaning_services, label: 'Object Remover', tier: ToolTier.free),
    FeatureItem(icon: Icons.layers_clear, label: 'BG Remover', tier: ToolTier.free),
  ];

  Future<void> _onTap(FeatureItem item) async {
    switch (item.label) {
      case 'Upscale 2x':
        await _run((b) => _engine.upscale(b, factor: 2), 'upscaled2x');
      case 'Upscale 4x':
        await _run((b) => _engine.upscale(b, factor: 4), 'upscaled4x');
      case 'Denoise':
        await _run((b) => _engine.denoise(b, amount: 0.6), 'denoised');
      case 'HDR':
        await _run((b) => _engine.hdr(b, amount: 0.7), 'hdr');
      case 'Object Remover':
        // The Editor's Retouch > Heal already removes small objects on-device.
        showComingSoon(
          context,
          title: 'Object Remover',
          reason:
              'For small objects/blemishes, use Editor > Retouch > Heal (works '
              'now). Full object removal needs the on-device inpainting model, '
              'which is being bundled.',
        );
      case 'BG Remover':
        showComingSoon(
          context,
          title: 'Background Remover',
          reason:
              'Cutting out the subject needs the on-device segmentation model. '
              'It runs fully offline once the model is bundled with the app.',
        );
    }
  }

  Future<void> _run(
    Future<Uint8List> Function(Uint8List) op,
    String suffix,
  ) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      // Bound very large inputs first so on-device ops stay responsive.
      var bytes = await picked.readAsBytes();
      bytes = await _engine.fitWithin(bytes, maxLongEdge: 2000);
      final out = await op(bytes);
      await FileSaver.instance.saveFile(
        name: 'tj_${suffix}_${DateTime.now().millisecondsSinceEpoch}',
        bytes: out,
        fileExtension: 'png',
        mimeType: MimeType.png,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved. Check your downloads.')),
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
              const Text(
                'Pick a photo and the tool runs on-device, then saves the result.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
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
