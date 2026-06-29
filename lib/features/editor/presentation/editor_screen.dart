import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/color_pipeline/adjusted_image.dart';
import '../../../core/services/image_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../subscription/application/entitlement_provider.dart';
import '../application/editor_controller.dart';
import 'widgets/adjust_panel.dart';
import 'widgets/body_panel.dart';
import 'widgets/crop_panel.dart';
import 'widgets/filter_panel.dart';
import 'widgets/frame_panel.dart';
import 'widgets/retouch_panel.dart';
import 'widgets/sticker_panel.dart';
import 'widgets/text_layer.dart';
import 'widgets/text_panel.dart';
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

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await ref.read(editorControllerProvider.notifier).loadImage(bytes);
  }

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

    // Actually deliver the file: web triggers a browser download, native writes
    // the file to storage. This closes the import -> edit -> export loop.
    String? savedAs;
    String? error;
    try {
      savedAs = await FileSaver.instance.saveFile(
        name: 'tj_edit_${DateTime.now().millisecondsSinceEpoch}',
        bytes: bytes,
        fileExtension: 'jpg',
        mimeType: MimeType.jpeg,
      );
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;

    final ok = error == null;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.error_outline,
              color: ok ? AppColors.accent : AppColors.danger,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              !ok
                  ? 'Export failed'
                  : (ent.isPro ? 'Saved in full quality' : 'Saved (watermarked)'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (ok && kIsWeb)
              const Text(
                'Your image has been downloaded.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            if (ok && !kIsWeb && savedAs != null)
              Text(
                'Saved to: $savedAs',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            if (!ok)
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            if (ok && !ent.isPro) ...[
              const SizedBox(height: 8),
              const Text(
                'Go Pro to remove the watermark and export in 4K.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(Routes.paywall);
                },
                child: const Text('Remove watermark — Go Pro'),
              ),
            ],
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
      EditorTool.filter => const FilterPanel(),
      EditorTool.text => const TextPanel(),
      EditorTool.sticker => const StickerPanel(),
      EditorTool.frame => const FramePanel(),
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
              onLongPressStart:
                  state.hasImage ? (_) => setState(() => _comparing = true) : null,
              onLongPressEnd:
                  state.hasImage ? (_) => setState(() => _comparing = false) : null,
              child: Container(
                color: Colors.black,
                width: double.infinity,
                alignment: Alignment.center,
                child: _CanvasView(
                  state: state,
                  comparing: _comparing,
                  onPick: _pickImage,
                  onDragOverlay:
                      ref.read(editorControllerProvider.notifier).dragOverlay,
                  onSelectOverlay:
                      ref.read(editorControllerProvider.notifier).selectOverlay,
                ),
              ),
            ),
          ),
          if (state.hasImage) ...[
            _panelFor(_activeTool),
            ToolRail(
              active: _activeTool,
              onSelect: (t) => setState(() => _activeTool = t),
            ),
          ],
        ],
      ),
    );
  }
}

class _CanvasView extends StatelessWidget {
  const _CanvasView({
    required this.state,
    required this.comparing,
    required this.onPick,
    required this.onDragOverlay,
    required this.onSelectOverlay,
  });
  final EditorState state;
  final bool comparing;
  final VoidCallback onPick;
  final void Function(String id, double ddx, double ddy) onDragOverlay;
  final void Function(String? id) onSelectOverlay;

  @override
  Widget build(BuildContext context) {
    if (!state.hasImage) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_photo_alternate_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Import a photo to start editing',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.photo_library),
            label: const Text('Choose photo'),
          ),
        ],
      );
    }

    final image = state.sourceImage!;
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    // Frame (hidden while comparing to the original).
    final frame = comparing ? null : state.frame;
    final hasFrame = frame != null && !frame.isNone;
    final minSide = w < h ? w : h;
    final b = hasFrame ? frame.border * minSide : 0.0;
    final bottom = hasFrame ? frame.bottomExtra * minSide : 0.0;
    final framedAspect = (w + 2 * b) / (h + 2 * b + bottom);

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final outer = _containRect(framedAspect, box);
        final scale = outer.width / (w + 2 * b);
        final bs = b * scale;
        final bottomS = bottom * scale;
        final inner = Rect.fromLTWH(
          outer.left + bs,
          outer.top + bs,
          outer.width - 2 * bs,
          outer.height - 2 * bs - bottomS,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelectOverlay(null), // tap empty space deselects
          child: Stack(
            children: [
              if (hasFrame)
                Positioned.fromRect(
                  rect: outer,
                  child: ColoredBox(color: Color(frame.color)),
                ),
              Positioned.fromRect(
                rect: inner,
                child: comparing
                    ? Image.memory(state.original!,
                        fit: BoxFit.contain, gaplessPlayback: true,)
                    : AdjustedImage(
                        image: image,
                        params: state.adjust,
                        filterMatrix: state.filterMatrix,
                      ),
              ),
              if (!comparing)
                Positioned.fromRect(
                  rect: inner,
                  child: TextLayer(
                    width: inner.width,
                    height: inner.height,
                    overlays: state.overlays,
                    selectedId: state.selectedOverlayId,
                    onDragDelta: onDragOverlay,
                    onSelect: onSelectOverlay,
                  ),
                ),
              if (state.isProcessing)
                const Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              if (comparing)
                const Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(child: Chip(label: Text('Original'))),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Largest rect with the image's aspect that fits inside [box] (contain).
  Rect _containRect(double aspect, Size box) {
    var w = box.width;
    var h = w / aspect;
    if (h > box.height) {
      h = box.height;
      w = h * aspect;
    }
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
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
