import 'package:flutter/material.dart';

/// Centralized palette. Editor apps live in dark UI so the photo pops.
abstract class AppColors {
  static const Color background = Color(0xFF0E0E12);
  static const Color surface = Color(0xFF1A1A20);
  static const Color surfaceHigh = Color(0xFF26262F);
  static const Color primary = Color(0xFF7C5CFF); // violet — AI/premium accent
  static const Color primaryVariant = Color(0xFF5B3DF5);
  static const Color accent = Color(0xFF00D9C0); // teal — actions/success
  static const Color danger = Color(0xFFFF5C5C);
  static const Color textPrimary = Color(0xFFF4F4F6);
  static const Color textSecondary = Color(0xFF9A9AA8);
  static const Color divider = Color(0xFF2E2E38);
  static const Color proGold = Color(0xFFFFC857);

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
