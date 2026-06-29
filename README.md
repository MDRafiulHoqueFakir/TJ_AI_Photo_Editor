# TJ Photo Editor

AI-powered cross-platform (iOS + Android + **Web**) photo editing app built with Flutter.

> Combines premium retouching, AI body/face editing, generative AI, and
> specialized tools (passport maker, object removal) with an **on-device-first**
> ML strategy and cloud fallback for heavy generative work.

## Documentation
- [Requirements (SRS)](docs/REQUIREMENTS.md)
- [Project Flow & Roadmap](docs/PROJECT_FLOW.md)

## Status — MVP complete (web + mobile), verified

Working end-to-end:
- App shell: onboarding → home → editor navigation (`go_router`), Riverpod, dark theme
- **Non-destructive edit stack** with undo/redo, hold-to-compare
- **Live GPU tonal editing** (brightness/contrast/exposure/saturation/warmth/vignette)
  via a cross-platform `ColorFilter` color-matrix — identical on web + mobile
- **Style filters** (Vivid, Mono, Noir, Sepia, Warm, Cool, Fade, Vintage) with live
  thumbnails — GPU color matrices composed under the tonal layer, cross-platform
- **Text overlays** — add/drag/style text on the photo (size, color, bold),
  baked into the export at full resolution
- **Emoji stickers** — drop, drag, and resize emoji stickers (no bundled assets)
- **Frames & borders** — White, Black, Soft, Film, Polaroid; live preview, baked into export
- **Tap-to-heal** spot retouch — tap blemishes to remove them (each tap is undoable)
- **Collage maker** — 5 layouts, per-cell photo picking, spacing & background, export
- Crop / rotate / flip, skin retouch, body reshape (CPU engine; FFI/GPU swap-ready)
- **Export & download** the result (web download / native file save)
- **Passport / ID maker** — crop to exact standard dimensions + printable 6×4" sheet
- **Upscale 2×** (cubic) — real, on-device
- Freemium gating: watermark on free export, paywall, credit-badged tiles
- Consistent "coming soon" UX for features awaiting ML models / cloud backend

Intentionally pending (need bundled ML models or a cloud backend): on-device
face/body detection, segmentation, object removal, super-res; cloud generative
(hair, AI art, generative fill); auto background removal. See
[PROJECT_FLOW.md](docs/PROJECT_FLOW.md) and [NATIVE_ML_BRIDGE.md](docs/NATIVE_ML_BRIDGE.md).

Verified on Flutter 3.44.4: `flutter analyze` clean, tests pass, `flutter build web`
succeeds, app runs in-browser with no console errors.

## ▶️ Open the app (Windows — easiest)
**Double-click `run_web.bat`** in this folder. The first launch compiles for about
a minute, then Chrome opens automatically with the app. Keep the console window
open while you use it; close it to stop.

If a terminal is preferred, `flutter` is now on your PATH, so simply:
```bash
flutter run -d chrome
```
(`serve_web.bat` builds an optimized release and serves it at http://localhost:8080.)

## Prerequisites
- **Flutter SDK 3.22+** (installed at `%USERPROFILE%\flutter`; on PATH)
- Android Studio (Android) and/or Xcode on macOS (iOS) for mobile builds

## First-time setup

This repo contains `lib/`, `pubspec.yaml`, and docs. Generate the native
platform folders (`android/`, `ios/`) without overwriting the source:

```bash
cd "C:/Rafiul/App Maker/TJ Photo Editor"
flutter create . --org com.tj --project-name tj_photo_editor --platforms=android,ios
flutter pub get
flutter analyze
flutter run
```

`flutter create .` keeps existing `lib/` and `pubspec.yaml` and only adds the
missing runner/platform scaffolding.

### Run on web
The same codebase runs as a web app (`android/`, `ios/`, and `web/` are all
generated):

```bash
flutter run -d chrome          # live dev server + hot reload
flutter build web              # production build → build/web/
```

**Cross-platform rendering note:** Flutter web does not support runtime fragment
shaders, so the live tonal pipeline uses a GPU `ColorFilter` color-matrix
(`core/services/color_pipeline/`) which is hardware-accelerated on web *and*
mobile and renders identically on both. The GLSL shader in `shaders/` remains as
a mobile-only advanced-effects hook.

## Architecture
Feature-first clean architecture. UI in Flutter; the Phase-1 image engine is
pure Dart (`core/services/dart_image_engine.dart`) behind the `ImageEngine`
interface — Phase 2 swaps in a C++/OpenCV + GPU-shader engine via `dart:ffi`
without changing any UI code. ML lives behind `MlService` (stubbed in Phase 1,
MediaPipe/TFLite + Core ML in Phase 2).

```
lib/
├── core/            # theme, routing, constants, service interfaces
├── features/        # onboarding, home, editor, ai_studio, tools, passport, subscription
└── shared/          # reusable widgets
```

## Monetization
Freemium + subscription (RevenueCat) + consumable credits for cloud actions.
Plans: $7.99/mo · $39.99/yr · $59.99 lifetime. See [REQUIREMENTS.md](docs/REQUIREMENTS.md) §3.6.
