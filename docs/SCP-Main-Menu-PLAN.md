# ZNTH Main Menu — Implemented Specification

> Reference: supplied Roblox screenshots and follow-up interaction requirements. Deliverable: one client-sided, executor-compatible Luau file at `SCP-Main-Menu/SCPMainMenu.lua`. Status: **implemented, revision 5**.

---

## 1. Current acceptance matrix

| Requirement | Implementation |
|---|---|
| True 3D side panels | Two interactive `SurfaceGui` panels on invisible camera-relative Parts |
| No orientation square | The `ViewportFrame` cube and all separate gizmo UI were removed |
| Direct rotation | A mouse/touch drag beginning on either visible panel updates shared target yaw and pitch |
| Preserve normal taps | Rotation starts after four pixels of movement; a tap does not reset direction |
| Synchronized motion | Both 3D planes consume the same exponentially interpolated yaw/pitch state |
| Aligned panel height | Both centers derive from one shared visible root-top line |
| Announcements navigation | Folded-paper icon beside Home selects `Announcements` |
| Empty Announcements/Updates views | Each is a 335×335 square plane containing only `Nothing here yet` |
| Return Home | Home icon, Zenith logo, or Z shortcut restores the main view |
| Footer labels | Exactly `F Announcements`, `X Key Link`, and `C Discord`; all three regions are touchable |
| Remove Active Users | Entire block, wording, and numeric count removed; right panel compacted |
| Mobile Key System | ScreenGui TextBox is projected over the moving 3D Key System bar every frame |
| Key acceptance | `Pending...` before input; nonblank Enter displays `Success!`, activates Remaining, and closes |
| Clipboard | Keyboard/touch Key Link copies exactly `Zenith.com` |
| Dynamic content | Current experience thumbnail/metadata, play time, username, and avatar remain live |
| Environment lifecycle | Blur and Roblox CoreGui hiding exist only while the menu is active |

---

## 2. Runtime hierarchy

```text
PlayerGui
├── ZNTHMainMenu (ScreenGui)
│   └── KeyInputOverlay (visible only while editing)
├── ZNTHLeftSurface (SurfaceGui, FixedSize 410×480)
│   └── LeftMenu
│       ├── NavigationRow
│       │   ├── HomeNavigation
│       │   └── AnnouncementsNavigation (folded-paper icon)
│       ├── HomeView
│       ├── AnnouncementsView (335×335)
│       │   └── Nothing here yet
│       └── UpdatesView (335×335)
│           └── Nothing here yet
└── ZNTHRightSurface (SurfaceGui, FixedSize 350×400)
    └── RightMenu
        ├── tappable Zenith logo
        ├── Standard / Time Played
        └── local player profile

Workspace
└── ZNTHMenu3D
    ├── ZNTHLeftSurfacePlane
    └── ZNTHRightSurfacePlane

Lighting
└── ZNTHMenuBlur
```

There is no `OrientationGizmo`, `ViewportFrame`, `WorldModel`, direction cube, or orientation PNG.

---

## 3. Left-panel views

### Home

```text
┌─────────────────────────────────────┐
│             Home │ Announcements    │
├─────────────────────────────────────┤
│             Key System              │
├─────────────────────────────────────┤
│ NEWS      current game thumbnail    │
├─────────────────────────────────────┤
│ CURRENT GAME TITLE                  │
│ description                         │
│ 16/03/2019 | Zenith Supported       │
├─────────────────────────────────────┤
│               Updates               │
└─────────────────────────────────────┘
F | Announcements   X | Key Link   C | Discord
```

### Announcements

- Selected by the folded-paper icon or F.
- Hides all Home content below the navigation strip.
- Shows one square plane containing exactly `Nothing here yet`.

### Updates

- Selected by the Updates bar on Home.
- Shows an identical square plane containing exactly `Nothing here yet`.

The Home icon or centered Zenith logo restores `HomeView`.

---

## 4. Direct panel rotation

1. Global mouse/touch input is observed without placing a blocking overlay above the UI.
2. The four corners of each visible panel root are projected through its Part CFrame and the current Camera.
3. A drag can start only when its initial point lies inside one projected panel quadrilateral.
4. Four pixels of movement distinguish rotation from a normal button tap.
5. Horizontal movement changes target yaw; vertical movement changes target pitch.
6. Touch identity is tracked so a second finger cannot hijack the active gesture.
7. Both panels interpolate toward the same targets on `RenderStepped`.
8. Closing the menu cancels any active gesture.

A plain tap no longer resets orientation.

---

## 5. Right panel

- The monochrome Zenith logo remains centered and is now a Home control.
- Standard Remaining displays `Pending...` until a key succeeds.
- Time Played remains a real session counter.
- The entire Active Users frame, `Active users` wording, and numeric count were removed.
- The local username/avatar row moves upward directly beneath account information.
- The right root is compacted from 384 to 313 canvas pixels high.

---

## 6. Mobile Key System projection

1. Tapping Key System hides its surface label.
2. A transparent `TextBox` in the ScreenGui captures focus.
3. Every rendered frame projects the four key-bar corners with `CFrame:PointToWorldSpace` and `CurrentCamera:WorldToViewportPoint`.
4. Position, dimensions, and rotation follow the moving 3D bar, including mobile viewport changes.
5. Navigating away from Home releases and hides an active key field.
6. Nonblank Enter changes the label to exactly `Success!`, activates the countdown, and closes the menu.

---

## 7. Footer and callbacks

| Control | Built-in behavior | Callback |
|---|---|---|
| F / Announcements region | Open Announcements | `callbacks.Announcements` (fallback `callbacks.F`) |
| X / Key Link region | Copy exactly `Zenith.com` | `callbacks.KeyLink` (fallback `callbacks.X`) |
| C / Discord region | Pulse Discord | `callbacks.Discord` (fallback `callbacks.C`) |
| Updates bar | Open Updates placeholder | `callbacks.Updates` |
| Home icon / Zenith logo | Restore Home | `callbacks.Home` |

---

## 8. Environment lifecycle

### Open

- Enable both SurfaceGuis.
- Tween blur to 18.
- Hide captured CoreGui states and `TopbarEnabled`, including delayed mobile-Chrome retries.

### Close/destroy

- Cancel direct rotation and release the key overlay.
- Restore every captured Roblox UI state.
- Tween blur to zero and disable it.
- Slide/disable both 3D surfaces.
- Destroy GUI, surfaces, world folder, blur, and tracked connections on teardown or re-execution.

---

## 9. Validation

- [x] Luau 0.748 compiler accepts the main script and loader.
- [x] Mock runtime confirms the orientation square/cube hierarchy is absent and only two world Parts remain.
- [x] Mock mouse and touch gestures begin directly on projected panel geometry and rotate both surfaces together.
- [x] Mock taps preserve orientation and continue to support navigation controls.
- [x] Folded-paper, F, Home, Zenith-logo, Updates, X, C, and RightShift paths are covered.
- [x] Announcements and Updates both render exact `Nothing here yet` state.
- [x] Active Users code/configuration is absent and the right panel is compacted.
- [x] Mobile key projection, exact `Pending...` / `Success!`, countdown activation, and close-after-success pass.
- [x] Exact `Zenith.com` clipboard behavior and full cleanup pass.
- [x] `git diff --check` passes.
- [ ] Final visual/input inspection in the target mobile executor.

---

*Implementation: `SCP-Main-Menu/SCPMainMenu.lua`.*
