# ZNTH menu image assets

All active menu assets use transparent backgrounds.

- `zenith-logo-monochrome.png` — active white/gray/charcoal repaint used by the menu.
- `zenith-logo-transparent.png` — archived purple source cleaned from the user-supplied `download.png`.
- `icon-home.png` — active Home navigation icon.
- `icon-doc.png` — active folded-paper Announcements navigation icon.
- `icon-people.png` — archived previous People icon; no longer rendered by the menu.

The active PNG bytes are embedded inside `../SCPMainMenu.lua`, so compatible executors need no sidecar files. Standard Roblox Studio requires uploaded `rbxassetid` values for the exact PNGs; see `../README.md`.

There is intentionally no orientation asset: the separate square/cube control was removed, and users rotate both 3D menu planes by dragging directly on either panel.
