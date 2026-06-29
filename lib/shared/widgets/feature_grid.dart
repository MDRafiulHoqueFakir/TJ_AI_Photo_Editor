import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

class FeatureItem {
  const FeatureItem({
    required this.icon,
    required this.label,
    required this.tier,
    this.creditKey,
  });

  final IconData icon;
  final String label;
  final ToolTier tier;
  final String? creditKey;
}

/// Reusable grid used by AI Studio, Quick Tools, etc. Renders tier badges
/// (PRO / credit cost) so gating is visible before the user taps in.
class FeatureGrid extends StatelessWidget {
  const FeatureGrid({super.key, required this.items, required this.onTap});

  final List<FeatureItem> items;
  final void Function(FeatureItem) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        for (final item in items)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onTap(item),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              padding: const EdgeInsets.all(14),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, color: AppColors.primary, size: 30),
                      const SizedBox(height: 10),
                      Text(
                        item.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Positioned(top: 0, right: 0, child: _badge(item)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _badge(FeatureItem item) {
    // When everything is unlocked, don't show PRO / credit-cost badges.
    if (AppConstants.unlockAllFeatures) return const SizedBox.shrink();
    switch (item.tier) {
      case ToolTier.free:
        return const SizedBox.shrink();
      case ToolTier.pro:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.proGold,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'PRO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        );
      case ToolTier.cloud:
        final cost = AppConstants.creditCosts[item.creditKey] ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            gradient: AppColors.premiumGradient,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 11, color: Colors.white),
              Text(
                '$cost',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
    }
  }
}
