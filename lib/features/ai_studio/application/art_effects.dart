import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// One artistic look. Applied fully on-device (package:image) — no model or
/// cloud needed — so the AI Art tool actually works offline.
enum ArtStyle { sketch, popArt, poster, oil, pixel, vintage }

extension ArtStyleLabel on ArtStyle {
  String get label => switch (this) {
        ArtStyle.sketch => 'Sketch',
        ArtStyle.popArt => 'Pop Art',
        ArtStyle.poster => 'Poster',
        ArtStyle.oil => 'Oil',
        ArtStyle.pixel => 'Pixel',
        ArtStyle.vintage => 'Vintage',
      };
}

abstract class ArtEffects {
  /// Apply [style] to [source] and return PNG bytes. [maxSide] downscales first
  /// for fast previews; pass a large value for full-res output.
  static Uint8List apply(Uint8List source, ArtStyle style, {int maxSide = 1600}) {
    var image = img.decodeImage(source);
    if (image == null) return source;

    // Bound work for responsiveness on big photos.
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > maxSide) {
      final scale = maxSide / longest;
      image = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
        interpolation: img.Interpolation.average,
      );
    }

    final out = switch (style) {
      ArtStyle.sketch => _sketch(image),
      ArtStyle.popArt => _popArt(image),
      ArtStyle.poster => img.quantize(image.clone(), numberOfColors: 8),
      ArtStyle.oil => _oil(image),
      ArtStyle.pixel => img.pixelate(image.clone(), size: 12),
      ArtStyle.vintage => _vintage(image),
    };
    return Uint8List.fromList(img.encodePng(out));
  }

  static img.Image _sketch(img.Image src) {
    final gray = img.grayscale(src.clone());
    final edges = img.sobel(gray, amount: 1);
    return img.invert(edges); // dark pencil lines on light paper
  }

  static img.Image _popArt(img.Image src) {
    final q = img.quantize(src.clone(), numberOfColors: 6);
    return img.adjustColor(q, saturation: 2, contrast: 1.1);
  }

  static img.Image _oil(img.Image src) {
    final blurred = img.gaussianBlur(src.clone(), radius: 3);
    return img.quantize(blurred, numberOfColors: 18);
  }

  static img.Image _vintage(img.Image src) {
    final s = img.sepia(src.clone(), amount: 0.7);
    return img.vignette(s, start: 0.7, end: 1.4);
  }
}
