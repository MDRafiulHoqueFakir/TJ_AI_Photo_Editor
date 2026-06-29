import 'package:flutter_test/flutter_test.dart';
import 'package:tj_photo_editor/core/services/color_pipeline/color_adjustments.dart';
import 'package:tj_photo_editor/core/services/color_pipeline/filter_presets.dart';
import 'package:tj_photo_editor/core/services/gpu/adjustment_params.dart';

const _identity = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

void expectClose(List<double> a, List<double> b) {
  expect(a.length, b.length);
  for (var i = 0; i < a.length; i++) {
    expect(a[i], closeTo(b[i], 1e-6), reason: 'index $i');
  }
}

void main() {
  group('color matrix composition', () {
    test('composing with identity is a no-op (both sides)', () {
      final m = FilterPreset.byId('sepia')!.matrix;
      expectClose(composeColorMatrix(_identity, m), m);
      expectClose(composeColorMatrix(m, _identity), m);
    });

    test('identity adjustments produce the identity matrix', () {
      expectClose(buildAdjustmentMatrix(AdjustmentParams.identity), _identity);
    });
  });

  group('filter presets', () {
    test('catalog starts with original = identity', () {
      expect(FilterPreset.catalog.first.id, 'original');
      expectClose(FilterPreset.catalog.first.matrix, _identity);
    });

    test('byId resolves known presets and rejects unknown', () {
      expect(FilterPreset.byId('mono'), isNotNull);
      expect(FilterPreset.byId('vivid')!.name, 'Vivid');
      expect(FilterPreset.byId('does-not-exist'), isNull);
      // Every preset matrix is a well-formed 4x5.
      for (final p in FilterPreset.catalog) {
        expect(p.matrix.length, 20, reason: p.id);
      }
    });
  });
}
