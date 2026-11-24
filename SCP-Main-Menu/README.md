# ZNTH Main Menu

Client-sided Luau reconstruction of the supplied menu, rendered on two interactive camera-relative 3D surfaces.

## Deliverables

- **`SCPMainMenu.lua`** — complete single-file menu; no `require` and no server script.
- **`loader.lua`** — remote executor loader for the published branch.
- **`assets/zenith-logo-monochrome.png`** — active white/gray/charcoal Zenith repaint.
- **`assets/icon-home.png`** and **`icon-doc.png`** — active Home and folded-paper Announcements icons.
- Rotation is handled directly on the menu planes, so there is no separate orientation widget or asset.
- **`../docs/SCP-Main-Menu-PLAN.md`** — implementation specification and verification checklist.

## Current behavior

- Two invisible camera-relative Parts carry interactive `SurfaceGui` panels with real perspective.
- The panels point inward by 17 degrees and animate smoothly around the player/dummy.
- The separate orientation square/cube was removed. Dragging directly on either visible panel with a mouse or finger smoothly rotates both planes together.
- A four-pixel movement threshold preserves normal taps on controls; a plain tap never resets orientation.
- Both side panels calculate their centers from one shared visible top line, keeping them aligned at the same height.
- The standalone Z label above the left panel remains removed.
- The entire menu uses a neutral black, white, silver, and charcoal palette. No orange accent remains.
- The Zenith logo was repainted in white, light gray, medium gray, and near-black.
- Home and the folded-paper **Announcements** tab split the navigation strip evenly.
- Announcements and Updates each open a square view containing only `Nothing here yet`; Home or the Zenith logo returns to the main menu.
- The footer now reads `F Announcements`, `X Key Link`, and `C Discord`; all three regions also support touch.
- **Key System** opens a flat ScreenGui text input dynamically projected over the 3D bar. This keeps the text in the correct box when a mobile keyboard changes the viewport.
- Until a key is accepted, Standard Remaining displays **Pending...**. Any non-empty temporary key is accepted; Enter displays **Success!**, activates the countdown, and closes the menu.
- Pressing `X` copies exactly `Zenith.com` to the executor clipboard. The Key Link area is also tappable on mobile.
- News remains one joined image/card; its footer is `16/03/2019 | Zenith Supported`.
- The right header contains only the centered monochrome Zenith logo.
- Current experience data, 12-hour countdown, session time, local username, and avatar remain live. The Active Users block and count were removed.
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

Direct panel dragging needs no uploaded asset in Studio or an executor.

## Run in an executor

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Models/arena/cbc36148-models/SCP-Main-Menu/SCPMainMenu.lua", true))()
```

You may alternatively execute `loader.lua`. Compatible executors decode and register all active PNGs automatically.

## Controls

| Input | Action |
|---|---|
| `RightShift` | Open or hide the menu, blur, and Roblox chrome override |
| Drag either menu panel | Smoothly rotate/pitch both 3D surfaces with mouse or touch |
| Home icon or Zenith logo | Return to the main Home view |
| Folded-paper icon | Open Announcements (`Nothing here yet`) |
| Updates bar | Open Updates (`Nothing here yet`) |
| `Z` | Open the menu and select Home |
| `F` | Open Announcements and invoke `callbacks.Announcements` |
| `X` | Copy exactly `Zenith.com`, pulse Key Link, and invoke `callbacks.KeyLink` |
| Tap Key Link | Same clipboard action for mobile users |
| `C` | Pulse Discord and invoke `callbacks.Discord` |
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

Available methods: `SetOpen(boolean)`, `Toggle()`, `SetNavigation(name)`, `OpenHome()`, `OpenAnnouncements()`, `OpenUpdates()`, `OpenDiscord()`, `SetOrientation(yaw, pitch)`, `CopyKeyLink()`, `PulseHotkey(key)`, `UpdateScale()`, and `Destroy()`.
