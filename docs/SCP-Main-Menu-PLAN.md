# ZNTH Main Menu — Implemented Specification

> Reference: supplied 1223×813 Roblox Studio screenshot. Deliverable: one client-sided, executor-compatible Luau file at `SCP-Main-Menu/SCPMainMenu.lua`. Status: **implemented, revision 2**.

---

## 1. Acceptance requirements

| Requirement | Implementation |
|---|---|
| Blur only while active | Dedicated `Lighting.BlurEffect`; tweened to 18 while open and back to 0 before disabling |
| Hide default Roblox logos/UI naturally | Saves each CoreGui enabled state plus top-bar state, hides them while open, restores them when closed/destroyed |
| Toggle with RightShift | Global `UserInputService.InputBegan` binding, including while the key field is focused |
| Panels must look truly 3D | Interactive `SurfaceGui` panels on two invisible camera-relative Parts, not flat ScreenGui frames |
| Stronger inward angle | Default ±17° yaw with -3° pitch and perspective-width correction |
| Orientation block like screenshot | Custom Back/Front cube with X/Y/Z axes at the upper-right; drag rotates both panels smoothly, click resets |
| Remove Clearance/Division | Right header contains only the centered supplied Zenith logo |
| Remove duplicate News bar | Thumbnail and news details form one joined card with a small integrated NEWS badge |
| Replace Continue | Full-width Key System bar and transparent aligned `TextBox` |
| Temporary key behavior | Any non-empty text + Enter is accepted, displays `Succes!`, invokes callback, then closes |
| Replace X label | Bottom row says `X / Key Link` and invokes `callbacks.KeyLink` |
| Remove E/Home header text | Three icon tabs evenly occupy the same 335px width as Key System |
| Preserve live data | Current game thumbnail/name/description, countdown, played time, local name/avatar, 69 active users |

---

## 2. Runtime scene graph

```text
PlayerGui
├── ZNTHMainMenu (ScreenGui)
│   └── OrientationGizmo (interactive Back/Front cube + X/Y/Z axes)
├── ZNTHLeftSurface (SurfaceGui, FixedSize 410×480, active)
│   └── LeftMenu (offset 50,12; 335×452)
└── ZNTHRightSurface (SurfaceGui, FixedSize 350×400, active)
    └── RightMenu (offset 14,8; 323×384)

Workspace
└── ZNTHMenu3D (client-only Folder)
    ├── ZNTHLeftSurfacePlane (invisible anchored Part)
    └── ZNTHRightSurfacePlane (invisible anchored Part)

Lighting
└── ZNTHMenuBlur (BlurEffect)
```

The baseplate, Dummy, sky, and other world objects are supplied by whichever Roblox experience executes the menu. The script does not replace the current game world.

---

## 3. Left surface layout

Reference content width: 335px.

```text
Z outside edge
┌─────────────────────────────────────┐ y=0, h=43
│       Home       People    Document │ equal-width icon tabs
├─────────────────────────────────────┤ y=48, h=54
│             Key System              │ click → transparent key TextBox
├─────────────────────────────────────┤ y=108, h=146
│ NEWS      current game thumbnail    │ runtime GameThumbnail
├─────────────────────────────────────┤ y=254, h=96
│ CURRENT GAME TITLE                  │ runtime product name
│ description                         │ runtime product description
│ 16/03/2019                          │
├─────────────────────────────────────┤ y=358, h=55
│               Updates               │
└─────────────────────────────────────┘
F | Updates     X | Key Link     C | Soon
```

### Key System state machine

1. **Idle:** centered `Key System` label.
2. **Editing:** button/label hidden; transparent centered `TextBox` captures focus.
3. **Rejected:** empty input changes the placeholder to `ENTER ANY KEY FIRST`.
4. **Accepted:** any non-whitespace input sets `keyAccepted`, displays green `Succes!`, calls `callbacks.KeyAccepted(api, enteredKey)`, waits 0.7 seconds, then closes.
5. **Reopened:** accepted label remains visible; clicking it closes again.

---

## 4. Right surface layout

```text
┌─────────────────────────────────────┐
│                                     │
│          transparent ZNTH logo      │ centered; no headers/text columns
│                                     │
├─────────────────────────────────────┤
│ Standard                            │
│ 12 Hours - Remaining / HH:MM:SS     │ live countdown
│ Time Played                         │
│ 0d 0h 0m                            │ live session timer
├─────────────────────────────────────┤
│ 69  Active users                    │
├─────────────────────────────────────┤
│ [avatar] LocalPlayer.Name           │
└─────────────────────────────────────┘
```

The supplied purple logo is embedded as transparent PNG bytes for compatible executors. Studio uses a code-drawn fallback until an uploaded asset ID is configured.

---

## 5. True 3D presentation

For each rendered frame:

1. Calculate scale from the current viewport against the exact 1223×813 reference.
2. Convert desired pixels to world units using camera depth and vertical field of view:
   `worldPerPixel = (2 × depth × tan(FOV/2)) / viewportHeight`.
3. Place each invisible Part relative to `CurrentCamera.CFrame` at depth 8.
4. Apply +17° yaw to the left plane and -17° yaw to the right plane so both point inward toward the player.
5. Apply shared user yaw/pitch from the orientation gizmo.
6. Smooth open amount and direction with exponential interpolation on `RenderStepped`.
7. Slide both real 3D surfaces beyond opposite screen edges when closing.

Physical surface width is multiplied by 0.86 to counter near-edge perspective expansion while preserving a visible trapezoid.

### Orientation gizmo

- Recreates the screenshot's grey Back/Front block.
- Green Y, blue Z, and red X axes.
- Mouse/touch drag updates target yaw and pitch.
- Yaw clamp: ±26°; pitch clamp: ±15°.
- Click without meaningful movement resets to yaw 0°, pitch -3°.
- Cube motion and both planes interpolate smoothly rather than snapping.

---

## 6. Menu environment lifecycle

### Open

- Enable both SurfaceGuis immediately.
- Show orientation gizmo.
- Hide saved CoreGui elements and top bar.
- Enable blur and tween Size to 18.
- Move both 3D surfaces toward their visible target positions.

### Close

- Restore every captured CoreGui state and prior top-bar state.
- Tween blur to zero, then disable it.
- Release/hide key input if necessary.
- Slide surfaces outward; disable them after the transition.
- Hide orientation gizmo.

### Destroy/re-execute

- Release text focus.
- Restore Roblox UI.
- Disconnect every tracked connection.
- Destroy ScreenGui, both SurfaceGuis, 3D folder/Parts, and blur.
- Clear the shared API reference.

---

## 7. Assets and data

| Content | Source |
|---|---|
| Zenith logo | `assets/zenith-logo-transparent.png`, embedded base64 + vector fallback |
| Home/People/Document | Embedded transparent PNGs + vector fallbacks |
| Experience image | `rbxthumb://type=GameThumbnail&id=<game.PlaceId>&w=768&h=432` |
| Experience metadata | `MarketplaceService:GetProductInfo(game.PlaceId)` |
| Player headshot | `Players:GetUserThumbnailAsync(LocalPlayer.UserId, HeadShot, Size180x180)` |
| Username | `LocalPlayer.Name` |
| Countdown | Local 12-hour expiry attribute + server-time fallback |
| Time played | Current client session elapsed time |

---

## 8. Verification

- [x] Luau 0.748 compiler accepts the complete source.
- [x] Mocked Roblox initialization executes without an exception.
- [x] Roblox API dump confirms all used SurfaceGui, Part, BlurEffect, StarterGui, and TextBox members.
- [x] `git diff --check` passes.
- [x] No `require`, server `Script`, `RemoteEvent`, or DataStore dependency.
- [x] Required additions detected: RightShift, BlurEffect, SurfaceGui, orientation gizmo, Key System, `Succes!`, X/Key Link.
- [x] Removed strings detected: Continue, Clearance, Division, E toggle, X/Soon.
- [ ] Final visual/input inspection inside Roblox Studio or the target executor.

---

*Implementation: `SCP-Main-Menu/SCPMainMenu.lua`.*
