import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'ml_service.dart';

/// Platform-channel implementation of [MlService]. The native side (Android:
/// MediaPipe + TFLite; iOS: Core ML + Vision) registers a MethodChannel named
/// [channelName] and implements the methods below. See
/// docs/NATIVE_ML_BRIDGE.md for the contract and native handler stubs.
class ChannelMlService implements MlService {
  const ChannelMlService();

  static const channelName = 'tj_photo_editor/ml';
  static const _channel = MethodChannel(channelName);

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false; // native handler not registered (e.g. running before Phase 2)
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<List<FaceResult>> detectFaces(Uint8List image) async {
    try {
      final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'detectFaces',
        {'image': image},
      );
      if (raw == null) return const [];
      return raw.map(_faceFromMap).toList();
    } on PlatformException {
      return const [];
    }
  }

  @override
  Future<Uint8List?> segmentSubject(Uint8List image) async {
    try {
      return await _channel.invokeMethod<Uint8List>('segmentSubject', {'image': image});
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<Uint8List?> inpaint(Uint8List image, Uint8List mask) async {
    try {
      return await _channel.invokeMethod<Uint8List>(
        'inpaint',
        {'image': image, 'mask': mask},
      );
    } on PlatformException {
      return null;
    }
  }

  FaceResult _faceFromMap(Map<dynamic, dynamic> m) {
    final b = (m['bounds'] as List).cast<num>();
    final pts = (m['landmarks'] as List).cast<List<dynamic>>();
    return FaceResult(
      bounds: Rect(b[0].toDouble(), b[1].toDouble(), b[2].toDouble(), b[3].toDouble()),
      landmarks: [
        for (final p in pts) Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
    );
  }
}
