import 'dart:typed_data';

/// On-device ML facade. Phase 1 ships interface + no-op stubs so the UI and
/// flows compile and can be wired; Phase 2 backs these with MediaPipe / TFLite
/// (Android) and Core ML (iOS) over platform channels.
abstract interface class MlService {
  Future<bool> isAvailable();

  /// Returns detected face bounding boxes + 468-pt mesh (Phase 2).
  Future<List<FaceResult>> detectFaces(Uint8List image);

  /// Returns a soft alpha mask isolating the subject (selfie segmentation).
  Future<Uint8List?> segmentSubject(Uint8List image);

  /// Inpaint the masked region (LaMa on-device for small/medium regions).
  Future<Uint8List?> inpaint(Uint8List image, Uint8List mask);
}

class FaceResult {
  const FaceResult({required this.bounds, required this.landmarks});
  final Rect bounds;
  final List<Offset> landmarks;
}

/// Minimal geometry types to keep this layer Flutter-agnostic.
class Rect {
  const Rect(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
}

class Offset {
  const Offset(this.dx, this.dy);
  final double dx, dy;
}

/// Phase-1 stub: reports unavailable so the UI shows "coming soon" states
/// instead of crashing. Swap for the real impl in Phase 2.
class StubMlService implements MlService {
  const StubMlService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<FaceResult>> detectFaces(Uint8List image) async => const [];

  @override
  Future<Uint8List?> segmentSubject(Uint8List image) async => null;

  @override
  Future<Uint8List?> inpaint(Uint8List image, Uint8List mask) async => null;
}
