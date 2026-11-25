# Zenith menu image assets

All active menu assets use transparent backgrounds.

- `zenith-chess-icon.png` — transparent pawn icon used by the separate Zenith Chess window.
- `zenith-wordle-icon.png` — transparent beveled W icon used by Zenith Vocabulary.
- `zenith-saved-icon.png` — transparent silver bookmark used beside the saved/used-word count, replacing the unsupported text glyph.
- `zenith-settings-icon.png` — transparent settings control supplied for the Vocabulary options panel.
- `zenith-logo-monochrome.png` — active white/gray/charcoal repaint used by the menu.
- `zenith-logo-transparent.png` — archived purple source cleaned from the user-supplied `download.png`.
- `icon-home.png` — active Home navigation icon.
- `icon-doc.png` — active folded-paper Announcements navigation icon.
- `icon-people.png` — archived previous People icon; no longer rendered by the menu.

The Key System PNG bytes are embedded inside `../SCPMainMenu.lua`. `ZenithChess.txt` caches the chess icon, while `ZenithVocabulary.txt` bundles the W, bookmark, and settings PNGs and registers them with `getcustomasset`/`getsynasset`. The W has a plain-text fallback, the settings control has a code-drawn sliders fallback, and the bookmark hides cleanly instead of showing a broken letter when local assets are unavailable. Standard Roblox Studio requires uploaded `rbxassetid` values for exact PNG rendering; see `../README.md`.

There is intentionally no orientation asset: the separate square/cube control was removed, and users rotate both 3D menu planes by dragging directly on either panel.
