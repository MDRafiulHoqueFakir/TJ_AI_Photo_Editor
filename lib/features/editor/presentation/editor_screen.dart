import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/color_pipeline/adjusted_image.dart';
import '../../../core/services/image_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../subscription/application/entitlement_provider.dart';
import '../application/editor_controller.dart';
import 'widgets/adjust_panel.dart';
import 'widgets/body_panel.dart';
import 'widgets/crop_panel.dart';
import 'widgets/retouch_panel.dart';
import 'widgets/tool_rail.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.imagePath});
  final String? imagePath;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  EditorTool _activeTool = EditorTool.adjust;
  bool _comparing = false;

  Future<void> _export() async {
    final ent = ref.read(entitlementProvider);
    final controller = ref.read(editorControllerProvider.notifier);

    // Free tier: watermark forced on. Pro: clean export.
    final bytes = await controller.export(
      format: ExportFormat.jpeg,
      quality: 95,
      watermark: !ent.isPro,
    );
    if (bytes == null || !mounted) return;

    // Phase 1: confirm + offer upsell. Phase 2 saves to gallery (gal/saver pkg).
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.accent, size: 48),
            const SizedBox(height: 12),
            Text(
              ent.isPro ? 'Exported in full quality' : 'Exported (watermarked)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (!ent.isPro)
              const Text(
                'Go Pro to remove the watermark and export in 4K.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 16),
            if (!ent.isPro)
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(Routes.paywall);
                },
                child: const Text('Remove watermark — Go Pro'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _panelFor(EditorTool tool) {
    return switch (tool) {
      EditorTool.adjust => const AdjustPanel(),
      EditorTool.retouch => const RetouchPanel(),
      EditorTool.body => const BodyPanel(),
      EditorTool.crop => const CropPanel(),
      _ => _ComingSoonPanel(tool: tool),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: state.canUndo
                ? ref.read(editorControllerProvider.notifier).undo
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: state.canRedo
                ? ref.read(editorControllerProvider.notifier).redo
                : null,
          ),
          IconButton(icon: const Icon(Icons.ios_share), onPressed: _export),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onLongPressStart: (_) => setState(() => _comparing = true),
              onLongPressEnd: (_) => setState(() => _comparing = false),
              child: Container(
                color: Colors.black,
                width: double.infinity,
                alignment: Alignment.center,
                child: _CanvasView(state: state, comparing: _comparing),
              ),
            ),
          ),
          _panelFor(_activeTool),
          ToolRail(
            active: _activeTool,
            onSelect: (t) => setState(() => _activeTool = t),
          ),
        ],
      ),
    );
  }
}

class _CanvasView extends StatelessWidget {
  const _CanvasView({required this.state, required this.comparing});
  final EditorState state;
  final bool comparing;

  @override
  Widget build(BuildContext context) {
    if (!state.hasImage) {
      return const Text(
        'No image loaded',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    // Hold-to-compare shows the untouched original; otherwise the GPU layer
    // paints the current structural result + live tonal adjustments.
    final Widget canvas = comparing
        ? Image.memory(state.original!, gaplessPlayback: true)
        : AdjustedImage(image: state.sourceImage!, params: state.adjust);
    return Stack(
      alignment: Alignment.center,
      children: [
        InteractiveViewer(maxScale: 5, child: canvas),
        if (state.isProcessing)
          const Positioned(
            top: 12,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (comparing)
          const Positioned(
            bottom: 12,
            child: Chip(label: Text('Original')),
          ),
      ],
    );
  }
}

class _ComingSoonPanel extends StatelessWidget {
  const _ComingSoonPanel({required this.tool});
  final EditorTool tool;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      width: double.infinity,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tool.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Wired in the build roadmap — see docs/PROJECT_FLOW.md',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
