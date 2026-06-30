import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/color_pipeline/filter_presets.dart';
import '../../../core/services/color_pipeline/image_renderer.dart';
import '../../../core/services/dart_image_engine.dart';
import '../../../core/services/gpu/adjustment_params.dart';
import '../../../core/services/gpu/shader_loader.dart';
import '../../../core/services/image_engine.dart';
import '../domain/edit_node.dart';
import '../domain/frame_preset.dart';
import '../domain/text_overlay.dart';

final imageEngineProvider = Provider<ImageEngine>((_) => const DartImageEngine());

/// Editor session state.
///
/// Pipeline: structural edits (crop/orient/retouch/body) are the CPU edit
/// stack; their result is decoded into a GPU texture ([sourceImage]). The
/// frequently-dragged tonal layer ([adjust]) runs entirely on the GPU via the
/// fragment shader, so sliders stay at frame rate with no CPU work or byte
/// round-trip. Structural edits are occasional and only then re-decode.
@immutable
class EditorState {
  const EditorState({
    this.original,
    this.sourceImage,
    this.adjust = AdjustmentParams.identity,
    this.filterId = '',
    this.frameId = '',
    this.overlays = const [],
    this.selectedOverlayId,
    this.healMode = false,
    this.healRadius = 0.035,
    this.freeCropMode = false,
    this.cropRect = const ui.Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
    this.faceRect = const ui.Rect.fromLTRB(0.3, 0.18, 0.7, 0.8),
    this.faceBrighten = 0,
    this.faceSmooth = 0,
    this.faceSlim = 0,
    this.stack = const [],
    this.redoStack = const [],
    this.isProcessing = false,
  });

  final Uint8List? original; // decoded source bytes
  final ui.Image? sourceImage; // CPU-stack result, as a GPU texture
  final AdjustmentParams adjust; // live tonal layer (GPU)
  final String filterId; // selected style filter ('' = none)
  final String frameId; // selected frame ('' = none)
  final List<TextOverlay> overlays; // draggable text layers
  final String? selectedOverlayId;
  final bool healMode; // when on, tapping the photo heals a blemish
  final double healRadius;
  final bool freeCropMode; // when on, a draggable crop box is shown
  final ui.Rect cropRect; // freeform crop, fractions of the image (0..1)
  final ui.Rect faceRect; // face region ellipse, fractions (0..1)
  final double faceBrighten;
  final double faceSmooth;
  final double faceSlim;
  final List<EditNode> stack;
  final List<List<EditNode>> redoStack;
  final bool isProcessing;

  bool get canUndo => stack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  bool get hasImage => sourceImage != null;

  /// Resolved style-filter matrix for the GPU pipeline (null when none).
  List<double>? get filterMatrix => FilterPreset.byId(filterId)?.matrix;

  /// Resolved frame (null/none when no border).
  FramePreset? get frame => FramePreset.byId(frameId);

  EditorState copyWith({
    Uint8List? original,
    ui.Image? sourceImage,
    AdjustmentParams? adjust,
    String? filterId,
    String? frameId,
    List<TextOverlay>? overlays,
    Object? selectedOverlayId = _noChange,
    bool? healMode,
    double? healRadius,
    bool? freeCropMode,
    ui.Rect? cropRect,
    ui.Rect? faceRect,
    double? faceBrighten,
    double? faceSmooth,
    double? faceSlim,
    List<EditNode>? stack,
    List<List<EditNode>>? redoStack,
    bool? isProcessing,
  }) {
    return EditorState(
      original: original ?? this.original,
      sourceImage: sourceImage ?? this.sourceImage,
      adjust: adjust ?? this.adjust,
      filterId: filterId ?? this.filterId,
      frameId: frameId ?? this.frameId,
      overlays: overlays ?? this.overlays,
      selectedOverlayId: selectedOverlayId == _noChange
          ? this.selectedOverlayId
          : selectedOverlayId as String?,
      healMode: healMode ?? this.healMode,
      healRadius: healRadius ?? this.healRadius,
      freeCropMode: freeCropMode ?? this.freeCropMode,
      cropRect: cropRect ?? this.cropRect,
      faceRect: faceRect ?? this.faceRect,
      faceBrighten: faceBrighten ?? this.faceBrighten,
      faceSmooth: faceSmooth ?? this.faceSmooth,
      faceSlim: faceSlim ?? this.faceSlim,
      stack: stack ?? this.stack,
      redoStack: redoStack ?? this.redoStack,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

/// Sentinel so copyWith can distinguish "leave selectedOverlayId" from "clear it".
const Object _noChange = Object();

class EditorController extends Notifier<EditorState> {
  bool _disposed = false;

  @override
  EditorState build() {
    ref.onDispose(() {
      _disposed = true;
      state.sourceImage?.dispose();
    });
    return const EditorState();
  }

  ImageEngine get _engine => ref.read(imageEngineProvider);

  /// Long-edge cap for the working image. Bounds memory + per-pixel CPU work so
  /// edits stay responsive and can't crash the tab on very large photos.
  static const _maxWorkingEdge = 1600;

  // Render serialization + a generation guard. Rapid edits (e.g. dragging the
  // body slider) used to fire overlapping renders that double-disposed the GPU
  // texture — a real crash on web. Now renders run one-at-a-time and coalesce,
  // and a stale render can't clobber a freshly loaded image.
  bool _rendering = false;
  bool _renderAgain = false;
  int _generation = 0;

  /// Swap the live GPU texture, disposing the previous one exactly once.
  void _setSourceImage(ui.Image image, {bool processing = false}) {
    if (_disposed) {
      image.dispose(); // controller is gone; don't touch state, don't leak
      return;
    }
    final old = state.sourceImage;
    state = state.copyWith(sourceImage: image, isProcessing: processing);
    if (old != null && !identical(old, image)) old.dispose();
  }

  Future<void> loadImage(Uint8List bytes) async {
    _generation++; // invalidate any in-flight render from a prior image
    final old = state.sourceImage;
    // Decode + downscale NATIVELY on the GPU (fast on web). Using package:image
    // here froze the tab for seconds on large photos — the editor's #1 crash.
    try {
      var decoded = await decodeUiImage(bytes);
      final scaled = await downscaleUiImage(decoded, _maxWorkingEdge);
      if (!identical(scaled, decoded)) decoded.dispose();
      decoded = scaled;
      final working = await encodeUiImage(decoded) ?? bytes;
      // Fresh state for the new image; show instantly with no CPU re-render.
      state = EditorState(original: working, sourceImage: decoded);
    } catch (e) {
      debugPrint('loadImage failed, falling back: $e');
      Uint8List working;
      try {
        working = await _engine.fitWithin(bytes, maxLongEdge: _maxWorkingEdge);
      } catch (_) {
        working = bytes;
      }
      state = EditorState(original: working);
      await _render();
    }
    if (old != null && !identical(old, state.sourceImage)) old.dispose();
  }

  /// Live tonal update — GPU only, no CPU pixel work. Cheap enough per frame.
  void updateAdjust(AdjustmentParams params) {
    state = state.copyWith(adjust: params);
  }

  /// Push a structural node (crop/orient/retouch/body) and re-render the stack.
  Future<void> pushNode(EditNode node) async {
    state = state.copyWith(
      stack: [...state.stack, node],
      redoStack: const [],
      isProcessing: true,
    );
    await _render();
  }

  /// Live body-reshape drag: keep a single top BodyReshapeNode.
  Future<void> updateLiveBody(BodyReshapeNode node) async {
    final stack = [...state.stack];
    if (stack.isNotEmpty && stack.last is BodyReshapeNode) {
      stack[stack.length - 1] = node;
    } else {
      stack.add(node);
    }
    state = state.copyWith(stack: stack, isProcessing: true);
    await _render();
  }

  void undo() {
    if (!state.canUndo) return;
    final stack = [...state.stack];
    final removed = stack.removeLast();
    state = state.copyWith(
      stack: stack,
      redoStack: [
        [removed],
        ...state.redoStack,
      ],
    );
    _render();
  }

  void redo() {
    if (!state.canRedo) return;
    final redo = [...state.redoStack];
    final restored = redo.removeAt(0);
    state = state.copyWith(stack: [...state.stack, ...restored], redoStack: redo);
    _render();
  }

  /// Reset the live tonal layer to identity (does not touch structural stack).
  void resetAdjust() => state = state.copyWith(adjust: AdjustmentParams.identity);

  /// Select a style filter ('' clears it). GPU-only, no CPU work.
  void selectFilter(String id) => state = state.copyWith(filterId: id);

  /// Select a frame/border ('' clears it).
  void selectFrame(String id) => state = state.copyWith(frameId: id);

  /// Apply an aspect-ratio crop. Consecutive ratio taps REPLACE the previous
  /// one (so each ratio crops from the same base, not a compounding crop).
  Future<void> applyAspectCrop(String label, double ratio) async {
    final stack = [...state.stack];
    final node = CropNode(aspectLabel: label, ratio: ratio);
    if (stack.isNotEmpty && stack.last is CropNode && !(stack.last as CropNode).hasRect) {
      stack[stack.length - 1] = node; // refresh to the new ratio
    } else {
      stack.add(node);
    }
    state = state.copyWith(stack: stack, redoStack: const [], isProcessing: true);
    await _render();
  }

  // ---- Free (hand-drawn) crop ----

  void beginFreeCrop() => state = state.copyWith(
        freeCropMode: true,
        cropRect: const ui.Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
      );

  void setCropRect(ui.Rect rect) => state = state.copyWith(cropRect: rect);

  void cancelFreeCrop() => state = state.copyWith(freeCropMode: false);

  Future<void> applyFreeCrop() async {
    final r = state.cropRect;
    state = state.copyWith(freeCropMode: false);
    await pushNode(CropNode(
      aspectLabel: 'Free',
      rectL: r.left,
      rectT: r.top,
      rectW: r.width,
      rectH: r.height,
    ),);
  }

  // ---- Face region (brighten / smooth / slim) ----

  /// Update the face region and/or its amounts; maintains a single live
  /// FaceAdjustNode at the top of the stack (replace, don't compound).
  Future<void> updateFace({
    ui.Rect? rect,
    double? brighten,
    double? smooth,
    double? slim,
  }) async {
    state = state.copyWith(
      faceRect: rect ?? state.faceRect,
      faceBrighten: brighten ?? state.faceBrighten,
      faceSmooth: smooth ?? state.faceSmooth,
      faceSlim: slim ?? state.faceSlim,
    );
    final r = state.faceRect;
    final node = FaceAdjustNode(
      cx: r.center.dx,
      cy: r.center.dy,
      rx: r.width / 2,
      ry: r.height / 2,
      brighten: state.faceBrighten,
      smooth: state.faceSmooth,
      slim: state.faceSlim,
    );
    final stack = [...state.stack];
    if (stack.isNotEmpty && stack.last is FaceAdjustNode) {
      stack[stack.length - 1] = node;
    } else {
      stack.add(node);
    }
    state = state.copyWith(stack: stack, isProcessing: true);
    await _render();
  }

  // ---- Spot heal ----

  void toggleHeal() => state = state.copyWith(healMode: !state.healMode);
  void setHealRadius(double r) => state = state.copyWith(healRadius: r);

  /// Heal a blemish at image-relative ([dx],[dy]); pushed to the stack so it is
  /// undoable and replayed on export.
  Future<void> addHeal(double dx, double dy) =>
      pushNode(HealNode(dx: dx, dy: dy, radius: state.healRadius));

  // ---- Text overlays ----

  final _uuid = const Uuid();

  void addText(String text) {
    final overlay = TextOverlay(id: _uuid.v4(), text: text);
    state = state.copyWith(
      overlays: [...state.overlays, overlay],
      selectedOverlayId: overlay.id,
    );
  }

  void addSticker(String emoji) {
    final overlay = TextOverlay(
      id: _uuid.v4(),
      text: emoji,
      size: 0.16,
      bold: false,
      sticker: true,
    );
    state = state.copyWith(
      overlays: [...state.overlays, overlay],
      selectedOverlayId: overlay.id,
    );
  }

  void selectOverlay(String? id) =>
      state = state.copyWith(selectedOverlayId: id);

  void updateOverlay(String id, TextOverlay Function(TextOverlay) update) {
    state = state.copyWith(
      overlays: [
        for (final o in state.overlays) if (o.id == id) update(o) else o,
      ],
    );
  }

  /// Drag an overlay by image-relative deltas (reads current pos each call, so
  /// repeated drag events never use a stale closure value).
  void dragOverlay(String id, double ddx, double ddy) {
    updateOverlay(
      id,
      (o) => o.copyWith(
        dx: (o.dx + ddx).clamp(0.0, 1.0),
        dy: (o.dy + ddy).clamp(0.0, 1.0),
      ),
    );
  }

  void removeOverlay(String id) {
    state = state.copyWith(
      overlays: state.overlays.where((o) => o.id != id).toList(),
      selectedOverlayId: null,
    );
  }

  TextOverlay? get selectedOverlay {
    final id = state.selectedOverlayId;
    if (id == null) return null;
    for (final o in state.overlays) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Runs the CPU structural stack over the original, then decodes the result
  /// into a GPU texture the shader layer paints on top of.
  Future<void> _render() async {
    // Serialize: if a render is in flight, ask it to run once more with the
    // latest state instead of starting a concurrent (racing) render.
    if (_rendering) {
      _renderAgain = true;
      return;
    }
    _rendering = true;
    try {
      do {
        _renderAgain = false;
        if (_disposed) break;
        final original = state.original;
        if (original == null) break;
        try {
          await _renderInternal(original, _generation);
        } catch (e) {
          // Never let a single bad op take down the app; just stop the spinner.
          debugPrint('Editor render failed: $e');
          if (!_disposed) state = state.copyWith(isProcessing: false);
        }
      } while (_renderAgain && !_disposed);
    } finally {
      _rendering = false;
    }
  }

  Future<void> _renderInternal(Uint8List original, int gen) async {
    var buffer = original;
    for (final node in state.stack) {
      buffer = switch (node) {
        AdjustNode(:final brightness, :final contrast, :final saturation) =>
          await _engine.applyAdjustments(
            buffer,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
          ),
        ResizeNode(:final width, :final height) =>
          await _engine.resize(buffer, width: width, height: height),
        OrientNode(:final degrees, :final flipH) =>
          await _engine.orient(buffer, degrees: degrees, flipH: flipH),
        SmoothNode(:final amount) =>
          await _engine.smoothSkin(buffer, amount: amount),
        BodyReshapeNode(:final slim, :final stretch) =>
          await _engine.reshapeBody(buffer, slim: slim, stretch: stretch),
        HealNode(:final dx, :final dy, :final radius) =>
          await _engine.heal(buffer, dx: dx, dy: dy, radius: radius),
        FaceAdjustNode(
          :final cx,
          :final cy,
          :final rx,
          :final ry,
          :final brighten,
          :final smooth,
          :final slim,
        ) =>
          await _engine.faceAdjust(
            buffer,
            cx: cx,
            cy: cy,
            rx: rx,
            ry: ry,
            brighten: brighten,
            smooth: smooth,
            slim: slim,
          ),
        CropNode(
          :final hasRect,
          :final ratio,
          :final rectL,
          :final rectT,
          :final rectW,
          :final rectH,
        ) =>
          hasRect
              ? await _engine.cropToRect(
                  buffer,
                  left: rectL!,
                  top: rectT!,
                  width: rectW!,
                  height: rectH!,
                )
              : ratio != null
                  ? await _engine.cropToAspect(buffer, ratio: ratio)
                  : buffer,
      };
    }

    final decoded = await decodeUiImage(buffer);
    // A newer image was loaded (or the editor was disposed) while we were
    // working — discard this result so we never replace the wrong texture.
    if (_disposed || gen != _generation) {
      decoded.dispose();
      return;
    }
    _setSourceImage(decoded);
  }

  /// Full-res export: replay the GPU tonal layer over the structural result at
  /// source resolution, then stamp the watermark (free tier) via the CPU engine.
  Future<Uint8List?> export({
    required bool watermark,
    ExportFormat format = ExportFormat.jpeg,
    int quality = 95,
  }) async {
    final src = state.sourceImage;
    if (src == null) return null;

    final overlays = state.overlays;
    var rendered = await ImageRenderer.render(
      src,
      state.adjust,
      filterMatrix: state.filterMatrix,
      overlay: overlays.isEmpty
          ? null
          : (canvas, size) => paintTextOverlays(canvas, size, overlays),
    );
    if (rendered == null) return null;

    // Frame/border: grows output dimensions; fractions are of the shorter side.
    final frame = state.frame;
    if (frame != null && !frame.isNone) {
      final minSide =
          src.width < src.height ? src.width : src.height;
      rendered = await _engine.frame(
        rendered,
        borderPx: (frame.border * minSide).round(),
        bottomExtraPx: (frame.bottomExtra * minSide).round(),
        colorArgb: frame.color,
      );
    }

    if (!watermark) return rendered;
    return _engine.export(rendered, format: format, quality: quality, watermark: true);
  }
}

final editorControllerProvider =
    NotifierProvider<EditorController, EditorState>(EditorController.new);
