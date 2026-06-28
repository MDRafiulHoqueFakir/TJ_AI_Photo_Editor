import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tj_photo_editor/features/editor/application/editor_controller.dart';
import 'package:tj_photo_editor/features/editor/domain/edit_node.dart';

void main() {
  group('EditorController edit stack', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('starts empty with no undo/redo', () {
      final state = container.read(editorControllerProvider);
      expect(state.canUndo, isFalse);
      expect(state.canRedo, isFalse);
      expect(state.stack, isEmpty);
    });

    test('undo moves a node to the redo stack', () async {
      final notifier = container.read(editorControllerProvider.notifier);
      // No image loaded -> _render no-ops, but stack bookkeeping still works.
      await notifier.pushNode(const CropNode(aspectLabel: '1:1'));

      var state = container.read(editorControllerProvider);
      expect(state.stack.length, 1);
      expect(state.canUndo, isTrue);

      notifier.undo();
      state = container.read(editorControllerProvider);
      expect(state.stack, isEmpty);
      expect(state.canRedo, isTrue);

      notifier.redo();
      state = container.read(editorControllerProvider);
      expect(state.stack.length, 1);
    });

    test('AdjustNode serializes for recipes/batch', () {
      const node = AdjustNode(brightness: 0.2, contrast: -0.1);
      final json = node.toJson();
      expect(json['type'], 'adjust');
      expect(json['brightness'], 0.2);
    });

    test('Phase 2 nodes serialize for recipes/batch', () {
      expect(const OrientNode(degrees: -90).toJson()['type'], 'orient');
      expect(const SmoothNode(amount: 0.4).toJson()['amount'], 0.4);
      expect(const BodyReshapeNode(slim: -0.3).toJson()['slim'], -0.3);
    });

    test('updateLiveBody keeps a single top BodyReshapeNode', () async {
      final notifier = container.read(editorControllerProvider.notifier);
      await notifier.updateLiveBody(const BodyReshapeNode(slim: 0.1));
      await notifier.updateLiveBody(const BodyReshapeNode(slim: 0.5));
      final state = container.read(editorControllerProvider);
      expect(state.stack.length, 1);
      expect((state.stack.single as BodyReshapeNode).slim, 0.5);
    });
  });
}
