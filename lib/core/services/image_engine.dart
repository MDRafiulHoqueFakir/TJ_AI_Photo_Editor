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

  /// Encode the working buffer for export.
  Future<Uint8List> export(
    Uint8List source, {
    required ExportFormat format,
    int quality = 90,
    bool watermark = true,
  });
}

enum ExportFormat { jpeg, png, webp }
