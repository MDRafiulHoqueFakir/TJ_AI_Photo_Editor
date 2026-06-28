import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/dart_image_engine.dart';
import '../../../core/services/image_engine.dart';
import '../domain/edit_node.dart';

final imageEngineProvider = Provider<ImageEngine>((_) => const DartImageEngine());

/// Editor session state: the original bytes + the non-destructive edit stack
/// + an undo/redo history of stacks.
@immutable
class EditorState {
  const EditorState({
    this.original,
    this.preview,
    this.stack = const [],
    this.redoStack = const [],
    this.isProcessing = false,
  });

  final Uint8List? original; // decoded source bytes
  final Uint8List? preview; // rendered (downscaled) proxy shown on canvas
  final List<EditNode> stack;
  final List<List<EditNode>> redoStack;
  final bool isProcessing;

  bool get canUndo => stack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  bool get hasImage => original != null;

  EditorState copyWith({
    Uint8List? original,
    Uint8List? preview,
    List<EditNode>? stack,
    List<List<EditNode>>? redoStack,
    bool? isProcessing,
  }) {
    return EditorState(
      original: original ?? this.original,
      preview: preview ?? this.preview,
      stack: stack ?? this.stack,
      redoStack: redoStack ?? this.redoStack,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class EditorController extends Notifier<EditorState> {
  @override
  EditorState build() => const EditorState();

  ImageEngine get _engine => ref.read(imageEngineProvider);

  Future<void> loadImage(Uint8List bytes) async {
    state = EditorState(original: bytes, preview: bytes);
  }

  /// Push a new node (e.g. live slider commit) and re-render the preview.
  Future<void> pushNode(EditNode node) async {
    final newStack = [...state.stack, node];
    state = state.copyWith(stack: newStack, redoStack: const [], isProcessing: true);
    await _render();
  }

  /// Replace the top adjust node while dragging (avoids stack spam).
  Future<void> updateLiveAdjust(AdjustNode node) async {
    final stack = [...state.stack];
    if (stack.isNotEmpty && stack.last is AdjustNode) {
      stack[stack.length - 1] = node;
    } else {
      stack.add(node);
    }
    state = state.copyWith(stack: stack, isProcessing: true);
    await _render();
  }

  /// Live body-reshape drag: keeps a single top BodyReshapeNode.
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

  /// Re-runs the edit stack over the original to produce the preview.
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
    state = state.copyWith(preview: buffer, isProcessing: false);
  }

  /// Full-res export. [watermark] is forced on for free tier by the caller.
  Future<Uint8List?> export({
    required ExportFormat format,
    int quality = 90,
    required bool watermark,
  }) async {
    final preview = state.preview;
    if (preview == null) return null;
    return _engine.export(preview, format: format, quality: quality, watermark: watermark);
  }
}

final editorControllerProvider =
    NotifierProvider<EditorController, EditorState>(EditorController.new);
