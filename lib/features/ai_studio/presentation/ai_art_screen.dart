import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../application/art_effects.dart';

/// AI Art — turn a photo into an artistic style. Runs fully on-device, so it
/// works offline and needs no cloud/credits.
class AiArtScreen extends StatefulWidget {
  const AiArtScreen({super.key, this.initialStyle = ArtStyle.enhance});

  final ArtStyle initialStyle;

  @override
  State<AiArtScreen> createState() => _AiArtScreenState();
}

class _AiArtScreenState extends State<AiArtScreen> {
  Uint8List? _source;
  Uint8List? _result;
  late ArtStyle _style = widget.initialStyle;
  bool _busy = false;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _source = bytes;
      _result = null;
    });
    await _apply(_style);
  }

  Future<void> _apply(ArtStyle style) async {
    final src = _source;
    if (src == null) return;
    setState(() {
      _busy = true;
      _style = style;
    });
    // Process off the first frame so the spinner shows.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final out = ArtEffects.apply(src, style);
    if (!mounted) return;
    setState(() {
      _result = out;
      _busy = false;
    });
  }

  Future<void> _download() async {
    final r = _result;
    if (r == null) return;
    try {
      await FileSaver.instance.saveFile(
        name: 'tj_art_${_style.label.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
        bytes: r,
        fileExtension: 'png',
        mimeType: MimeType.png,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved. Check your downloads.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Art'),
        actions: [
          if (_result != null)
            IconButton(icon: const Icon(Icons.ios_share), onPressed: _download),
        ],
      ),
      body: Stack(
        children: [
          if (_source == null)
            _empty()
          else
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _result != null
                          ? Image.memory(_result!, gaplessPlayback: true)
                          : Image.memory(_source!),
                    ),
                  ),
                ),
                _styleBar(),
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

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.brush, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'Turn a photo into art',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sketch, Pop Art, Oil, Pixel and more — on-device.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.photo_library),
            label: const Text('Choose photo'),
          ),
        ],
      ),
    );
  }

  Widget _styleBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final s in ArtStyle.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.label),
                  selected: _style == s && _result != null,
                  onSelected: (_) => _apply(s),
                ),
              ),
            TextButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('New photo'),
            ),
          ],
        ),
      ),
    );
  }
}
