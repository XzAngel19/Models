---
name: roblox-luau-gui
description: Build client-sided Roblox GUI menus in Luau that run as a single executable LocalScript (Roblox Studio StarterGui or executor loadstring). Use when the user asks for a Roblox GUI, hub menu, main menu, or any ScreenGui built purely in code.
---

# Roblox Luau GUI Builder (Client-Sided, Executable)

## When to use this skill
- User wants a Roblox GUI/menu built in Luau (not in Studio by hand).
- The GUI must be **client-sided**: a `LocalScript` that creates a `ScreenGui` in `PlayerGui` at runtime.
- The GUI must be **executable**: runnable via Roblox Studio Play **and** via an executor `loadstring` / `HttpGet` single-file script.

## Core rules (non-negotiable)
1. **100% code-built UI.** Every `Instance.new` happens in Luau. No hand-placed Studio objects, no `.rbxm` dependency.
2. **Client only.** Use `game:GetService("Players").LocalPlayer`, `PlayerGui`, `UserInputService`, `TweenService`, `RunService`. Never create `Script`/`RemoteEvent` server logic.
3. **Single-file friendly.** The whole GUI must work as ONE `.lua` file pasted into a `LocalScript` or executed with `loadstring`. If splitting into ModuleScripts, also provide a single-file build that inlines them.
4. **Idempotent.** If the GUI already exists in `PlayerGui` (same name), destroy it first so re-executing doesn't duplicate.
5. **No external requires.** No `require(assetId)` modules. All code is inline. Assets are only `rbxassetid://` images.
6. **Luau idioms.** `local`, `task.spawn`/`task.wait`, `table.insert`, `UDim2.fromScale`/`fromOffset`, `Color3.fromRGB`, `Enum.Font.*`. No `wait()`/`spawn()` legacy globals.

## Code style (match this repo's `Zenith` convention)
- Header comment: `-- <Name> | GUI ...` + services block at top.
- `local` services: `playersService`, `userInputService`, `tweenService`, etc.
- Constants block: sizes, colors (`Color3.fromRGB`), fonts, `TweenInfo`s.
- Helper `create(className, properties, parent)` that sets props then parents.
- Helper `tween(instance, info, goal)` wrapping `TweenService:Create`.
- Helper `addStroke` / `addGradient` / `addCorner` for borders, gradients, corners.
- One root table (e.g. `local Menu = { ... }`) holding state, connections, callbacks.
- Every `RBXScriptConnection` stored and cleaned up on close/destroy.
- Tabs/sections built by functions (`buildLeftPanel()`, `buildRightPanel()`), not one giant inline block.

## UI building blocks
- `ScreenGui` → `IgnoreGuiInset = true`, `DisplayOrder`, `ResetOnSpawn = false`.
- Panels: `Frame` + `UIStroke` (1px, grey/white) + optional `UIGradient` (black fade).
- Buttons: `TextButton` with `AutoButtonColor = false` + manual hover tween (background + text color).
- Icons: `ImageLabel` with `rbxassetid://` + `ScaleType = Fit`.
- Text: `TextLabel`/`TextButton` with `TextScaled = false`, explicit `TextSize`, `Font = Enum.Font.Gotham*`.
- Layout: prefer `UIListLayout` + `UIPadding` inside panels; use `UDim2.fromOffset` for pixel-exact replication, `fromScale` for responsive anchors.
- Dividers: 1px `Frame` with `BackgroundColor3` grey, `BorderSizePixel = 0`.
- Keybind hints: orange key letter + white label + thin vertical divider frame.

## Animation
- Open/close: `TweenService` on `Position`/`GroupTransparency`/`BackgroundTransparency`.
- Hover: 0.15s `Quad Out` tween on background/text color.
- Press: scale `0.98` via `UIScale` tween, then back.
- Never use `while` loops for animation; use tweens or `RenderStepped`.

## Assets
- All images must be `rbxassetid://<id>` with a fallback: if `Image` fails to load, show a colored placeholder frame so layout never breaks.
- Keep an `ASSETS` table at top of file: `SCP_LOGO = "rbxassetid://..."`, `NEWS_IMAGE = "..."`, icons, etc.
- If the user hasn't provided IDs yet, use clearly-marked placeholders and list them as TODOs in the plan.

## Data binding (client-safe)
- Player name: `LocalPlayer.DisplayName` / `Name`.
- Avatar: `Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, ...)`.
- Friends online: `LocalPlayer:GetFriendsAsync()` (pcall-wrapped; fallback to 0).
- Time played / balance / clearance: local `Config` table + `DataStore` is server-only — simulate with `HttpService:JSONEncode` to a local table or hard-coded defaults.

## Execution checklist (verify before finishing)
- [ ] Runs in Studio: `StarterGui > LocalScript`, Play Solo, no errors in Output.
- [ ] Runs via executor: single file, `loadstring(game:HttpGet(url))()` or pasted, no `require`.
- [ ] Re-executing doesn't stack duplicate GUIs.
- [ ] Works at 1280x720 and 1920x1080 (no clipped panels).
- [ ] All buttons respond (hover + click), all keybinds (E/Q/F/X/C) work.
- [ ] No server `Script`, no `RemoteEvent`, no `require(assetId)`.

## Output format
- Deliver: (1) the `.lua` file(s), (2) how to run it in Studio, (3) how to run it via executor, (4) asset ID list, (5) controls/keybinds.
- If the user asked for a plan first, deliver the plan and STOP — do not write the full GUI until they approve.
