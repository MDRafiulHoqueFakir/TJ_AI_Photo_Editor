# Professional Attire (AI Virtual Try-On) — Design & Integration Spec

**Status:** specified, not yet functional — needs a generative backend (below).
**Goal:** user uploads a selfie → picks a corporate/formal outfit → the app fits
that garment to their detected body, photorealistically → preview → download.

> **Positioning & compliance (read first).** Many countries legally require
> official passport/visa photos to be **unaltered** — digitally changing attire
> can get a photo rejected. This feature is intended for **corporate / LinkedIn /
> CV / ID-card headshots**, not for deceiving passport authorities. The UI must
> label it accordingly and must not claim outputs are "undetectable".

---

## 1. Why this needs a backend
Realistic garment swap is a **generative diffusion** task (pose-aware warping +
inpainting + relighting). It does not run on-device or in pure Dart. It requires
a GPU running a virtual try-on model. Recommended models:

| Model | Notes |
|---|---|
| **IDM-VTON** | Strong identity + garment preservation; available on Replicate. |
| **OOTDiffusion** | Good full-outfit results; open weights, self-hostable. |
| **TryOnDiffusion** | High quality; heavier to host. |

Two delivery options:
- **Hosted API (fastest):** Replicate / fal.ai endpoint. App sends images, gets a
  result URL. You provide an API token; cost is per generation.
- **Self-hosted:** your GPU server (Triton/ComfyUI) exposing the contract in §3.

---

## 2. App-side flow (what TJ builds)
```
Professional Attire
  └─ Pick selfie (front-facing, plain background recommended)
        └─ Choose outfit from the garment catalog (navy suit, black blazer, …)
              └─ Tap "Fit outfit"
                    ├─ check backend configured? ── no ──► explain + link to setup
                    └─ yes ──► upload selfie + garment ref ──► poll job
                                  └─ success ──► preview ──► Download / "Try another"
```
- **Garment catalog:** each entry = a reference garment image (front-flat) +
  label. These reference images must be provided (licensed assets or generated).
- **On-device pre-steps (already available):** selfie segmentation/pose can use
  the existing `MlService` bridge to validate framing before sending.

---

## 3. Backend contract (`VirtualTryOnService`)
Single async call; the client handles upload + polling.

```
POST /tryon
  body: { person: <image>, garment: <image|garmentId>, options?: {...} }
  → 202 { jobId }
GET /tryon/{jobId}
  → { status: "processing" | "succeeded" | "failed", resultUrl?, error? }
```
Dart seam: `lib/features/tryon/application/virtual_tryon_service.dart`
- `Future<bool> isConfigured()`
- `Future<Uint8List?> tryOn({required Uint8List person, required String garmentId})`

A `ReplicateTryOnService` (or `SelfHostedTryOnService`) implements this; the UI
depends only on the interface, with a `StubTryOnService` (default) reporting
"not configured" so nothing pretends to work.

---

## 4. To switch it on
1. Choose backend (hosted token **or** self-hosted endpoint).
2. Provide garment reference images for the catalog.
3. Implement the chosen `VirtualTryOnService` (HTTP client to §3).
4. Add credentials via secure config (never commit tokens).

Until then the feature stays behind an honest "needs AI service" state — no fake
generation.
