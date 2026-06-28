# TJ Photo Editor — Software Requirements Specification (SRS)

**Version:** 1.0
**Date:** 2026-06-28
**Platform:** iOS + Android (Flutter)
**Status:** Approved for development

---

## 1. Purpose & Scope

TJ Photo Editor is a cross-platform mobile photo editing application that combines
premium retouching, AI body/face editing, generative AI, and specialized tools
(passport maker, object removal) into one product. It targets parity with CapCut Pro,
YouCam Perfect, and Samsung AI photo editing, with an **on-device-first** ML strategy
and cloud fallback for heavy generative work.

### 1.1 Goals
- Ship a fast, non-destructive editor with a professional layer/mask system.
- Run detection, segmentation, reshape, beauty, basic inpainting, and upscaling **on-device**.
- Use cloud GPU only for generative features (hair restyle, AI art, generative fill, 4× upscale).
- Monetize via freemium subscription + consumable credits for cloud actions.

### 1.2 Out of scope (v1)
- Video editing (photo only for v1).
- Desktop/web clients.
- Social feed / community features.

---

## 2. Definitions

| Term | Meaning |
|---|---|
| On-device | Inference runs locally via TFLite (Android) / Core ML (iOS). Zero marginal cost. |
| Cloud action | Generative inference on server GPU. Consumes user credits. |
| Recipe | A saved, reusable stack of edits applied to one or many photos (batch). |
| Non-destructive | Original pixels are never overwritten; edits are a stack of nodes. |
| Entitlement | A capability unlocked by subscription (e.g. `pro`, `no_watermark`). |

---

## 3. Functional Requirements

IDs are referenced by the build tracker. **MoSCoW:** M=Must, S=Should, C=Could.

### 3.1 Basic Editing (on-device)
| ID | Requirement | Priority |
|---|---|---|
| FR-BE-01 | Resize to custom width/height in px, with optional aspect-ratio lock. | M |
| FR-BE-02 | Aspect-ratio presets: 1:1, 4:5, 9:16, 16:9, 3:4, plus ID sizes. | M |
| FR-BE-03 | Resolution enhancement (super-resolution) up to 2× on-device, 4× via cloud. | M |
| FR-BE-04 | Brightness, contrast, exposure, highlights, shadows, warmth, saturation sliders with live preview. | M |
| FR-BE-05 | Crop, straighten, rotate, flip, perspective correction. | M |
| FR-BE-06 | Histogram + RGB curves. | S |

### 3.2 AI Body & Face Editing
| ID | Requirement | Priority |
|---|---|---|
| FR-AI-01 | Auto-detect faces (468-pt mesh) and body pose (33 keypoints). | M |
| FR-AI-02 | Body reshape sliders: taller/shorter, thinner/wider, with mesh warp. | M |
| FR-AI-03 | Skin brightening with texture preservation (frequency separation). | M |
| FR-AI-04 | Teeth whitening (auto teeth isolation). | M |
| FR-AI-05 | Hair style change from AI-generated options. | M *(cloud)* |
| FR-AI-06 | Object removal via inpainting; one-tap watermark/text selection. | M *(hybrid)* |

### 3.3 AI Generation
| ID | Requirement | Priority |
|---|---|---|
| FR-GEN-01 | Generative fill / object reposition (select on-device, generate cloud). | M *(cloud)* |
| FR-GEN-02 | Background generation / replacement (segment local, generate cloud or preset). | M |
| FR-GEN-03 | AI art / style transfer: 20+ on-device presets + cloud prompt-based generation. | S |

### 3.4 Specialized Tools
| ID | Requirement | Priority |
|---|---|---|
| FR-SP-01 | Passport/ID maker: auto background removal, standards-compliant crop, print sheet layout. | M |
| FR-SP-02 | Country/standard database (US 2×2", Schengen 35×45, India, etc.) as config. | M |
| FR-SP-03 | Beauty filters: skin smoothing, blemish removal, makeup AR overlays. | M |

### 3.5 Pro Suite (parity)
| ID | Requirement | Priority |
|---|---|---|
| FR-PRO-01 | Layers with blend modes (normal, multiply, screen, overlay, etc.). | M |
| FR-PRO-02 | Masks: brush, gradient, AI-subject mask. | M |
| FR-PRO-03 | Text overlays: fonts, color, outline, shadow, curve. | M |
| FR-PRO-04 | Stickers + downloadable packs. | S |
| FR-PRO-05 | Batch editing via saved recipes. | M |
| FR-PRO-06 | Advanced color grading: HSL, color wheels (lift/gamma/gain), `.cube` LUT import. | S |
| FR-PRO-07 | Noise reduction + HDR/tone-map effects. | S |
| FR-PRO-08 | Export: JPEG/PNG/WEBP/HEIF, quality + DPI control, batch export. | M |

### 3.6 Monetization & Accounts
| ID | Requirement | Priority |
|---|---|---|
| FR-MON-01 | Freemium gate: free tier watermarks exports, limits resolution, shows ads. | M |
| FR-MON-02 | Subscription (monthly/annual/lifetime) via RevenueCat entitlements. | M |
| FR-MON-03 | Consumable credit system for cloud actions; cost shown before run. | M |
| FR-MON-04 | Paywall triggered at export/save for gated effects. | M |
| FR-MON-05 | Restore purchases; trial handling. | M |

---

## 4. Non-Functional Requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-01 | Performance | Live adjustment preview ≥ 30 FPS on mid-tier devices (e.g. SD 7-series, A14). |
| NFR-02 | Latency | On-device tool result < 2s for ≤ 12MP images; cloud action < 15s p95. |
| NFR-03 | Memory | Peak < 600 MB; tiled inference for SR/inpainting on > 4MP images. |
| NFR-04 | Offline | All non-generative features fully functional with no network. |
| NFR-05 | Privacy | Photos never uploaded for on-device actions. Cloud actions upload only the masked region/inputs needed, deleted after processing. GDPR/CCPA compliant. |
| NFR-06 | Reliability | Failed cloud action must not consume a credit; auto-retry once. |
| NFR-07 | Compatibility | iOS 14+, Android 8+ (API 26+). Graceful model downgrade on low-RAM devices. |
| NFR-08 | Security | TLS 1.3 to API; signed upload URLs; no PII in logs. |
| NFR-09 | Accessibility | Dynamic type, VoiceOver/TalkBack labels, min 4.5:1 contrast on controls. |
| NFR-10 | Store compliance | Object/watermark removal positioned for user-owned content only. |

---

## 5. System Architecture (summary)

```
┌──────────────────────────────────────────────┐
│                 Flutter UI                     │
│  (screens, widgets, Riverpod state, go_router) │
└───────────────┬───────────────────────┬───────┘
                │ Dart FFI               │ Method/Event channels
        ┌───────▼────────┐      ┌────────▼─────────┐
        │  Image Engine   │      │   ML Runtime     │
        │  C++ / OpenCV   │      │ TFLite / CoreML  │
        │  GLSL/Metal     │      │ MediaPipe        │
        └────────────────┘      └──────────────────┘
                │
        ┌───────▼────────────────────────────────┐
        │  Cloud Inference API (generative only)   │
        │  Gateway → SDXL/ControlNet on GPU        │
        │  Credits ledger · signed uploads         │
        └─────────────────────────────────────────┘
```

- **State:** Riverpod (providers per feature).
- **Navigation:** go_router (declarative routes).
- **Subscriptions:** RevenueCat SDK.
- **Local storage:** Isar/Hive for recipes, history, settings; secure storage for tokens.

See [PROJECT_FLOW.md](PROJECT_FLOW.md) for screen flows and the build roadmap.

---

## 6. ML Model Inventory

| Task | Model | Runtime | Size | Location |
|---|---|---|---|---|
| Face landmarks | MediaPipe Face Mesh | TFLite/CoreML | ~3 MB | on-device |
| Body pose | MediaPipe Pose | TFLite | ~6 MB | on-device |
| Segmentation | Selfie / DeepLabV3-lite | TFLite | ~5 MB | on-device |
| Subject select | MobileSAM | TFLite/CoreML | ~40 MB | on-device |
| Inpainting | LaMa (quantized) | TFLite/ONNX | ~50 MB | on-device |
| Super-resolution | Real-ESRGAN-lite | TFLite | ~15 MB | on-device |
| Style transfer | Magenta arbitrary | TFLite | ~10 MB | on-device |
| Generative (hair/fill/art) | SDXL + ControlNet | GPU | — | cloud |

---

## 7. Acceptance Criteria (v1 MVP — Phase 1)

- [ ] User can import a photo, adjust brightness/contrast/exposure live, crop/resize, and export.
- [ ] Free export carries watermark; Pro export removes it and allows 4K.
- [ ] Beauty basics (smooth, brighten) apply on-device with before/after compare.
- [ ] Paywall appears at export for gated capability; purchase unlocks via RevenueCat.
- [ ] No crashes on a 12MP image on a 4GB-RAM device.

---

## 8. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Generative quality unachievable on-device | Credit-funded cloud path; set expectations in UI. |
| Store rejection (watermark removal) | Frame as user-owned object/text cleanup; review copy with legal. |
| Cloud GPU cost overruns margin | Credits per generative action; cap free generation at 0. |
| Low-end device OOM | Device-tier detection; tiled inference; downgrade models. |
