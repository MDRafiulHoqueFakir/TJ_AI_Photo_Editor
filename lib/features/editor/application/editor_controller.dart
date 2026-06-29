import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/color_pipeline/filter_presets.dart';
import '../../../core/services/color_pipeline/image_renderer.dart';
import '../../../core/services/dart_image_engine.dart';
import '../../../core/services/gpu/adjustment_params.dart';
import '../../../core/services/gpu/shader_loader.dart';
import '../../../core/services/image_engine.dart';
import '../domain/edit_node.dart';

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
    this.stack = const [],
    this.redoStack = const [],
    this.isProcessing = false,
  });

  final Uint8List? original; // decoded source bytes
  final ui.Image? sourceImage; // CPU-stack result, as a GPU texture
  final AdjustmentParams adjust; // live tonal layer (GPU)
  final String filterId; // selected style filter ('' = none)
  final List<EditNode> stack;
  final List<List<EditNode>> redoStack;
  final bool isProcessing;

  bool get canUndo => stack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  bool get hasImage => sourceImage != null;

  /// Resolved style-filter matrix for the GPU pipeline (null when none).
  List<double>? get filterMatrix => FilterPreset.byId(filterId)?.matrix;

  EditorState copyWith({
    Uint8List? original,
    ui.Image? sourceImage,
    AdjustmentParams? adjust,
    String? filterId,
    List<EditNode>? stack,
    List<List<EditNode>>? redoStack,
    bool? isProcessing,
  }) {
    return EditorState(
      original: original ?? this.original,
      sourceImage: sourceImage ?? this.sourceImage,
      adjust: adjust ?? this.adjust,
      filterId: filterId ?? this.filterId,
      stack: stack ?? this.stack,
      redoStack: redoStack ?? this.redoStack,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class EditorController extends Notifier<EditorState> {
  @override
  EditorState build() {
    ref.onDispose(() => state.sourceImage?.dispose());
    return const EditorState();
  }

  ImageEngine get _engine => ref.read(imageEngineProvider);

  Future<void> loadImage(Uint8List bytes) async {
    state = EditorState(original: bytes);
    await _render();
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

  /// Runs the CPU structural stack over the original, then decodes the result
  /// into a GPU texture the shader layer paints on top of.
  Future<void> _render() async {
    final original = state.original;
    if (original == null) return;

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
        CropNode() => buffer, // freeform crop rect handled by native engine
      };
    }

    final decoded = await decodeUiImage(buffer);
    state.sourceImage?.dispose();
    state = state.copyWith(sourceImage: decoded, isProcessing: false);
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

    final rendered = await ImageRenderer.render(
      src,
      state.adjust,
      filterMatrix: state.filterMatrix,
    );
    if (rendered == null) return null;

    if (!watermark) return rendered;
    return _engine.export(rendered, format: format, quality: quality, watermark: true);
  }
}

final editorControllerProvider =
    NotifierProvider<EditorController, EditorState>(EditorController.new);
