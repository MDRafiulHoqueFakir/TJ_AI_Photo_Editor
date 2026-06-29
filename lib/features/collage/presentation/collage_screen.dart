import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/gpu/shader_loader.dart';
import '../../../core/theme/app_colors.dart';
import '../application/collage_renderer.dart';
import '../domain/collage_layout.dart';

class CollageScreen extends StatefulWidget {
  const CollageScreen({super.key});

  @override
  State<CollageScreen> createState() => _CollageScreenState();
}

class _CollageScreenState extends State<CollageScreen> {
  CollageLayout _layout = CollageLayout.catalog.first;
  final Map<String, Uint8List> _byKey = {}; // "layoutId:cellIndex" -> bytes
  double _spacing = 0.012;
  int _bg = 0xFFFFFFFF;
  bool _busy = false;

  static const _bgSwatches = [0xFFFFFFFF, 0xFF000000, 0xFFEDEDED, 0xFF7C5CFF, 0xFF00D9C0];

  String _key(int i) => '${_layout.id}:$i';

  Future<void> _pickFor(int i) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _byKey[_key(i)] = bytes);
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final images = <int, ui.Image>{};
      for (var i = 0; i < _layout.count; i++) {
        final bytes = _byKey[_key(i)];
        if (bytes != null) images[i] = await decodeUiImage(bytes);
      }
      if (images.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add at least one photo first.')),
          );
        }
        return;
      }
      final out = await CollageRenderer.render(
        layout: _layout,
        images: images,
        size: 2048,
        spacing: _spacing,
        bgArgb: _bg,
      );
      for (final im in images.values) {
        im.dispose();
      }
      if (out == null) return;
      await FileSaver.instance.saveFile(
        name: 'tj_collage_${DateTime.now().millisecondsSinceEpoch}',
        bytes: out,
        fileExtension: 'png',
        mimeType: MimeType.png,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collage saved. Check your downloads.')),
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
      appBar: AppBar(
        title: const Text('Collage'),
        actions: [
          IconButton(icon: const Icon(Icons.ios_share), onPressed: _busy ? null : _export),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _layoutSelector(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _preview(),
                    ),
                  ),
                ),
              ),
              _controls(),
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

  Widget _layoutSelector() {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: CollageLayout.catalog.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final l = CollageLayout.catalog[i];
          final selected = l.id == _layout.id;
          return GestureDetector(
            onTap: () => setState(() => _layout = l),
            child: Container(
              width: 60,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                  width: selected ? 2 : 1,
                ),
              ),
              child: _layoutThumb(l),
            ),
          );
        },
      ),
    );
  }

  Widget _layoutThumb(CollageLayout l) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (_, c) {
          final s = c.maxWidth;
          return Stack(
            children: [
              for (final cell in l.cells)
                Positioned(
                  left: cell.left * s,
                  top: cell.top * s,
                  width: cell.width * s,
                  height: cell.height * s,
                  child: const Padding(
                    padding: EdgeInsets.all(1),
                    child: ColoredBox(color: AppColors.textSecondary),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _preview() {
    return ColoredBox(
      color: Color(_bg),
      child: LayoutBuilder(
        builder: (_, c) {
          final s = c.maxWidth;
          final gapPx = _spacing * s / 2;
          return Stack(
            children: [
              for (var i = 0; i < _layout.count; i++)
                Positioned(
                  left: _layout.cells[i].left * s,
                  top: _layout.cells[i].top * s,
                  width: _layout.cells[i].width * s,
                  height: _layout.cells[i].height * s,
                  child: Padding(
                    padding: EdgeInsets.all(gapPx),
                    child: _cell(i),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _cell(int i) {
    final bytes = _byKey[_key(i)];
    return GestureDetector(
      onTap: () => _pickFor(i),
      child: bytes == null
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                border: Border.all(color: AppColors.divider),
              ),
              child: const Center(
                child: Icon(Icons.add_photo_alternate_outlined,
                    color: AppColors.textSecondary,),
              ),
            )
          : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }

  Widget _controls() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Spacing', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _spacing,
                  max: 0.06,
                  onChanged: (v) => setState(() => _spacing = v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Background', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
              for (final c in _bgSwatches)
                GestureDetector(
                  onTap: () => setState(() => _bg = c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _bg == c ? AppColors.primary : AppColors.divider,
                        width: _bg == c ? 2 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
