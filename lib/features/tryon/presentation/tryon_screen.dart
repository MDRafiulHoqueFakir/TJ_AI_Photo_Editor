import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../application/virtual_tryon_service.dart';

/// Professional Attire — fit a corporate/formal outfit onto a selfie.
/// The actual photorealistic generation runs on a GPU backend
/// (see docs/VIRTUAL_TRYON.md). Until that's connected, this screen runs the
/// full flow but is honest that generation isn't available yet — it never fakes
/// a result. For corporate / LinkedIn / CV headshots (not official passports).
class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key, this.service = const StubTryOnService()});

  final VirtualTryOnService service;

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  Uint8List? _selfie;
  String _garment = 'navy_suit';
  bool _busy = false;

  static const _garments = [
    Garment(id: 'navy_suit', label: 'Navy Suit'),
    Garment(id: 'black_blazer', label: 'Black Blazer'),
    Garment(id: 'grey_suit', label: 'Grey Suit'),
    Garment(id: 'formal_shirt', label: 'Formal Shirt'),
    Garment(id: 'saree_formal', label: 'Formal Saree'),
    Garment(id: 'panjabi', label: 'Panjabi'),
  ];

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _selfie = bytes);
  }

  Future<void> _fit() async {
    final selfie = _selfie;
    if (selfie == null) return;
    setState(() => _busy = true);
    final configured = await widget.service.isConfigured();
    Uint8List? result;
    if (configured) {
      result = await widget.service.tryOn(person: selfie, garmentId: _garment);
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (!configured) {
      _showNotConnected();
    } else if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generation failed. Please try again.')),
      );
    } else {
      // Wired backend would show/download the result here.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Done.')),
      );
    }
  }

  void _showNotConnected() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI styling service not connected',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),),
            SizedBox(height: 10),
            Text(
              'Photorealistic outfit fitting runs on a generative AI backend '
              '(a GPU try-on model). Connect one — a hosted API token or your own '
              'endpoint — to turn this on. See docs/VIRTUAL_TRYON.md.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              'Best for corporate / LinkedIn / CV headshots — not for official '
              'passport submission, where altered photos may be rejected.',
              style: TextStyle(color: AppColors.proGold, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Professional Attire')),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Center(
                  child: _selfie == null
                      ? _empty()
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Image.memory(_selfie!),
                        ),
                ),
              ),
              if (_selfie != null) _garmentBar(),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.checkroom, size: 64, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        const Text('Try on professional attire',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Upload a front-facing selfie, pick an outfit, and fit it to your body. '
            'For corporate / LinkedIn headshots.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.photo_library),
          label: const Text('Choose selfie'),
        ),
      ],
    );
  }

  Widget _garmentBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final g in _garments)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(g.label),
                      selected: _garment == g.id,
                      onSelected: (_) => setState(() => _garment = g.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('New selfie'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _fit,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Fit outfit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
