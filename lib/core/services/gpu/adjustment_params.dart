import 'dart:ui';

/// Immutable set of live adjustment values driving [adjustments.frag].
/// All fields are normalized; 0 = no change (identity).
class AdjustmentParams {
  const AdjustmentParams({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.exposure = 0,
    this.warmth = 0,
    this.vignette = 0,
  });

  final double brightness;
  final double contrast;
  final double saturation;
  final double exposure;
  final double warmth;
  final double vignette;

  static const identity = AdjustmentParams();

  bool get isIdentity =>
      brightness == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      exposure == 0 &&
      warmth == 0 &&
      vignette == 0;

  AdjustmentParams copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? exposure,
    double? warmth,
    double? vignette,
  }) {
    return AdjustmentParams(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      exposure: exposure ?? this.exposure,
      warmth: warmth ?? this.warmth,
      vignette: vignette ?? this.vignette,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdjustmentParams &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.saturation == saturation &&
      other.exposure == exposure &&
      other.warmth == warmth &&
      other.vignette == vignette;

  @override
  int get hashCode =>
      Object.hash(brightness, contrast, saturation, exposure, warmth, vignette);

  /// Push the float uniforms in the exact order declared in the shader.
  /// uSize occupies float slots 0,1 (set by the painter); these follow.
  void applyTo(FragmentShader shader, {required int startIndex}) {
    shader
      ..setFloat(startIndex, brightness)
      ..setFloat(startIndex + 1, contrast)
      ..setFloat(startIndex + 2, saturation)
      ..setFloat(startIndex + 3, exposure)
      ..setFloat(startIndex + 4, warmth)
      ..setFloat(startIndex + 5, vignette);
  }
}
