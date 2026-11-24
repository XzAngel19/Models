---
name: roblox-ui-asset-painter
description: Repaint, extract, alpha-clean, and embed screenshot-derived PNG assets for code-built Roblox interfaces using Pillow and Luau.
---

# Roblox UI Asset Painter

Use this skill when a Roblox GUI must reproduce a small visual asset exactly instead of approximating it with stacked Frames.

## Workflow

1. Read the reference image at native resolution.
2. Crop the smallest rectangle containing the requested asset.
3. Preserve native size when the target will render near 1:1; avoid AI upscaling for text or axis labels.
4. Remove only the known background:
   - use alpha 0 for near-black neutral pixels when extracting from a black sky;
   - retain colored pixels such as red/green/blue axes;
   - retain dark text inside lighter faces.
5. For recoloring, preserve the source alpha channel and map semantic source colors to a deliberate palette.
6. Save optimized RGBA PNGs under the feature's `assets/` directory.
7. Verify dimensions, alpha statistics, PNG decoding, and SHA-256.
8. Base64-embed active assets in the single Luau file for executors supporting `writefile` and `getcustomasset`.
9. Keep a code-drawn fallback for standard Studio clients.
10. Never put an opaque screenshot rectangle behind an asset intended to float over the game.

## ZNTH palette

- paper white: `(245, 246, 248)`
- silver: `(215, 219, 225)`
- medium gray: `(145, 151, 160)`
- charcoal: `(42, 46, 52)`
- panel black: `(5, 5, 6)`

## Verification checklist

- [ ] PNG has RGBA mode and a non-empty alpha channel.
- [ ] No unwanted screenshot background remains.
- [ ] Small embedded labels remain legible at the actual Roblox render size.
- [ ] Embedded base64 decodes byte-for-byte to the source PNG.
- [ ] Studio fallback does not show a large opaque rectangle.
- [ ] Active Luau contains no obsolete accent colors.
