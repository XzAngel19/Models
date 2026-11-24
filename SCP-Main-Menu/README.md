# ZNTH Main Menu

Client-sided Luau reconstruction of the supplied menu, rendered on two interactive camera-relative 3D surfaces.

## Deliverables

- **`SCPMainMenu.lua`** — complete single-file menu; no `require` and no server script.
- **`loader.lua`** — remote executor loader for the published branch.
- **`assets/zenith-logo-monochrome.png`** — active white/gray/charcoal Zenith repaint.
- **`assets/icon-home.png`** and **`icon-doc.png`** — active navigation icons.
- The orientation cube is generated entirely from real 3D Parts at runtime; it has no PNG asset.
- **`../docs/SCP-Main-Menu-PLAN.md`** — implementation specification and verification checklist.

## Current behavior

- Two invisible camera-relative Parts carry interactive `SurfaceGui` panels with real perspective.
- The panels point inward by 17 degrees and animate smoothly around the player/dummy.
- The upper-right orientation control is a real `ViewportFrame` scene with a `WorldModel`, Camera, shaded cube faces, twelve physical edge bars, and neon X/Y/Z axis Parts—no painted selector.
- The cube is smaller and positioned higher. Its Model rotates every frame from the same smoothed yaw/pitch values as both menu planes.
- Both side panels calculate their centers from one shared visible top line, keeping them aligned at the same height.
- The standalone Z label above the left panel was removed.
- The entire menu uses a neutral black, white, silver, and charcoal palette. No orange accent remains.
- The Zenith logo was repainted in white, light gray, medium gray, and near-black.
- The People/Friends navigation tab was removed. Home and Document now split the aligned navigation strip evenly.
- **Key System** opens a flat ScreenGui text input dynamically projected over the 3D bar. This keeps the text in the correct box when a mobile keyboard changes the viewport.
- Until a key is accepted, Standard Remaining displays **Pending...**. Any non-empty temporary key is accepted; Enter displays **Success!**, activates the countdown, and closes the menu.
- Pressing `X` copies exactly `Zenith.com` to the executor clipboard. The Key Link area is also tappable on mobile.
- News remains one joined image/card; its footer is `16/03/2019 | Zenith Supported`.
- The right header contains only the centered monochrome Zenith logo.
- Current experience data, 12-hour countdown, session time, 69 active users, local username, and avatar remain live.
- A `BlurEffect` fades only with menu state. Roblox CoreGui and modern mobile Chrome are disabled repeatedly during opening, with a protected executor `RobloxGui` fallback, then restored when closing/destroying.
- Re-execution cleans old surfaces, blur, GUI objects, and connections before rebuilding.

## Run in Roblox Studio

1. Create a `LocalScript` under `StarterPlayer > StarterPlayerScripts` or `StarterGui`.
2. Paste all of `SCPMainMenu.lua`.
3. Start **Play Solo**.

Studio does not expose executor-only `writefile/getcustomasset` functions. The script includes code-drawn icon/logo fallbacks. For the exact repainted logo in Studio, upload it and set its numeric ID in `Config.Assets`:

```lua
DivisionLogo = "<uploaded zenith-logo-monochrome ID>",
```

The real orientation cube needs no uploaded asset in Studio or an executor.

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
| Key System + Enter | Accept any non-empty temporary key, show `Success!`, then close |

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
