import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../application/passport_service.dart';

/// Passport / ID maker — functional in pure Dart: pick a photo, crop it to the
/// chosen standard's exact print dimensions, and download a single photo or a
/// tiled 6x4" print sheet. (Auto background removal arrives with the on-device
/// segmentation model; for now shoot against a plain wall.)
class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  bool _busy = false;
  PassportSpec? _spec;
  Uint8List? _sheet;
  Uint8List? _single;

  Future<void> _start(PassportSpec spec) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _busy = true);
    final bytes = await picked.readAsBytes();
    // Generated synchronously but quick; the spinner covers it.
    final sheet = PassportService.buildSheet(bytes, spec);
    final single = PassportService.buildSingle(bytes, spec);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _spec = spec;
      _sheet = sheet;
      _single = single;
    });
  }

  Future<void> _download(Uint8List bytes, String suffix) async {
    try {
      await FileSaver.instance.saveFile(
        name: 'tj_passport_${suffix}_${DateTime.now().millisecondsSinceEpoch}',
        bytes: bytes,
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

  void _reset() => setState(() {
        _spec = null;
        _sheet = null;
        _single = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passport / ID Maker'),
        leading: _sheet != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _reset)
            : null,
      ),
      body: Stack(
        children: [
          if (_sheet == null) _specList() else _result(),
          if (_busy)
            const ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _specList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Pick a standard, then choose a photo. Tip: use a photo taken against a plain wall.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        for (final spec in PassportSpec.catalog)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: ListTile(
              leading: const Icon(Icons.badge, color: AppColors.primary),
              title: Text(spec.name),
              subtitle: Text(
                '${spec.widthMm.toStringAsFixed(0)} × ${spec.heightMm.toStringAsFixed(0)} mm  ·  ${spec.bgLabel} bg',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _start(spec),
            ),
          ),
      ],
    );
  }

  Widget _result() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _spec!.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Print sheet (6 × 4 in). Cut along the guides.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(_sheet!, fit: BoxFit.contain),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _download(_sheet!, 'sheet'),
                icon: const Icon(Icons.grid_on),
                label: const Text('Print sheet'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _download(_single!, 'single'),
                icon: const Icon(Icons.photo),
                label: const Text('Single'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
