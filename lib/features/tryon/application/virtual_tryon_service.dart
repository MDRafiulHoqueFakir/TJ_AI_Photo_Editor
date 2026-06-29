import 'dart:typed_data';

/// Integration seam for AI virtual clothing try-on (see docs/VIRTUAL_TRYON.md).
///
/// Photorealistic garment swap is a generative diffusion task that runs on a
/// GPU backend (hosted, e.g. Replicate IDM-VTON, or self-hosted) — it cannot run
/// on-device. The UI depends only on this interface; until a real implementation
/// + credentials are wired, [StubTryOnService] reports "not configured" so the
/// feature never pretends to generate.
abstract interface class VirtualTryOnService {
  /// Whether a backend + credentials are configured and reachable.
  Future<bool> isConfigured();

  /// Fit [garmentId] onto the [person] selfie; returns the generated image, or
  /// null on failure / when not configured.
  Future<Uint8List?> tryOn({
    required Uint8List person,
    required String garmentId,
  });
}

/// A corporate/formal outfit option. [referenceAsset] is the front-flat garment
/// image the backend needs; it must be supplied before the catalog is usable.
class Garment {
  const Garment({required this.id, required this.label, this.referenceAsset});
  final String id;
  final String label;
  final String? referenceAsset;
}

/// Default implementation: nothing is wired yet, so the feature stays honest.
class StubTryOnService implements VirtualTryOnService {
  const StubTryOnService();

  @override
  Future<bool> isConfigured() async => false;

  @override
  Future<Uint8List?> tryOn({
    required Uint8List person,
    required String garmentId,
  }) async =>
      null;
}
