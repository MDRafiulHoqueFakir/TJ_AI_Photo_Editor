import 'dart:math' as math;
import 'dart:ui';

import '../gpu/adjustment_params.dart';

/// Builds a GPU-accelerated [ColorFilter] (4x5 color matrix) from
/// [AdjustmentParams]. Unlike runtime fragment shaders, `ColorFilter.matrix`
/// is supported on **every** Flutter platform — mobile, desktop, AND web — so
/// the web app renders tonal adjustments the exact same way as mobile.
///
/// Composition: saturation (linear) → exposure+contrast scale → brightness +
/// warmth offsets, folded into a single affine color transform. Vignette is
/// spatial (not matrix-expressible) and is drawn as an overlay by the caller.
ColorFilter buildColorFilter(AdjustmentParams p) {
  // Saturation (Rec. 709 luma weights).
  final s = 1 + p.saturation;
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;

  // Exposure (≈ ±2 stops) folded with contrast into a single linear scale k,
  // contrast pivoting around mid-grey (128 in 0..255 space).
  final expF = math.pow(2.0, p.exposure * 2.0).toDouble();
  final t = 1 + p.contrast;
  final k = t * expF;
  final co = 128 * (1 - t); // contrast offset

  final bo = p.brightness * 127.5; // additive brightness
  final wo = p.warmth * 30.0; // warm = +R / -B

  return ColorFilter.matrix(<double>[
    k * (sr + s), k * sg, k * sb, 0, co + bo + wo,
    k * sr, k * (sg + s), k * sb, 0, co + bo,
    k * sr, k * sg, k * (sb + s), 0, co + bo - wo,
    0, 0, 0, 1, 0,
  ]);
}

/// Vignette overlay color at the given strength (0..1). Transparent at 0.
Color vignetteColor(double strength) =>
    Color.fromRGBO(0, 0, 0, strength.clamp(0.0, 1.0) * 0.8);
