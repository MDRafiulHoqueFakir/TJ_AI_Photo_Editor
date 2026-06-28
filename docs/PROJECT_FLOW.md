# TJ Photo Editor — Project Flow & Roadmap

**Version:** 1.0 · **Date:** 2026-06-28

This document describes (1) the user navigation flow, (2) the editor data flow,
(3) the cloud action flow, and (4) the phased build roadmap.

---

## 1. App Navigation Flow

```
                          ┌──────────────┐
                          │  Onboarding   │  (first launch only)
                          │  3 swipes →   │
                          │  permission   │
                          └──────┬───────┘
                                 │
                          ┌──────▼───────┐
                          │     HOME      │
                          └──┬───┬───┬───┬┘
            ┌────────────────┘   │   │   └────────────────┐
            │             ┌──────┘   └──────┐             │
      ┌─────▼─────┐ ┌─────▼─────┐    ┌──────▼─────┐ ┌─────▼──────┐
      │ Edit Photo │ │ AI Studio │    │ Quick Tools│ │  Profile   │
      └─────┬─────┘ └─────┬─────┘    └──────┬─────┘ └─────┬──────┘
            │             │                 │             │
       ┌────▼────┐   ┌────▼─────┐     ┌─────▼──────┐ ┌────▼─────┐
       │ Picker  │   │ Hair /   │     │ Passport / │ │ Subs ·   │
       │         │   │ AI Art / │     │ Object Rm /│ │ Credits ·│
       └────┬────┘   │ GenFill  │     │ Upscale /  │ │ Recipes ·│
            │        └────┬─────┘     │ BG Remove  │ │ Settings │
       ┌────▼─────────────▼───────────────▼────────┐└──────────┘
       │              EDITOR CANVAS                  │
       └─────────────────────────────────────────────┘
```

---

## 2. Editor Screen Layout

```
┌─────────────────────────────────────────────┐
│  ← Back        TJ Editor      Undo  Redo  ⤓   │  top bar
├─────────────────────────────────────────────┤
│                                               │
│              CANVAS (pinch/pan)               │  live GPU preview
│            [layer / mask badges]              │
│                                               │
├─────────────────────────────────────────────┤
│   ◀  contextual control (slider / brush)  ▶   │  changes per tool
│            [ hold to Compare ]                │
├─────────────────────────────────────────────┤
│ Adjust│Retouch│Body│AI│Filter│Text│Layer│... │  scrollable tool rail
└─────────────────────────────────────────────┘
```

**Interaction rules**
1. Every edit is a **non-destructive node** pushed to the edit stack.
2. **Hold-to-Compare** reveals the original on any tool.
3. **Auto** button first; **Manual** expands sliders (progressive disclosure).
4. Cloud tools show **credit cost before running**, with progress + cancel.
5. Paywall is deferred to **Save/Export**, not tool entry.

---

## 3. Editor Data Flow (non-destructive pipeline)

```
Import ──► Decode (libvips) ──► Base Layer
                                   │
                                   ▼
                            ┌─────────────┐
   user picks tool ───────► │ Edit Stack   │ ◄── undo/redo history
                            │ [node,node…] │
                            └──────┬──────┘
                                   ▼
                     Render graph compiled to GPU
                     (shaders + layer compositing)
                                   │
                          ┌────────┴────────┐
                          ▼                 ▼
                   Live preview        Export render
                   (downscaled)        (full-res, format)
```

- The **edit stack** is the single source of truth (serializable → enables Recipes & batch).
- Preview renders a downscaled proxy for FPS; export re-runs the same graph at full res.

---

## 4. Cloud Action Flow (generative, credit-gated)

```
User taps generative tool
        │
        ▼
Check entitlement + credit balance ──► insufficient ──► Paywall / Buy credits
        │ ok
        ▼
Show cost + confirm
        │
        ▼
Prepare minimal payload (mask + region, not full library)
        │
        ▼
Signed upload ──► API gateway ──► GPU inference (SDXL/ControlNet)
        │
        ▼
Poll/stream result ──► success ──► debit credit ──► composite into editor
        │
        └─ failure ──► NO debit ──► auto-retry once ──► else surface error
```

---

## 5. Build Roadmap (phased, de-risked)

### Phase 1 — MVP foundation (all on-device, $0 marginal cost)
- App shell: onboarding, home, navigation, theme. **[scaffolded]**
- Image import/export pipeline + watermark gate.
- Basic editing: adjust sliders, crop/resize/rotate.
- Beauty basics: smooth skin, brighten.
- Paywall + RevenueCat integration.
- **Exit criteria:** acceptance tests in REQUIREMENTS §7 pass.

### Phase 2 — On-device AI (the differentiator)  *(in progress)*
- [x] Editor ops wired in Dart engine: crop/orient, skin smooth, body reshape, background replace.
- [x] Editor panels live: Retouch, Body, Crop (replacing placeholders).
- [x] Native ML bridge contract + `ChannelMlService` (MethodChannel `tj_photo_editor/ml`). See [NATIVE_ML_BRIDGE.md](NATIVE_ML_BRIDGE.md).
- [ ] Native MediaPipe face/pose/segmentation handlers (Android/iOS).
- [ ] Mesh/liquify GPU warp replacing the interim scale-based reshape.
- [ ] Teeth whitening, blemish removal (landmark-anchored).
- [ ] Passport auto-crop using detected face box + segmentation BG removal.
- [ ] LaMa object removal + one-tap watermark/text select.

### Phase 3 — Cloud generative (credit-funded)
- API gateway + credits ledger + signed uploads.
- Hair restyle, generative fill/reposition, AI art prompt, 4× upscale.

### Phase 4 — Pro suite depth
- Layers/masks/blend modes, text engine, stickers.
- Batch recipes, LUT import, color wheels, noise/HDR.

---

## 6. Current Repository Structure

```
TJ Photo Editor/
├── docs/
│   ├── REQUIREMENTS.md        # SRS
│   └── PROJECT_FLOW.md        # this file
├── pubspec.yaml               # Flutter deps
├── analysis_options.yaml      # lint rules
├── README.md                  # setup & run
└── lib/
    ├── main.dart              # entry point
    ├── app.dart               # MaterialApp + router
    ├── core/
    │   ├── theme/             # colors, theme
    │   ├── routing/           # go_router config
    │   ├── constants/         # app constants
    │   └── services/          # ML + image engine interfaces
    ├── features/
    │   ├── onboarding/
    │   ├── home/
    │   ├── editor/            # canvas, tool rail, edit-stack models
    │   ├── ai_studio/
    │   ├── tools/             # quick tools
    │   ├── passport/
    │   └── subscription/      # paywall
    └── shared/                # reusable widgets
```

---

## 7. Definition of Done (per feature)
- Compiles with no analyzer warnings (`flutter analyze`).
- Works offline if non-generative.
- Non-destructive (pushes to edit stack, undoable).
- Has before/after compare where it alters pixels.
- Free vs Pro gating wired to entitlement service.
