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
      expect(const HealNode(dx: 0.4, dy: 0.6).toJson()['type'], 'heal');
    });

    test('toggleHeal flips heal mode; addHeal pushes a HealNode', () async {
      final n = container.read(editorControllerProvider.notifier);
      n.toggleHeal();
      n.setHealRadius(0.05);
      expect(container.read(editorControllerProvider).healMode, isTrue);
      await n.addHeal(0.4, 0.6);
      final node = container.read(editorControllerProvider).stack.single;
      expect(node, isA<HealNode>());
      expect((node as HealNode).dx, 0.4);
      expect(node.radius, 0.05);
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

  group('text overlays', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('addText adds an overlay and selects it', () {
      final n = container.read(editorControllerProvider.notifier);
      n.addText('Hello');
      final s = container.read(editorControllerProvider);
      expect(s.overlays.length, 1);
      expect(s.overlays.single.text, 'Hello');
      expect(s.selectedOverlayId, s.overlays.single.id);
    });

    test('dragOverlay clamps position to 0..1', () {
      final n = container.read(editorControllerProvider.notifier);
      n.addText('x');
      final id = container.read(editorControllerProvider).overlays.single.id;
      n.dragOverlay(id, -5, 5); // way out of bounds both directions
      final o = container.read(editorControllerProvider).overlays.single;
      expect(o.dx, 0.0);
      expect(o.dy, 1.0);
    });

    test('selectFrame resolves the frame preset', () {
      final n = container.read(editorControllerProvider.notifier);
      n.selectFrame('polaroid');
      final f = container.read(editorControllerProvider).frame;
      expect(f, isNotNull);
      expect(f!.id, 'polaroid');
      expect(f.bottomExtra, greaterThan(0));
      n.selectFrame(''); // '' = no frame selected
      expect(container.read(editorControllerProvider).frame, isNull);
    });

    test('addSticker marks the overlay as a sticker', () {
      final n = container.read(editorControllerProvider.notifier);
      n.addSticker('🔥');
      final o = container.read(editorControllerProvider).overlays.single;
      expect(o.sticker, isTrue);
      expect(o.text, '🔥');
    });

    test('removeOverlay deletes it and clears selection', () {
      final n = container.read(editorControllerProvider.notifier);
      n.addText('x');
      final id = container.read(editorControllerProvider).overlays.single.id;
      n.removeOverlay(id);
      final s = container.read(editorControllerProvider);
      expect(s.overlays, isEmpty);
      expect(s.selectedOverlayId, isNull);
    });
  });
}
