import 'dart:typed_data';

/// Abstraction over the pixel-processing backend.
///
/// Phase 1: a pure-Dart implementation backed by package:image (slow but
/// dependency-free, good enough to validate the UI and the edit-stack model).
/// Phase 2: swap for a C++/OpenCV + GPU shader implementation via dart:ffi —
/// the interface stays the same so UI code does not change.
abstract interface class ImageEngine {
  /// Apply tonal adjustments. Values are normalized -1.0..1.0 (0 = no change).
  Future<Uint8List> applyAdjustments(
    Uint8List source, {
    double brightness = 0,
    double contrast = 0,
    double saturation = 0,
  });

  /// Resize to target dimensions (Lanczos in the native impl).
  Future<Uint8List> resize(Uint8List source, {required int width, required int height});

  /// Downscale so the longest edge is at most [maxLongEdge] (keeps aspect).
  /// Returns the source unchanged if it already fits. Used to bound the working
  /// image so on-device pixel ops can't exhaust memory / crash on huge photos.
  Future<Uint8List> fitWithin(Uint8List source, {required int maxLongEdge});

  /// Crop to a pixel rectangle.
  Future<Uint8List> crop(
    Uint8List source, {
    required int x,
    required int y,
    required int width,
    required int height,
  });

  /// Rotate by [degrees] (clockwise) and/or mirror horizontally.
  Future<Uint8List> orient(Uint8List source, {double degrees = 0, bool flipH = false});

  /// Skin/portrait smoothing. [amount] 0..1 blends toward a blurred copy.
  /// Phase 2 native impl uses frequency separation on an ML skin mask; this
  /// Dart path is a global blend approximation good enough for QA/preview.
  Future<Uint8List> smoothSkin(Uint8List source, {double amount = 0.3});

  /// Body reshape: [slim] and [stretch] in -1..1 (0 = no change). Squeezes/
  /// expands then cover-crops back to the original frame (no black bars).
  Future<Uint8List> reshapeBody(Uint8List source, {double slim = 0, double stretch = 0});

  /// Center-crop to the given aspect [ratio] (width / height).
  Future<Uint8List> cropToAspect(Uint8List source, {required double ratio});

  /// Reduce noise (edge-preserving-ish smoothing). [amount] 0..1.
  Future<Uint8List> denoise(Uint8List source, {double amount = 0.5});

  /// HDR-style local contrast + tone pop. [amount] 0..1.
  Future<Uint8List> hdr(Uint8List source, {double amount = 0.6});

  /// Upscale by [factor] (cubic). Not AI super-resolution, but a real resize.
  Future<Uint8List> upscale(Uint8List source, {int factor = 2});

  /// Replace pixels outside [subjectMask] with [bgArgb] (passport/BG tools).
  /// If [subjectMask] is null (no ML available), fills the whole canvas tint.
  Future<Uint8List> replaceBackground(
    Uint8List source, {
    Uint8List? subjectMask,
    required int bgArgb,
  });

  /// Spot-heal: remove a small blemish at ([dx],[dy]) (image-relative 0..1) by
  /// replacing a feathered disc with the average skin tone sampled from a ring
  /// around it. [radius] is a fraction of the shorter side.
  Future<Uint8List> heal(
    Uint8List source, {
    required double dx,
    required double dy,
    required double radius,
  });

  /// Wrap [source] in a solid border. [bottomExtraPx] adds extra bottom margin
  /// (polaroid look). Output dimensions grow by the border on all sides.
  Future<Uint8List> frame(
    Uint8List source, {
    required int borderPx,
    required int bottomExtraPx,
    required int colorArgb,
  });

  /// Encode the working buffer for export.
  Future<Uint8List> export(
    Uint8List source, {
    required ExportFormat format,
    int quality = 90,
    bool watermark = true,
  });
}

enum ExportFormat { jpeg, png, webp }
