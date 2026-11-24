# SCP Main Menu — Exact Replication Plan (Luau, Client-Sided)

> Reference: user screenshot (1223×813, Roblox Studio). Goal: pixel-faithful recreation of the supplied menu as a **single executable Luau file** (LocalScript / executor `loadstring`). **Status: implemented** in `SCP-Main-Menu/SCPMainMenu.lua` after the user supplied the final customization spec.

---

## 1. What we're building

A client-sided `ScreenGui` with two floating panels (left nav/news, right profile) over a dark 3D scene (studded baseplate + grey dummy). The GUI itself is 2D; the 3D background is the game world, not part of the GUI.

**Deliverable:** `SCP-Main-Menu/SCPMainMenu.lua` — one 1,500+ line file, zero `require`, zero server scripts. PNG artwork is embedded for compatible executors and has code-drawn Studio fallbacks.

**Execution:**
- Studio: `StarterGui → LocalScript`, paste file, Play Solo.
- Executor: `loadstring(game:HttpGet("<raw-url>"))()` or paste file directly.

---

## 2. Reference breakdown (from screenshot)

### 2.1 Left panel (~x 55–400, y 205–690)
| # | Element | Spec |
|---|---------|------|
| L1 | Zenith key "Z" | Orange `Z` glyph, ~20px, top-left, outside panel edge (user-requested replacement for Q) |
| L2 | Home icon (selected) | Orange square ~45×35, black house glyph, `BackgroundColor3` ≈ `Color3.fromRGB(255,140,0)` |
| L3 | Friends icon | White two-person glyph, unselected |
| L4 | News/doc icon | White page glyph, unselected |
| L5 | Divider | 1px vertical grey line |
| L6 | "E" | Orange letter, ~18px |
| L7 | "Home" | White text, ~20px, Gotham |
| L8 | Divider | 1px vertical grey line |
| L9 | **Continue** bar | Full-width black bar, h≈55, centered white text ~28px, 1px white/grey top+bottom border |
| L10 | **News** header bar | Same style as L9 |
| L11 | Current-game image | Runtime `rbxthumb://type=GameThumbnail&id=<PlaceId>&w=768&h=432`, cropped to ~335×126 |
| L12 | Current-game title | Runtime `MarketplaceService:GetProductInfo(game.PlaceId)`, orange, bold, truncated safely |
| L13 | Current-game description | Product description with a local fallback, light grey, wrapped |
| L14 | "16/03/2019" | Orange, ~12px, retained from the reference |
| L15 | **Updates** bar | Same style as L9 |
| L16 | Keybind row | `F / Updates`, `X / Soon`, `C / Soon`, with orange keys and thin dividers |

### 2.2 Right panel (~x 895–1230, y 270–680)
| # | Element | Spec |
|---|---------|------|
| R1 | "Clearance" / "Division" | White ~16px, each with thin underline (1px frame) |
| R2 | "ZNTH" | Bold white ~37px below Clearance (replaces L1) |
| R3 | Zenith division logo | User-supplied purple logo, white background removed; transparent PNG/fallback at ~96px |
| R4 | Divider | 1px horizontal grey line |
| R5 | "Standard" + live 12-hour remaining counter | Starts as `12 Hours - Remaining`, then updates every second |
| R6 | "Time Played" / "0d 0h 0m" | Real session timer, displayed in the reference format |
| R7 | Divider | 1px horizontal grey line |
| R8 | "69" + "Active / users" | User-requested count and stacked label |
| R9 | Divider | 1px horizontal grey line |
| R10 | Local avatar + Roblox username | Runtime `GetUserThumbnailAsync` + `LocalPlayer.Name` |

### 2.3 Center / background
- "Dummy" nametag, grey R6 character, baseplate, starry sky, and Studio orientation widget are **not created by the menu**; they belong to the reference's game-world scene.
- The client menu overlays whichever current Roblox experience executes it.

### 2.4 Visual style
- Panels: near-black `Color3.fromRGB(10,10,10)` with slight transparency (`BackgroundTransparency ≈ 0.05–0.15`), 1px light borders.
- Accent orange: `Color3.fromRGB(255,140,0)` (tune to `#FF8C00`).
- Text: white `Color3.fromRGB(255,255,255)`, secondary `Color3.fromRGB(200,200,200)`.
- Font: `Enum.Font.Gotham` / `GothamBold` / `GothamMedium` (closest Roblox match to screenshot's geometric sans).
- The reference panels are photographed with slight inward perspective; this deliverable keeps them as a stable flat `ScreenGui` so they remain readable and clickable over any current game.

---

## 3. Layout spec (pixel-exact)

Reference canvas: 1223×813 (the supplied file's exact dimensions). Build with offset-based panel internals, edge anchors, and paired `UIScale` objects driven by the current camera viewport.

```
ScreenGui (IgnoreGuiInset=true, ResetOnSpawn=false, DisplayOrder=10)
├── LeftPanel (Frame, AnchorPoint 0,0.5, Pos 55,0.5, Size 345×~485)
│   ├── IconRow (Frame, h=40)
│   │   ├── ZenithKey (TextLabel "Z", orange)
│   │   ├── HomeBtn (TextButton, orange bg, house ImageLabel)
│   │   ├── FriendsBtn (TextButton, people ImageLabel)
│   │   ├── NewsBtn (TextButton, doc ImageLabel)
│   │   ├── VDivider1 (Frame 1px)
│   │   ├── ELabel (TextLabel "E", orange)
│   │   ├── HomeLabel (TextLabel "Home", white)
│   │   └── VDivider2 (Frame 1px)
│   ├── ContinueBtn (TextButton, h=55, "Continue")
│   ├── NewsHeader (TextButton/Frame, h=55, "News")
│   ├── GameThumbnail (ImageLabel, 335×126, runtime PlaceId thumbnail)
│   ├── NewsBody (Frame)
│   │   ├── GameTitleLabel (runtime game name, orange bold)
│   │   ├── GameDescriptionLabel (runtime description, wrapped)
│   │   └── DateLabel ("16/03/2019", orange)
│   ├── UpdatesBtn (TextButton, h=55, "Updates")
│   └── KeybindRow (Frame, h=34)
│       ├── FLabel ("F", orange) + UpdatesLabel + VDivider
│       ├── XLabel ("X", orange) + SoonLabel + VDivider
│       └── CLabel ("C", orange) + SoonLabel
└── RightPanel (Frame, AnchorPoint 1,0.5, Pos -31,0.563, Size 323×404)
    ├── HeaderRow: ClearanceLabel+Underline | DivisionLabel+Underline
    ├── StatsRow: ZNTHLabel (bold 37px) | ZenithLogo (transparent PNG/fallback 96px)
    ├── HDivider
    ├── StandardLabel + live RemainingValue
    ├── TimeLabel + live TimeValue ("0d 0h 0m")
    ├── HDivider
    ├── ActiveRow: CountLabel ("69") + StackedLabel ("Active"/"users")
    ├── HDivider
    └── PlayerRow: runtime AvatarThumb + LocalPlayer.Name
```

All panels: `BackgroundColor3 = Color3.fromRGB(10,10,10)`, `BackgroundTransparency = 0.08`, `BorderSizePixel = 0`, `UIStroke` 1px `Color3.fromRGB(120,120,120)` transparency 0.3. No `UICorner` (screenshot is square-cornered).

---

## 4. Asset list (must be uploaded as `rbxassetid://`)

| Asset | Used in | Status |
|-------|---------|--------|
| Zenith division logo (transparent PNG) | R3 | Generated from the supplied `download.png`; saved at `assets/zenith-logo-transparent.png` and embedded in the Luau file |
| Current-game thumbnail | L11 | Runtime `rbxthumb://type=GameThumbnail` from `game.PlaceId`; no upload needed |
| House icon | L2 | Transparent PNG generated + embedded; code-drawn Studio fallback |
| People icon | L3 | Transparent PNG generated + embedded; code-drawn Studio fallback |
| Document icon | L4 | Transparent PNG generated + embedded; code-drawn Studio fallback |
| Avatar thumbnail | R10 | Runtime `GetUserThumbnailAsync`; no upload needed |

**Runtime policy:** executors with `writefile` + `getcustomasset` decode the embedded PNGs automatically. Standard Studio security does not expose those APIs, so the UI uses matching vector fallbacks unless the transparent PNG is uploaded and its ID is entered in `Config.Assets`.

---

## 5. Code architecture (single file)

```
SCPMainMenu.lua (1,500+ lines)
├── Services + Config (1223×813 reference, colors, data, asset overrides)
├── Embedded transparent PNG payloads + safe executor asset resolver
├── Helpers: create(), connect(), tween(), addStroke(), makePanelBar(), icon builders
├── State/API: Menu = { connections, callbacks, references, positions, open, ... }
├── buildLeftPanel()  → Z/nav, bars, runtime game content, Updates, F/X/C hints
├── buildRightPanel() → ZNTH/logo, real countdown, time played, 69 active users, player
├── Runtime binding   → GetProductInfo, GameThumbnail, LocalPlayer name/headshot
├── Input/animation  → E/Z/F/X/C, hover/press feedback, two-sided open/close
├── Responsive scale → exact 1223×813 baseline, clamped for other viewport sizes
└── Cleanup          → idempotent re-execution and full connection teardown
```

**Interactivity:**
- `Continue` closes the two panels by default; a caller can override `Menu.callbacks.Continue`.
- `News` and `Updates` retain hover/press feedback and expose callbacks.
- Icon buttons switch the orange selected state.
- `E` toggles; `Z` opens/selects Home; `F`, `X`, and `C` pulse their visible hints.
- Hover is 0.14 seconds; panel entrance/exit is 0.42 seconds with Quint easing.

---

## 6. Implemented phases

1. **Skeleton:** `ScreenGui`, edge-anchored roots, exact reference coordinates, lines and strokes.
2. **Left panel:** PNG/vector nav icons, dynamic game thumbnail/title/description, Updates and key hints.
3. **Right panel:** ZNTH clearance, transparent supplied logo, account timer, played timer, active users, local profile.
4. **Data + input:** safe client APIs, persistent-in-session countdown attribute, keyboard controls and callbacks.
5. **Polish:** embedded assets, responsive scaling, entrance animation, idempotent cleanup and source validation.

---

## 7. Resolved decisions from the final user specification

1. **Branding:** replace Q with Z, L1 with ZNTH, and the SCP mark with the supplied Zenith logo.
2. **Scope:** GUI only; the baseplate, dummy, sky, and Studio orientation widget remain the current game's world.
3. **Delivery:** one executable `.lua` file, plus the extracted transparent PNG files for Studio upload.
4. **Buttons:** polished defaults with an exposed callback table for integration into real game logic.
5. **Transparency:** retain the reference's slightly translucent black panels and square corners.
6. **Live values:** current game data, local player identity, 12-hour countdown, and played time are runtime-driven.

---

## 8. Verification checklist

- [x] Luau 0.748 parser/compiler accepts the complete 1,500+ line file.
- [x] Mock Roblox initialization test completes without a runtime error.
- [x] Embedded PNG decoder reproduces all four source files byte-for-byte by length/signature.
- [x] Idempotent teardown, no `require`, no `Script`, no `RemoteEvent`, and no server dependency.
- [x] Exact 1223×813 baseline coordinates plus clamped viewport scaling.
- [x] Required text/data present: Z, Home, Updates, F/Updates, X/Soon, C/Soon, ZNTH, Standard, 69 Active users.
- [ ] Final visual inspection in Roblox Studio/target executor (requires a Roblox runtime unavailable in this repository sandbox).

---

*Implementation: `SCP-Main-Menu/SCPMainMenu.lua`.*
