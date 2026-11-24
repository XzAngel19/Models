# ZNTH Main Menu

Pixel-faithful, client-sided Luau reconstruction of the supplied 1223×813 menu reference.

## Deliverable

- **`SCPMainMenu.lua`** — the complete single-file menu (1,500+ lines).
- **`assets/zenith-logo-transparent.png`** — the supplied Division logo with its white background removed.
- **`assets/icon-home.png`**, **`icon-people.png`**, **`icon-doc.png`** — transparent navigation icons.
- **`../docs/SCP-Main-Menu-PLAN.md`** — resolved design and verification plan.

## Implemented details

- Orange **Z** instead of Q.
- PNG/fallback icons for Home, People, and the folded document, followed by **E | Home**.
- Current experience thumbnail from `game.PlaceId` using Roblox's `GameThumbnail` provider.
- Current experience name and description from `MarketplaceService:GetProductInfo`.
- **Continue**, **News**, and **Updates** bars matching the square, translucent reference style.
- Bottom hints: **F / Updates**, **X / Soon**, **C / Soon**.
- Right side: **Clearance / ZNTH**, **Division / Zenith logo**.
- **Standard** with a real 12-hour countdown that updates every second and survives script re-execution during the same session.
- Real **Time Played** session counter in `0d 0h 0m` format.
- **69 Active users**.
- Runtime Roblox username and headshot for `Players.LocalPlayer`.
- Responsive scaling based on the exact 1223×813 reference.
- Idempotent execution: running the file again cleans up the old GUI and all tracked connections.

## Run in Roblox Studio

1. Create a `LocalScript` under `StarterPlayer > StarterPlayerScripts` (or `StarterGui`).
2. Paste the complete contents of `SCPMainMenu.lua`.
3. Start **Play Solo**.

Roblox Studio does not expose executor-only `writefile/getcustomasset` APIs. The file therefore draws matching vector fallbacks for all icons. For the exact supplied Division PNG in Studio:

1. Upload `assets/zenith-logo-transparent.png` as a Roblox image/decal.
2. Copy its numeric asset ID.
3. Set `Config.Assets.DivisionLogo` near the top of `SCPMainMenu.lua` to that ID.

The Home, People, and Document fields can be set the same way, but their built-in code-drawn fallbacks already preserve the menu layout.

## Run in an executor

Use the published branch loader:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Models/arena/cbc36148-models/SCP-Main-Menu/SCPMainMenu.lua", true))()
```

Alternatively, paste/execute `loader.lua` or all of `SCPMainMenu.lua` as one chunk. Compatible executors automatically decode the four embedded PNG files and register them through `getcustomasset`; no extra files or `require` calls are needed.

## Controls

| Input | Action |
|---|---|
| `E` | Open/close both menu sides |
| `Z` | Open the menu and select Home |
| `F` | Pulse Updates and invoke the optional Updates callback |
| `X` | Pulse Soon / invoke optional X callback |
| `C` | Pulse Soon / invoke optional C callback |
| Continue | Closes the menu by default |

## Optional game integration

The executed file returns and exposes the same API as `getgenv().ZNTHMainMenu` in executor environments:

```lua
local menu = getgenv().ZNTHMainMenu

menu.callbacks.Continue = function(api)
    api:SetOpen(false)
    -- Start or resume your game here.
end

menu.callbacks.Updates = function(api)
    -- Open your updates page here.
end
```

Available methods: `SetOpen(boolean)`, `Toggle()`, `SetNavigation(name)`, `PulseHotkey(key)`, `UpdateScale()`, and `Destroy()`.
