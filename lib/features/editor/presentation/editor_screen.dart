import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'widgets/crop_overlay.dart';
import 'widgets/crop_panel.dart';
import 'widgets/face_panel.dart';
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
  final TransformationController _tc = TransformationController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  /// Mouse-wheel / trackpad zoom toward the cursor (1x–5x).
  void _onScroll(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final m = _tc.value.clone();
    final current = m.getMaxScaleOnAxis();
    var factor = e.scrollDelta.dy < 0 ? 1.12 : 1 / 1.12;
    final next = (current * factor).clamp(1.0, 5.0);
    factor = next / current;
    if ((factor - 1).abs() < 1e-3) return;
    final p = e.localPosition;
    // Zoom toward the cursor: T(p) · S(factor) · T(-p) · current.
    final zoom = Matrix4.translationValues(p.dx, p.dy, 0)
        .multiplied(Matrix4.diagonal3Values(factor, factor, 1))
        .multiplied(Matrix4.translationValues(-p.dx, -p.dy, 0));
    _tc.value = zoom.multiplied(m);
  }

  void _resetZoom() => _tc.value = Matrix4.identity();

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
                  : (ent.isPro
                      ? 'Saved in full quality'
                      : 'Saved (watermarked)'),
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
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            if (!ok)
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
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
      EditorTool.face => const FacePanel(),
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
    final notifier = ref.read(editorControllerProvider.notifier);

    final scaffold = Scaffold(
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
            child: Listener(
              onPointerSignal: state.hasImage ? _onScroll : null,
              child: GestureDetector(
                onLongPressStart: state.hasImage
                    ? (_) => setState(() => _comparing = true)
                    : null,
                onLongPressEnd: state.hasImage
                    ? (_) => setState(() => _comparing = false)
                    : null,
                onDoubleTap: state.hasImage ? _resetZoom : null,
                child: InteractiveViewer(
                  transformationController: _tc,
                  minScale: 1,
                  maxScale: 5,
                  // Disable drag-pan while a precise overlay (crop/face) is
                  // being edited so its handles get the gestures; zoom still works.
                  panEnabled:
                      !(state.freeCropMode || _activeTool == EditorTool.face),
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.center,
                    child: _CanvasView(
                      state: state,
                      comparing: _comparing,
                      onPick: _pickImage,
                      onDragOverlay: ref
                          .read(editorControllerProvider.notifier)
                          .dragOverlay,
                      onSelectOverlay: ref
                          .read(editorControllerProvider.notifier)
                          .selectOverlay,
                      onHealTap:
                          ref.read(editorControllerProvider.notifier).addHeal,
                      onCropChanged: ref
                          .read(editorControllerProvider.notifier)
                          .setCropRect,
                      faceMode: _activeTool == EditorTool.face,
                      onFaceRectChanged: (r) => ref
                          .read(editorControllerProvider.notifier)
                          .updateFace(rect: r),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (state.hasImage && state.freeCropMode)
            _CropBar(
              onCancel:
                  ref.read(editorControllerProvider.notifier).cancelFreeCrop,
              onApply:
                  ref.read(editorControllerProvider.notifier).applyFreeCrop,
            )
          else if (state.hasImage) ...[
            _panelFor(_activeTool),
            ToolRail(
              active: _activeTool,
              onSelect: (t) => setState(() => _activeTool = t),
            ),
          ],
        ],
      ),
    );

    // Keyboard shortcuts: Ctrl/Cmd+Z = undo, Ctrl+Y / Ctrl+Shift+Z = redo.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            notifier.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            notifier.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ,
            control: true, shift: true): notifier.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            notifier.redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            notifier.redo,
      },
      child: Focus(autofocus: true, child: scaffold),
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
    required this.onHealTap,
    required this.onCropChanged,
    required this.faceMode,
    required this.onFaceRectChanged,
  });
  final EditorState state;
  final bool comparing;
  final VoidCallback onPick;
  final void Function(String id, double ddx, double ddy) onDragOverlay;
  final void Function(String? id) onSelectOverlay;
  final void Function(double dx, double dy) onHealTap;
  final void Function(Rect rect) onCropChanged;
  final bool faceMode;
  final void Function(Rect rect) onFaceRectChanged;

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
          onTapUp: (details) {
            if (state.freeCropMode || faceMode) {
              return; // an overlay owns gestures while cropping / face editing
            }
            if (state.healMode && !comparing) {
              final p = details.localPosition;
              final hx = (p.dx - inner.left) / inner.width;
              final hy = (p.dy - inner.top) / inner.height;
              if (hx >= 0 && hx <= 1 && hy >= 0 && hy <= 1) {
                onHealTap(hx, hy);
              }
            } else {
              onSelectOverlay(null); // tap empty space deselects
            }
          },
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
                    ? Image.memory(
                        state.original!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      )
                    : AdjustedImage(
                        image: image,
                        params: state.adjust,
                        filterMatrix: state.filterMatrix,
                      ),
              ),
              if (!comparing && !state.freeCropMode)
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
              if (state.freeCropMode)
                Positioned.fromRect(
                  rect: inner,
                  child: CropOverlay(
                    width: inner.width,
                    height: inner.height,
                    rect: state.cropRect,
                    onChanged: onCropChanged,
                  ),
                ),
              if (faceMode && !comparing && !state.freeCropMode)
                Positioned.fromRect(
                  rect: inner,
                  child: CropOverlay(
                    width: inner.width,
                    height: inner.height,
                    rect: state.faceRect,
                    onChanged: onFaceRectChanged,
                    ellipse: true,
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

class _CropBar extends StatelessWidget {
  const _CropBar({required this.onCancel, required this.onApply});
  final VoidCallback onCancel;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text(
            'Drag the box, then apply',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onApply,
            icon: const Icon(Icons.crop),
            label: const Text('Apply crop'),
          ),
        ],
      ),
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
