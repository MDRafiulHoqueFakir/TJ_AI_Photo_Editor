# Native ML Bridge — Phase 2 Integration Contract

The Dart side ([`ChannelMlService`](../lib/core/services/channel_ml_service.dart))
talks to on-device ML over a single `MethodChannel`. This document is the
contract the Android and iOS native code must implement.

- **Channel name:** `tj_photo_editor/ml`
- **Image payload:** raw encoded bytes (`Uint8List`, JPEG/PNG) in/out.
- **Graceful degradation:** if the channel is unregistered, Dart catches
  `MissingPluginException`/`PlatformException` → features show "coming soon".

## Methods

| Method | Args | Returns | Native impl |
|---|---|---|---|
| `isAvailable` | — | `bool` | report model load + delegate availability |
| `detectFaces` | `{image}` | `List<{bounds:[x,y,w,h], landmarks:[[x,y],…]}>` | MediaPipe Face Mesh / Vision |
| `segmentSubject` | `{image}` | `Uint8List` mask (grayscale; ≥0.5 = subject) | Selfie Seg / DeepLab |
| `inpaint` | `{image, mask}` | `Uint8List` result | LaMa (quantized) |

## Android (`MainActivity.kt` / FlutterPlugin)
```kotlin
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tj_photo_editor/ml")
  .setMethodCallHandler { call, result ->
    when (call.method) {
      "isAvailable" -> result.success(MlEngine.ready)
      "detectFaces" -> result.success(MlEngine.detectFaces(call.argument("image")))
      "segmentSubject" -> result.success(MlEngine.segment(call.argument("image")))
      "inpaint" -> result.success(MlEngine.inpaint(call.argument("image"), call.argument("mask")))
      else -> result.notImplemented()
    }
  }
```
- TFLite with **GPU delegate** (fallback NNAPI → CPU). Run heavy ops off the
  platform thread; return via `runOnUiThread { result.success(...) }`.
- Models bundled under `android/app/src/main/assets/ml/` (see `pubspec.yaml`).

## iOS (`AppDelegate.swift`)
```swift
let ch = FlutterMethodChannel(name: "tj_photo_editor/ml",
                              binaryMessenger: controller.binaryMessenger)
ch.setMethodCallHandler { call, result in
  switch call.method {
  case "isAvailable": result(MLEngine.ready)
  case "detectFaces": result(MLEngine.detectFaces(call.arguments))
  // …segmentSubject, inpaint
  default: result(FlutterMethodNotImplemented)
  }
}
```
- **Core ML** models target the Neural Engine; use the **Vision** framework for
  face landmarks. Convert TFLite → Core ML via `coremltools` at build time.

## Threading & memory
- Tile large images (512×512 + overlap) for SR/inpainting to bound RAM (NFR-03).
- Never block the Flutter UI thread; the Dart calls are already `async`.
