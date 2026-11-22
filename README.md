# Models

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
