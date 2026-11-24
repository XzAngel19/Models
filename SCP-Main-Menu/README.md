# ZNTH Main Menu

Client-sided Luau reconstruction of the supplied menu, rendered on two interactive camera-relative 3D surfaces.

## Deliverables

- **`SCPMainMenu.lua`** — complete single-file menu; no `require` and no server script.
- **`loader.lua`** — remote executor loader for the published branch.
- **`assets/zenith-logo-monochrome.png`** — active white/gray/charcoal Zenith repaint.
- **`assets/orientation-gizmo-reference.png`** — transparent orientation widget extracted from the exact original reference.
- **`assets/icon-home.png`** and **`icon-doc.png`** — active navigation icons.
- **`../docs/SCP-Main-Menu-PLAN.md`** — implementation specification and verification checklist.

## Current behavior

- Two invisible camera-relative Parts carry interactive `SurfaceGui` panels with real perspective.
- The panels point inward by 17 degrees and animate smoothly around the player/dummy.
- The upper-right orientation control now uses the exact compact Back/Right Studio widget from the reference, including its X/Y/Z axes. Dragging still changes both panel directions; tapping without dragging resets them.
- The entire menu uses a neutral black, white, silver, and charcoal palette. No orange accent remains.
- The Zenith logo was repainted in white, light gray, medium gray, and near-black.
- The People/Friends navigation tab was removed. Home and Document now split the aligned navigation strip evenly.
- **Key System** opens a flat ScreenGui text input dynamically projected over the 3D bar. This keeps the text in the correct box when a mobile keyboard changes the viewport.
- Any non-empty temporary key is accepted; Enter displays **Succes!** and closes the menu.
- Pressing `X` copies exactly `Zenith.com` to the executor clipboard. The Key Link area is also tappable on mobile.
- News remains one joined image/card instead of a separate News header and image.
- The right header contains only the centered monochrome Zenith logo.
- Current experience data, 12-hour countdown, session time, 69 active users, local username, and avatar remain live.
- A `BlurEffect` fades only with menu state. Roblox CoreGui and modern mobile Chrome are disabled repeatedly during opening, with a protected executor `RobloxGui` fallback, then restored when closing/destroying.
- Re-execution cleans old surfaces, blur, GUI objects, and connections before rebuilding.

## Run in Roblox Studio

1. Create a `LocalScript` under `StarterPlayer > StarterPlayerScripts` or `StarterGui`.
2. Paste all of `SCPMainMenu.lua`.
3. Start **Play Solo**.

Studio does not expose executor-only `writefile/getcustomasset` functions. The script includes code-drawn fallbacks. For the exact repainted logo and reference gizmo in Studio, upload these files and set their numeric IDs in `Config.Assets`:

```lua
DivisionLogo = "<uploaded zenith-logo-monochrome ID>",
OrientationGizmo = "<uploaded orientation-gizmo-reference ID>",
```

## Run in an executor

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Models/arena/cbc36148-models/SCP-Main-Menu/SCPMainMenu.lua", true))()
```

You may alternatively execute `loader.lua`. Compatible executors decode and register all active PNGs automatically.

## Controls

| Input | Action |
|---|---|
| `RightShift` | Open or hide the menu, blur, gizmo, and Roblox chrome override |
| Drag orientation widget | Smoothly rotate/pitch both 3D menu surfaces |
| Tap orientation widget | Reset panel direction |
| `Z` | Open the menu and select Home |
| `F` | Pulse Updates and invoke `callbacks.Updates` |
| `X` | Copy exactly `Zenith.com`, pulse Key Link, and invoke `callbacks.KeyLink` |
| Tap Key Link | Same clipboard action for mobile users |
| `C` | Pulse Soon and invoke `callbacks.C` |
| Key System + Enter | Accept any non-empty temporary key, show `Succes!`, then close |

## Optional game integration

The returned API is also exposed as `getgenv().ZNTHMainMenu` in compatible executor environments:

```lua
local menu = getgenv().ZNTHMainMenu

menu.callbacks.KeyAccepted = function(api, enteredKey)
    print("Accepted key:", enteredKey)
    -- Replace the temporary any-text rule with your real key service later.
end

menu.callbacks.KeyLink = function(api)
    -- The built-in behavior already copies Zenith.com.
end
```

Available methods: `SetOpen(boolean)`, `Toggle()`, `SetNavigation(name)`, `SetOrientation(yaw, pitch)`, `CopyKeyLink()`, `PulseHotkey(key)`, `UpdateScale()`, and `Destroy()`.
