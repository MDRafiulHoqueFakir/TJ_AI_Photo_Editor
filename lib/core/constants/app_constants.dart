/// App-wide constants and feature flags.
abstract class AppConstants {
  static const String appName = 'TJ Photo Editor';

  // Free-tier limits
  static const int freeMaxExportPx = 1920; // long edge
  static const bool freeExportsWatermarked = true;

  // Credit costs for cloud actions (generative). Shown before run.
  static const Map<String, int> creditCosts = {
    'hair_restyle': 4,
    'generative_fill': 3,
    'ai_art_prompt': 3,
    'upscale_4k': 2,
    'background_generate': 3,
  };
}

/// Capabilities unlocked by entitlement. Used by the paywall gate.
enum Entitlement { free, pro }

/// Identifies which tools require Pro and/or credits.
enum ToolTier {
  free, // on-device, always available
  pro, // on-device but Pro-gated (e.g. 4K export, batch)
  cloud, // generative, Pro + credits
}
