/// A single non-destructive edit operation in the stack.
///
/// The whole stack is serializable -> this is what makes Recipes and batch
/// editing possible: save the list, replay it on another photo.
sealed class EditNode {
  const EditNode();
  Map<String, dynamic> toJson();
}

class AdjustNode extends EditNode {
  const AdjustNode({this.brightness = 0, this.contrast = 0, this.saturation = 0});

  final double brightness; // -1..1
  final double contrast; // -1..1
  final double saturation; // -1..1

  AdjustNode copyWith({double? brightness, double? contrast, double? saturation}) {
    return AdjustNode(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'adjust',
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
      };
}

class ResizeNode extends EditNode {
  const ResizeNode({required this.width, required this.height});
  final int width;
  final int height;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'resize', 'width': width, 'height': height};
}

class CropNode extends EditNode {
  const CropNode({
    required this.aspectLabel,
    this.ratio,
    this.rectL,
    this.rectT,
    this.rectW,
    this.rectH,
  });
  final String aspectLabel; // e.g. "1:1", "4:5", "Free"
  final double? ratio; // width/height; for aspect presets
  // Freeform crop rect in image fractions (0..1); set for a hand-drawn crop.
  final double? rectL;
  final double? rectT;
  final double? rectW;
  final double? rectH;

  bool get hasRect => rectW != null && rectH != null;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'crop',
        'aspect': aspectLabel,
        'ratio': ratio,
        if (hasRect) 'rect': [rectL, rectT, rectW, rectH],
      };
}

class OrientNode extends EditNode {
  const OrientNode({this.degrees = 0, this.flipH = false});
  final double degrees;
  final bool flipH;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'orient', 'degrees': degrees, 'flipH': flipH};
}

class SmoothNode extends EditNode {
  const SmoothNode({this.amount = 0.3});
  final double amount; // 0..1

  @override
  Map<String, dynamic> toJson() => {'type': 'smooth', 'amount': amount};
}

class HealNode extends EditNode {
  const HealNode({required this.dx, required this.dy, this.radius = 0.035});
  final double dx; // 0..1
  final double dy; // 0..1
  final double radius; // fraction of shorter side

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'heal', 'dx': dx, 'dy': dy, 'radius': radius};
}

class BodyReshapeNode extends EditNode {
  const BodyReshapeNode({this.slim = 0, this.stretch = 0});
  final double slim; // -1..1
  final double stretch; // -1..1

  BodyReshapeNode copyWith({double? slim, double? stretch}) =>
      BodyReshapeNode(slim: slim ?? this.slim, stretch: stretch ?? this.stretch);

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'body', 'slim': slim, 'stretch': stretch};
}
