# Zenith menu image assets

All active menu assets use transparent backgrounds.

- `zenith-chess-icon.png` — transparent pawn icon used by the separate Zenith Chess window.
- `zenith-wordle-icon.png` — transparent beveled W icon used by Zenith Vocabulary.
- `zenith-reset-icon.png` — transparent reset icon used beside the used-word count, replacing the unsupported text glyph.
- `zenith-logo-monochrome.png` — active white/gray/charcoal repaint used by the menu.
- `zenith-logo-transparent.png` — archived purple source cleaned from the user-supplied `download.png`.
- `icon-home.png` — active Home navigation icon.
- `icon-doc.png` — active folded-paper Announcements navigation icon.
- `icon-people.png` — archived previous People icon; no longer rendered by the menu.

The Key System PNG bytes are embedded inside `../SCPMainMenu.lua`. `ZenithChess.txt` caches the chess icon, while `ZenithVocabulary.txt` bundles the W and reset PNGs and registers them with `getcustomasset`/`getsynasset`; each has a code/text fallback when local assets are unavailable. Standard Roblox Studio requires uploaded `rbxassetid` values for exact PNG rendering; see `../README.md`.

There is intentionally no orientation asset: the separate square/cube control was removed, and users rotate both 3D menu planes by dragging directly on either panel.
