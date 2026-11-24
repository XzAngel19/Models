# ZNTH Main Menu

Client-sided Luau reconstruction of the supplied 1223×813 menu, now rendered on two true camera-relative 3D surfaces.

## Deliverables

- **`SCPMainMenu.lua`** — complete single-file menu; no `require` and no server script.
- **`loader.lua`** — remote executor loader for the published branch.
- **`assets/zenith-logo-transparent.png`** — supplied Zenith logo with its white background removed.
- **`assets/icon-home.png`**, **`icon-people.png`**, **`icon-doc.png`** — transparent navigation icons.
- **`../docs/SCP-Main-Menu-PLAN.md`** — current implementation specification and validation checklist.

## Current behavior

- Two invisible camera-relative Parts carry interactive `SurfaceGui` panels.
- The panels point inward by 17 degrees and have real perspective, producing the requested 3D illusion around the player/dummy.
- A Studio-style orientation cube appears at the upper-right. Drag it to change both panel directions smoothly; click without dragging to reset it.
- A `BlurEffect` fades in only while the menu is open.
- Roblox CoreGui and the default top bar are hidden only while the menu is open, then restored to their previous states.
- `RightShift` opens or hides the complete menu.
- The former E/Home header is removed; Home, People, and Document now occupy one aligned full-width strip.
- **Key System** replaces Continue. Clicking it reveals a transparent, centered key field. Any non-empty text is accepted for now; Enter displays **Succes!** and closes the menu.
- News is one joined image/card instead of a separate News header and image.
- Current experience thumbnail, name, and description are detected from `game.PlaceId`.
- Bottom hints are **F / Updates**, **X / Key Link**, and **C / Soon**.
- The right header contains only the centered Zenith logo—no Clearance or Division text.
- Live 12-hour Standard countdown, session play time, 69 active users, local username, and local avatar remain enabled.
- Re-execution destroys old surfaces, blur, GUI objects, and connections before rebuilding.

## Run in Roblox Studio

1. Create a `LocalScript` under `StarterPlayer > StarterPlayerScripts` or `StarterGui`.
2. Paste all of `SCPMainMenu.lua`.
3. Start **Play Solo**.

Studio does not expose executor-only `writefile/getcustomasset` functions. The file therefore draws matching icon/logo fallbacks. To use the exact supplied logo in Studio, upload `assets/zenith-logo-transparent.png` and assign its numeric ID to `Config.Assets.DivisionLogo` near the top of the script.

## Run in an executor

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Models/arena/cbc36148-models/SCP-Main-Menu/SCPMainMenu.lua", true))()
```

You may alternatively execute `loader.lua`. Compatible executors decode and register the embedded PNGs automatically.

## Controls

| Input | Action |
|---|---|
| `RightShift` | Open or hide the menu, blur, orientation gizmo, and Roblox chrome override |
| Drag orientation cube | Smoothly rotate/pitch both 3D menu surfaces |
| Click orientation cube | Reset panel direction |
| `Z` | Open the menu and select Home |
| `F` | Pulse Updates and invoke `callbacks.Updates` |
| `X` | Pulse Key Link and invoke `callbacks.KeyLink` |
| `C` | Pulse Soon and invoke `callbacks.C` |
| Key System + Enter | Accept any non-empty temporary key, show `Succes!`, then close |

## Optional game integration

The returned API is also exposed as `getgenv().ZNTHMainMenu` in compatible executor environments:

```lua
local menu = getgenv().ZNTHMainMenu

menu.callbacks.KeyAccepted = function(api, enteredKey)
    print("Accepted key:", enteredKey)
    -- Replace the temporary any-text rule with your key service later.
end

menu.callbacks.KeyLink = function(api)
    -- Copy or display the real key URL here.
end

menu.callbacks.Updates = function(api)
    -- Open your updates page here.
end
```

Available methods: `SetOpen(boolean)`, `Toggle()`, `SetNavigation(name)`, `SetOrientation(yaw, pitch)`, `PulseHotkey(key)`, `UpdateScale()`, and `Destroy()`.
