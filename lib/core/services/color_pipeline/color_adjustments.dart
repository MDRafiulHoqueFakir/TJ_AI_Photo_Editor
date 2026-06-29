import 'dart:math' as math;
import 'dart:ui';

import '../gpu/adjustment_params.dart';

/// Builds the 4x5 color matrix (row-major, offsets in 0..255) for the live
/// tonal [AdjustmentParams]: saturation (linear) → exposure+contrast scale →
/// brightness + warmth offsets, folded into one affine color transform.
List<double> buildAdjustmentMatrix(AdjustmentParams p) {
  final s = 1 + p.saturation;
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;

  final expF = math.pow(2.0, p.exposure * 2.0).toDouble();
  final t = 1 + p.contrast;
  final k = t * expF;
  final co = 128 * (1 - t);

  final bo = p.brightness * 127.5;
  final wo = p.warmth * 30.0;

  return <double>[
    k * (sr + s), k * sg, k * sb, 0, co + bo + wo,
    k * sr, k * (sg + s), k * sb, 0, co + bo,
    k * sr, k * sg, k * (sb + s), 0, co + bo - wo,
    0, 0, 0, 1, 0,
  ];
}

/// Composes two 4x5 color matrices: returns `a ∘ b` (apply [b] first, then [a]).
/// Used to stack a style-filter under the live tonal adjustments in one filter.
List<double> composeColorMatrix(List<double> a, List<double> b) {
  final m2 = _to5x5(a);
  final m1 = _to5x5(b);
  final out = List<double>.filled(25, 0);
  for (var r = 0; r < 5; r++) {
    for (var c = 0; c < 5; c++) {
      var sum = 0.0;
      for (var k = 0; k < 5; k++) {
        sum += m2[r * 5 + k] * m1[k * 5 + c];
      }
      out[r * 5 + c] = sum;
    }
  }
  return [for (var r = 0; r < 4; r++) for (var c = 0; c < 5; c++) out[r * 5 + c]];
}

List<double> _to5x5(List<double> m) => <double>[...m, 0, 0, 0, 0, 1];

/// The effective GPU color filter: live adjustments applied on top of an
/// optional style-filter matrix. Single ColorFilter → one GPU pass.
ColorFilter composedColorFilter(AdjustmentParams params, List<double>? filterMatrix) {
  final adj = buildAdjustmentMatrix(params);
  if (filterMatrix == null) return ColorFilter.matrix(adj);
  return ColorFilter.matrix(composeColorMatrix(adj, filterMatrix));
}

/// Convenience for adjustments only.
ColorFilter buildColorFilter(AdjustmentParams p) =>
    ColorFilter.matrix(buildAdjustmentMatrix(p));

/// Vignette overlay color at the given strength (0..1). Transparent at 0.
Color vignetteColor(double strength) =>
    Color.fromRGBO(0, 0, 0, strength.clamp(0.0, 1.0) * 0.8);
