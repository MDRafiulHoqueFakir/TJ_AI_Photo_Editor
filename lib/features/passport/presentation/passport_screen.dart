import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Passport/ID maker. Phase 1 ships the standards catalog + flow shell;
/// Phase 2 wires segmentation (BG removal) + auto-crop to the selected spec.
class PassportScreen extends StatelessWidget {
  const PassportScreen({super.key});

  static const _standards = [
    (name: 'US Passport / Visa', size: '2 × 2 in', bg: 'White'),
    (name: 'Schengen Visa', size: '35 × 45 mm', bg: 'Light grey'),
    (name: 'India Passport', size: '35 × 45 mm', bg: 'White'),
    (name: 'UK Passport', size: '35 × 45 mm', bg: 'Cream'),
    (name: 'China Visa', size: '33 × 48 mm', bg: 'White'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passport / ID Maker')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _standards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final s = _standards[i];
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: ListTile(
              leading: const Icon(Icons.badge, color: AppColors.primary),
              title: Text(s.name),
              subtitle: Text('${s.size}  ·  ${s.bg} background'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${s.name}: auto-crop wired in Phase 2.')),
              ),
            ),
          );
        },
      ),
    );
  }
}
