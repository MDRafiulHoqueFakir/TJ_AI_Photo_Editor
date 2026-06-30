# Generative AI setup (Replicate)

The generative features (Background Remover, and — once wired — hair restyle,
generative fill, background generate) run on **Replicate** GPU models. The
browser can't call Replicate directly (CORS + the token must stay secret), so
the local Node server (`tools/serve.js`, launched by `run_web.bat`) proxies the
calls and adds your token server-side.

## One-time setup
1. Get a token at https://replicate.com/account/api-tokens (starts with `r8_`).
2. Create a file named **`.replicate-token`** in the project root
   (`C:\Rafiul\App Maker\TJ Photo Editor\.replicate-token`) containing just the
   token, e.g.:
   ```
   r8_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
   (Or set the `REPLICATE_API_TOKEN` environment variable instead.)
3. Launch the app with **`run_web.bat`** (the proxy lives in that server).

That's it — **Background Remover** (Quick Tools) will now work. The file is
git-ignored so your token is never committed.

## How it works
- App → `POST /api/replicate { model, input }` (same origin, no CORS).
- `serve.js` adds `Authorization: Bearer <token>` and calls
  `https://api.replicate.com/v1/models/<owner>/<name>/predictions` with
  `Prefer: wait` (blocks until done, no polling), then returns the output.
- `App → GET /api/config` reports `{ hasToken }` so the UI can show setup help.

## Models in use / to add
| Feature | Replicate model | Notes |
|---|---|---|
| Background Remover | `cjwbw/rembg` | image in → cutout out. Working. |
| Hair restyle | (choose a hair model) | needs a hair-edit model + maybe a prompt |
| Generative fill | `stability-ai/stable-diffusion-inpainting` | needs image + mask + prompt |
| Background generate | SDXL / bg model | needs a prompt |

Hair / fill / bg-generate need prompts or masks, so they require a bit more UI;
the proxy + service already support any model — wiring is per-feature.
