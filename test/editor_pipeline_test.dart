import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tj_photo_editor/features/editor/application/editor_controller.dart';
import 'package:tj_photo_editor/features/editor/domain/edit_node.dart';

/// A small but real PNG to drive the full pipeline.
Uint8List _testImage() {
  final im = img.Image(width: 160, height: 120);
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      im.setPixelRgb(x, y, (x * 255) ~/ 160, (y * 255) ~/ 120, 140);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  // Needs the widgets binding for ui image codec + PictureRecorder.toImage.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('editor pipeline on a real image', () {
    late ProviderContainer container;
    late EditorController c;

    setUp(() {
      container = ProviderContainer();
      c = container.read(editorControllerProvider.notifier);
    });
    tearDown(() => container.dispose());

    test('loads an image and produces a source texture', () async {
      await c.loadImage(_testImage());
      final s = container.read(editorControllerProvider);
      expect(s.hasImage, isTrue);
      expect(s.sourceImage, isNotNull);
    });

    test('a large photo is bounded to the working size (no freeze)', () async {
      final big = img.Image(width: 2400, height: 1800);
      img.fill(big, color: img.ColorRgb8(120, 130, 140));
      await c.loadImage(Uint8List.fromList(img.encodeJpg(big, quality: 80)));
      final s = container.read(editorControllerProvider);
      expect(s.sourceImage, isNotNull);
      expect(s.sourceImage!.width, lessThanOrEqualTo(1600));
      expect(s.sourceImage!.height, lessThanOrEqualTo(1600));
    });

    test('every structural op runs without throwing', () async {
      await c.loadImage(_testImage());
      await c.pushNode(const SmoothNode(amount: 0.6));
      await c.updateLiveBody(const BodyReshapeNode(slim: -0.4, stretch: 0.3));
      await c.addHeal(0.5, 0.5);
      await c.pushNode(const OrientNode(degrees: -90));
      await c.pushNode(const OrientNode(flipH: true));
      final s = container.read(editorControllerProvider);
      expect(s.sourceImage, isNotNull);
      expect(s.isProcessing, isFalse);
    });

    test('filter, frame, text, sticker, then export produces bytes', () async {
      await c.loadImage(_testImage());
      c
        ..selectFilter('vivid')
        ..selectFrame('polaroid');
      c.addText('Hello');
      c.addSticker('🔥');
      final out = await c.export(watermark: false);
      expect(out, isNotNull);
      expect(out!.lengthInBytes, greaterThan(0));
    });

    test('rapid overlapping edits do not double-dispose the texture', () async {
      await c.loadImage(_testImage());
      // Fire many live updates WITHOUT awaiting — simulates dragging a slider.
      final futures = <Future<void>>[
        for (var i = 0; i < 12; i++)
          c.updateLiveBody(BodyReshapeNode(slim: i / 12 - 0.5)),
      ];
      await Future.wait(futures);
      final s = container.read(editorControllerProvider);
      expect(s.sourceImage, isNotNull);
      expect(s.isProcessing, isFalse);
    });

    test('loading a new image mid-edit is safe', () async {
      await c.loadImage(_testImage());
      final f = c.pushNode(const SmoothNode(amount: 0.6)); // in-flight render
      await c.loadImage(_testImage()); // new image arrives mid-render
      await f;
      expect(container.read(editorControllerProvider).sourceImage, isNotNull);
    });

    test('undo/redo after edits keeps a valid texture', () async {
      await c.loadImage(_testImage());
      await c.pushNode(const SmoothNode(amount: 0.4));
      c.undo();
      c.redo();
      final s = container.read(editorControllerProvider);
      expect(s.sourceImage, isNotNull);
    });
  });
}
