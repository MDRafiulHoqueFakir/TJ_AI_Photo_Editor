import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../gpu/adjustment_params.dart';
import 'color_adjustments.dart';

/// Live editor canvas — cross-platform (web + mobile + desktop). Applies the
/// tonal [params] via a GPU color-matrix [ColorFilter]; dragging a slider only
/// rebuilds the (cheap) filter, the GPU re-composites the same uploaded texture.
/// Vignette is painted as a radial overlay since it is spatial.
class AdjustedImage extends StatelessWidget {
  const AdjustedImage({
    super.key,
    required this.image,
    required this.params,
    this.filterMatrix,
  });

  final ui.Image image;
  final AdjustmentParams params;
  final List<double>? filterMatrix; // optional style-filter, composed under tonal

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: composedColorFilter(params, filterMatrix),
          child: RawImage(image: image, fit: BoxFit.contain),
        ),
        if (params.vignette > 0)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.9,
                  colors: [Colors.transparent, vignetteColor(params.vignette)],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
