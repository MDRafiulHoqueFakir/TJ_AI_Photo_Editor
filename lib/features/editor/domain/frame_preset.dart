/// A border/frame drawn around the photo. [border] and [bottomExtra] are
/// fractions of the image's shorter side, so frames scale with the photo and
/// render identically in the live preview and the full-resolution export.
class FramePreset {
  const FramePreset({
    required this.id,
    required this.name,
    this.border = 0,
    this.bottomExtra = 0,
    this.color = 0xFFFFFFFF,
  });

  final String id;
  final String name;
  final double border;
  final double bottomExtra; // extra bottom margin (polaroid look)
  final int color; // ARGB

  bool get isNone => border == 0 && bottomExtra == 0;

  static const catalog = <FramePreset>[
    FramePreset(id: 'none', name: 'None'),
    FramePreset(id: 'white', name: 'White', border: 0.04),
    FramePreset(id: 'black', name: 'Black', border: 0.04, color: 0xFF000000),
    FramePreset(id: 'soft', name: 'Soft', border: 0.04, color: 0xFFEDEDED),
    FramePreset(id: 'film', name: 'Film', border: 0.05, color: 0xFF111111),
    FramePreset(
      id: 'polaroid',
      name: 'Polaroid',
      border: 0.05,
      bottomExtra: 0.18,
    ),
  ];

  static FramePreset? byId(String id) {
    for (final f in catalog) {
      if (f.id == id) return f;
    }
    return null;
  }
}
