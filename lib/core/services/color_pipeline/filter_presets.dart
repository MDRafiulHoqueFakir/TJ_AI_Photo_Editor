/// One-tap look/style filters expressed as 4x5 color matrices (row-major,
/// offsets in 0..255). GPU-accelerated via ColorFilter on every platform —
/// web included — and composes with the live tonal adjustments.
class FilterPreset {
  const FilterPreset(this.id, this.name, this.matrix);

  final String id;
  final String name;
  final List<double> matrix; // length 20

  static const _lr = 0.2126, _lg = 0.7152, _lb = 0.0722;

  /// The full catalog shown in the editor's Filter tab. `original` is first.
  static const catalog = <FilterPreset>[
    FilterPreset('original', 'Original', [
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0, //
    ]),
    FilterPreset('vivid', 'Vivid', [
      1.315, -0.286, -0.029, 0, 0, //
      -0.085, 1.114, -0.029, 0, 0, //
      -0.085, -0.286, 1.371, 0, 0, //
      0, 0, 0, 1, 0, //
    ]),
    FilterPreset('mono', 'Mono', [
      _lr, _lg, _lb, 0, 0, //
      _lr, _lg, _lb, 0, 0, //
      _lr, _lg, _lb, 0, 0, //
      0, 0, 0, 1, 0, //
    ]),
    FilterPreset('noir', 'Noir', [
      0.319, 1.073, 0.108, 0, -64, //
      0.319, 1.073, 0.108, 0, -64, //
      0.319, 1.073, 0.108, 0, -64, //
      0, 0, 0, 1, 0, //
    ]),
    FilterPreset('sepia', 'Sepia', [
      0.393, 0.769, 0.189, 0, 0, //
      0.349, 0.686, 0.168, 0, 0, //
      0.272, 0.534, 0.131, 0, 0, //
      0, 0, 0, 1, 0, //
    ]),
    FilterPreset('warm', 'Warm', [
      1, 0, 0, 0, 18, //
      0, 1, 0, 0, 6, //
      0, 0, 1, 0, -12, //
      0, 0, 0, 1, 0, //
    ]),
    FilterPreset('cool', 'Cool', [
      1, 0, 0, 0, -12, //
      0, 1, 0, 0, 2, //
      0, 0, 1, 0, 18, //
      0, 0, 0, 1, 0, //
    ]),
    FilterPreset('fade', 'Fade', [
      0.82, 0, 0, 0, 22, //
      0, 0.82, 0, 0, 22, //
      0, 0, 0.82, 0, 22, //
      0, 0, 0, 1, 0, //
    ]),
    FilterPreset('vintage', 'Vintage', [
      0.85, 0.05, 0, 0, 28, //
      0.03, 0.82, 0, 0, 18, //
      0.02, 0.05, 0.78, 0, 10, //
      0, 0, 0, 1, 0, //
    ]),
  ];

  static FilterPreset? byId(String id) {
    for (final p in catalog) {
      if (p.id == id) return p;
    }
    return null;
  }
}
