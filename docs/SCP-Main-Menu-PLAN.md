# ZNTH Main Menu — Implemented Specification

> Reference: supplied Roblox screenshots. Deliverable: one client-sided, executor-compatible Luau file at `SCP-Main-Menu/SCPMainMenu.lua`. Status: **implemented, revision 3**.

---

## 1. Current acceptance matrix

| Requirement | Implementation |
|---|---|
| True 3D side panels | Interactive `SurfaceGui` panels on invisible camera-relative Parts |
| Smooth orientation control | Drag/touch updates shared yaw and pitch through exponential interpolation |
| Cube must match original | Exact Back/Right Studio selector extracted from the first supplied screenshot, black sky removed, embedded as transparent PNG |
| Monochrome Zenith branding | Logo repainted white/light gray/medium gray/charcoal and embedded |
| Remove orange | Global accent, hover colors, labels, dates, hints, and selected tab changed to neutral grayscale |
| Remove Friends icon | People tab no longer constructed; Home and Document each occupy half the strip |
| Fix mobile Key System | Editable TextBox moved to ScreenGui and projected over the moving 3D key bar every rendered frame |
| Key acceptance | Any non-whitespace input + Enter displays `Succes!` and closes |
| X copies link | Keyboard X and tappable Key Link call clipboard API with exactly `Zenith.com` |
| Blur/CoreGui lifecycle | Blur only while active; CoreGui All, individual states, and Topbar are hidden/retried while opening and restored on close/destroy |
| Preserve dynamic content | Experience thumbnail/metadata, countdown, play time, active users, username, and avatar |

---

## 2. Painted asset workflow

The installed `skills/roblox-ui-asset-painter/SKILL.md` workflow uses Pillow as the paint/vector utility:

1. Start from `assets/zenith-logo-transparent.png`.
2. Preserve the alpha channel and antialiased edges.
3. Map the four supplied purple levels to:
   - outer ring/dot: `(215, 219, 225)`;
   - upper chevron: `(245, 246, 248)`;
   - middle chevron: `(145, 151, 160)`;
   - inner chevron: `(42, 46, 52)`.
4. Save as `assets/zenith-logo-monochrome.png`.
5. Crop the original Studio selector at its native resolution from the first screenshot.
6. Remove only the nearly-black neutral sky while preserving gray faces, dark labels, and colored axes.
7. Save as `assets/orientation-gizmo-reference.png`.
8. Base64-embed both PNGs in the single Luau deliverable for `getcustomasset` executors.

The original purple logo and old People icon remain archived but are not rendered.

---

## 3. Runtime hierarchy

```text
PlayerGui
├── ZNTHMainMenu (ScreenGui)
│   ├── OrientationGizmo
│   │   ├── exact transparent Studio selector image
│   │   └── invisible drag/touch target
│   └── KeyInputOverlay (visible only while editing)
├── ZNTHLeftSurface (SurfaceGui, FixedSize 410×480)
│   └── LeftMenu
└── ZNTHRightSurface (SurfaceGui, FixedSize 350×400)
    └── RightMenu

Workspace
└── ZNTHMenu3D
    ├── ZNTHLeftSurfacePlane
    └── ZNTHRightSurfacePlane

Lighting
└── ZNTHMenuBlur
```

---

## 4. Left panel

```text
Z outside edge
┌─────────────────────────────────────┐
│            Home │ Document          │ two equal navigation tabs
├─────────────────────────────────────┤
│             Key System              │ projected mobile input overlays this bar
├─────────────────────────────────────┤
│ NEWS      current game thumbnail    │
├─────────────────────────────────────┤
│ CURRENT GAME TITLE                  │
│ description                         │
│ 16/03/2019                          │
├─────────────────────────────────────┤
│               Updates               │
└─────────────────────────────────────┘
F | Updates     X | Key Link     C | Soon
```

All previous orange elements now use `Config.Accent = Color3.fromRGB(207, 211, 217)` or another neutral white/gray value.

---

## 5. Mobile Key System projection

The key field is no longer parented to a `SurfaceGui`:

1. Clicking the 3D Key System button hides its surface label.
2. A transparent `TextBox` in the root ScreenGui captures focus.
3. Each `RenderStepped` frame projects the four bar corners from surface-canvas coordinates through:
   - the current Part size and CFrame;
   - `CFrame:PointToWorldSpace`;
   - `CurrentCamera:WorldToViewportPoint`.
4. The overlay receives the projected center, average width/height, and normalized screen rotation.
5. If the mobile keyboard changes viewport size, the surfaces and field are recalculated together, so the editable text remains inside the same visual box.
6. Enter accepts any non-empty temporary key, hides the overlay, restores the 3D label as `Succes!`, then closes.

---

## 6. Orientation widget

- Visual asset matches the original screenshot: gray spherical selector, Back/Right faces, green Y, blue Z, and red X.
- The large artificial square and `DRAG TO ORIENT` caption were removed.
- The entire 102×92 transparent image is the drag/touch target.
- Drag updates yaw (±26°) and pitch (±15°).
- Tap without a meaningful drag resets to yaw 0°, pitch -3°.
- The image remains visually faithful rather than rotating its 2D axes; the actual 3D planes provide movement feedback.

---

## 7. Clipboard behavior

```text
KEY_LINK_TEXT = "Zenith.com"
clipboard API = setclipboard or toclipboard
```

- Physical keyboard X copies the exact string.
- Tapping the Key Link section performs the same action on mobile.
- The label briefly displays `Copied!` when the executor clipboard API succeeds.
- `callbacks.KeyLink` remains available after the built-in copy action.

---

## 8. Environment lifecycle

### Open

- Enable both SurfaceGuis and orientation selector.
- Tween blur to 18.
- Call `SetCoreGuiEnabled(All, false)`, then disable captured types individually.
- Disable `TopbarEnabled` immediately, use a protected executor-only `CoreGui.RobloxGui.Enabled` fallback, and retry at 0.1, 0.35, 0.8, and 1.4 seconds for late mobile Chrome initialization.

### Close/destroy

- Restore every captured CoreGui state and prior topbar state.
- Tween blur to zero, then disable it.
- Release/hide the key overlay.
- Slide and disable the 3D surfaces.
- Destroy ScreenGui, SurfaceGuis, Parts/folder, blur, and tracked connections when re-executed.

---

## 9. Validation

- [x] Luau 0.748 compiler accepts the complete main script and loader.
- [x] Mock initialization/API lifecycle passes.
- [x] Mock mobile key overlay projects into ScreenGui instead of SurfaceGui.
- [x] Mock temporary key flow reaches `Succes!` and closes.
- [x] Mock X input writes exactly `Zenith.com` to the clipboard function.
- [x] Friends navigation entry is absent.
- [x] No orange RGB values or People icon construction remain in active code.
- [x] Embedded PNG decoder/source signatures validated.
- [x] `git diff --check` passes.
- [ ] Final visual/input inspection in the target mobile executor.

---

*Implementation: `SCP-Main-Menu/SCPMainMenu.lua`.*
