import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adjustment_params.dart';
import 'adjustments_painter.dart';
import 'shader_loader.dart';

/// Live, GPU-accelerated editor canvas. Give it a decoded [image] and the
/// current [params]; dragging a slider only rebuilds the params and the GPU
/// re-runs the shader — no byte round-trip, no CPU pixel work.
class GpuPreview extends ConsumerWidget {
  const GpuPreview({super.key, required this.image, required this.params});

  final ui.Image image;
  final AdjustmentParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(adjustmentsProgramProvider);
    return programAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Shader load failed: $e',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
      data: (program) => RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: AdjustmentsPainter(
            program: program,
            image: image,
            params: params,
          ),
        ),
      ),
    );
  }
}
