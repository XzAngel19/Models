# ZNTH Main Menu — Implemented Specification

> Reference: supplied Roblox screenshots. Deliverable: one client-sided, executor-compatible Luau file at `SCP-Main-Menu/SCPMainMenu.lua`. Status: **implemented, revision 4**.

---

## 1. Current acceptance matrix

| Requirement | Implementation |
|---|---|
| True 3D side panels | Interactive `SurfaceGui` panels on invisible camera-relative Parts |
| Smooth orientation control | Drag/touch updates shared yaw and pitch through exponential interpolation |
| Real 3D orientation cube | Compact `ViewportFrame`/`WorldModel` scene built from face plates, edge bars, axes, lighting, and a dedicated Camera; no PNG or painted imitation |
| Synchronized motion | The cube Model and both menu planes use the same interpolated yaw/pitch state each rendered frame |
| Aligned panel height | Both panel centers derive from one shared visible top line |
| Monochrome Zenith branding | Logo repainted white/light gray/medium gray/charcoal and embedded |
| Remove orange | Global accent, hover colors, labels, dates, hints, and selected tab changed to neutral grayscale |
| Remove Friends icon | People tab no longer constructed; Home and Document each occupy half the strip |
| Fix mobile Key System | Editable TextBox moved to ScreenGui and projected over the moving 3D key bar every rendered frame |
| Key acceptance | Standard Remaining is `Pending...` first; any non-whitespace input + Enter displays `Success!`, starts the 12-hour countdown, and closes |
| Date attribution | Existing game date renders as `16/03/2019 | Zenith Supported` |
| Remove visible Z | No standalone upper-left Z label; the useful Z shortcut remains |
| X copies link | Keyboard X and tappable Key Link call clipboard API with exactly `Zenith.com` |
| Blur/CoreGui lifecycle | Blur only while active; CoreGui All, individual states, and Topbar are hidden/retried while opening and restored on close/destroy |
| Preserve dynamic content | Experience thumbnail/metadata, countdown, play time, fixed 69 active users, username, and avatar |

---

## 2. Asset and geometry workflow

The installed `skills/roblox-ui-asset-painter/SKILL.md` workflow remains applicable to the Zenith logo only:

1. Start from `assets/zenith-logo-transparent.png`.
2. Preserve the alpha channel and antialiased edges.
3. Map the four supplied purple levels to:
   - outer ring/dot: `(215, 219, 225)`;
   - upper chevron: `(245, 246, 248)`;
   - middle chevron: `(145, 151, 160)`;
   - inner chevron: `(42, 46, 52)`.
4. Save as `assets/zenith-logo-monochrome.png` and Base64-embed it for compatible executors.

The orientation cube is deliberately not an image asset. Luau creates its six face plates, twelve edge bars, axis rods/endpoints, labels, `WorldModel`, and Camera at runtime. The original purple logo and old People icon remain archived but are not rendered.

---

## 3. Runtime hierarchy

```text
PlayerGui
├── ZNTHMainMenu (ScreenGui)
│   ├── OrientationGizmo (82×82 drag/touch target)
│   │   └── ViewportFrame + dedicated Camera
│   │       └── WorldModel
│   │           └── DirectionCube3D Model
│   │               ├── six face/label plates
│   │               ├── twelve physical edge bars
│   │               └── X/Y/Z neon axis rods and endpoints
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
┌─────────────────────────────────────┐
│            Home │ Document          │ two equal navigation tabs
├─────────────────────────────────────┤
│             Key System              │ projected mobile input overlays this bar
├─────────────────────────────────────┤
│ NEWS      current game thumbnail    │
├─────────────────────────────────────┤
│ CURRENT GAME TITLE                  │
│ description                         │
│ 16/03/2019 | Zenith Supported       │
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
6. Enter accepts any non-empty temporary key, hides the overlay, restores the 3D label as `Success!`, then closes.

---

## 6. Real orientation cube

- The compact 82×82 control contains a real `ViewportFrame`, `WorldModel`, `Model`, and dedicated perspective Camera.
- Six physical face plates use distinct neutral shades; twelve beveled-looking edge bars outline the cube.
- Red X, green Y, and blue Z axes use real neon cylinder rods and endpoint spheres, with small viewport labels for legibility.
- There is no screenshot, selector PNG, fake painted cube, or large artificial background square.
- Drag updates target yaw (±26°) and pitch (±15°); mouse and touch share the same path.
- Exponential interpolation drives both panel Parts and `DirectionCube3D:PivotTo(...)` every rendered frame. They therefore start, move, and settle together in the same direction.
- Tap without a meaningful drag resets to yaw 0°, pitch -3°.
- Both side surfaces use one `sharedRootTop` calculation so their visible bases begin at the same vertical height.

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
- [x] Mock initialization/API lifecycle passes with `ViewportFrame`, `WorldModel`, Camera, and `Model:PivotTo` support.
- [x] Mock geometry count confirms six face plates, twelve edges, six axis pieces, and the two world-space menu planes.
- [x] Mock mouse and touch drags update orientation; render assertions confirm both panels and the cube consume the same interpolated yaw/pitch state.
- [x] Shared-top offset math aligns the visible left/right panel roots.
- [x] Mock mobile key overlay projects into ScreenGui instead of SurfaceGui.
- [x] Mock pre-key state is exactly `Pending...`; temporary key flow reaches `Success!`, activates Remaining, and closes.
- [x] Mock X input and tappable Key Link write exactly `Zenith.com` to the clipboard function.
- [x] RightShift, retained Z shortcut, teardown, and Friends-tab absence are covered.
- [x] No orange RGB values or People icon construction remain in active code.
- [x] Embedded active PNGs are byte-identical to source files; the painted orientation asset/reference is absent.
- [x] `git diff --check` passes.
- [ ] Final visual/input inspection in the target mobile executor.

---

*Implementation: `SCP-Main-Menu/SCPMainMenu.lua`.*
