import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'adjustment_params.dart';

/// Paints [image] through the adjustments fragment shader. Because the GPU does
/// all the per-pixel work, repainting on every slider tick stays at frame rate
/// even on large textures — the image is uploaded once and only uniforms change.
///
/// Uniform float index map (must match shaders/adjustments.frag declaration
/// order; samplers do not consume float indices):
///   0,1 -> uSize (vec2)
///   sampler 0 -> uTexture
///   2 -> uBrightness, 3 -> uContrast, 4 -> uSaturation,
///   5 -> uExposure, 6 -> uWarmth, 7 -> uVignette
class AdjustmentsPainter extends CustomPainter {
  AdjustmentsPainter({
    required this.program,
    required this.image,
    required this.params,
  });

  final ui.FragmentProgram program;
  final ui.Image image;
  final AdjustmentParams params;

  @override
  void paint(Canvas canvas, Size size) {
    // Fit the image into [size] preserving aspect ratio (contain).
    final dst = _contain(
      Size(image.width.toDouble(), image.height.toDouble()),
      size,
    );

    final shader = program.fragmentShader()
      ..setFloat(0, dst.width)
      ..setFloat(1, dst.height)
      ..setImageSampler(0, image);
    params.applyTo(shader, startIndex: 2);

    canvas.save();
    canvas.translate(dst.left, dst.top);
    canvas.drawRect(
      Offset.zero & dst.size,
      Paint()..shader = shader,
    );
    canvas.restore();
  }

  Rect _contain(Size content, Size box) {
    final scale = (box.width / content.width) < (box.height / content.height)
        ? box.width / content.width
        : box.height / content.height;
    final w = content.width * scale;
    final h = content.height * scale;
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
  }

  @override
  bool shouldRepaint(covariant AdjustmentsPainter old) =>
      old.image != image || old.params != params || old.program != program;
}
