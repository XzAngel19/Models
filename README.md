# Models

## Snowpaw | Field Console

[`SnowpawMenu.client.luau`](SnowpawMenu.client.luau) is a separate, mobile-friendly Roblox menu themed around the paw-up cat. The **Main**, **Extra**, and **Visual** tabs have 12 decorative switches and three tuning sliders. Selecting Aimbot, Flight, Player ESP, etc. only changes the console's own UI. **Config** changes its accent, card spacing and captions; nothing is saved across runs.

- **Touch:** tap the tabs, tap a card, or slide the tuner. Drag the header to move the console. **−** docks it to a small Snowpaw button; tap that to reopen. On a keyboard, **Right Shift** also docks/restores it. **×** asks before unloading.
- **Roblox:** the standalone script uses the local player's `PlayerGui`. Both photos are included: no decal upload, external image request or file access. If the place doesn't allow `EditableImage`, it draws the same pictures with static GUI gradients instead.
- **Browser preview:** serve `snowpaw/` with a static web server (e.g. `python -m http.server --directory snowpaw`). The interactive preview and Roblox script use the same [catalog](snowpaw/kit.json), icon shapes and artwork. The preview is not a Roblox runtime.
- **Maintenance:** after changing `snowpaw/kit.json` or the two photos in `snowpaw/assets/`, run `python tools/sync_snowpaw.py` (requires ImageMagick's `convert`) to update the embedded kit. `--check` verifies it without rewriting the file. Run `npm ci && npm test` in `tests/menu` for the mocked-client checks for both menus.

## Zenith | Violence District

[`ViolenceDistrictMenu.client.luau`](ViolenceDistrictMenu.client.luau) is a standalone client menu. On a phone the cards stack in one column. Drag the title to move the window; tap **−** to minimize and **+** to restore it.

**Main → Live HUD** mirrors three captions from the local player's on-screen UI. A missing or hidden caption reads **Not on HUD**. The menu doesn't start a timer, assume a generator total, or infer the player's role.

| Readout | What it mirrors |
| --- | --- |
| Round timer | `time/TimerLabel` in the `Spectatot` lobby or `SpectatorHUD` layouts, including `-mob` and `-con` variants. This may be a waiting message rather than a time. |
| Generators | `bottom left/Gen/genholder/Gencount` on the spectator HUD, or the rendered `Gencount` inside the active HUD's `SurvivorGen` panel. |
| Interaction | The caption or help text in `ProgressPromptGui/Frame`, while displayed. |

These UI shapes come from the [three-part place export](https://github.com/XzAngel19/ARandomMenu/tree/3c7fd7cd960f57411f6b1d54b465d4977885d3ed). The script uses live `PlayerGui` labels, not the stored templates or the mobile layout editor's sample labels. Gameplay, movement, aim, travel and ESP controls remain previews.

**Config → Settings**

- **Save Settings** writes `ZenithViolenceDistrict.settings.json` in the local file workspace when `readfile` and `writefile` are available. **Load Settings** and the next launch restore the last valid save. The file contains menu controls only, not HUD text or player data.
- **Auto Save** keeps subsequent changes, writing slider changes once at the end of a drag. Turning Auto Save off is also saved.
- **Reset Settings** restores the controls without overwriting your save. Tap **Save Settings** to keep the defaults.
- Without file access, Save/Load works in memory until the menu is unloaded. The footer tells you when a write falls back to the session. **Copy Settings** offers selectable JSON text on mobile or desktop.

### Development checks

From `tests/menu`, run `npm ci` and `npm test`. This compiles the standalone Luau script and exercises it with a mobile-sized mock `PlayerGui`, input signals and a simulated local filesystem. The test dependency is not used by the menu. These checks do not run Roblox itself.
