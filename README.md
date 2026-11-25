# Zenith

Zenith is split into two independent scripts:

## Zenith Chess

Automatic read-only chess analysis for the supported Roblox chess games. It reads the board, calls Chess-API, displays evaluation and the best move, and draws visual guidance without moving a piece.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Models/arena/cbc36148-models/ZenithChess.txt", true))()
```

## Zenith Vocabulary

Compact automatic helper for exactly two supported word games, with fully isolated remote adapters: **Word Battle** (`74300432420573`) owns its `MatchStatus`/dynamic per-match typing protocol and **Last Letter** (`129866685202296`) owns only `ReplicatedStorage.Modules.Packet.RemoteEvent` plus its visible `CurrentWord` interface. A remote observed in one game is never installed, trusted, or reused in the other. In either game, one click or tap types a suggestion through that game's real keyboard or verified protocol—never by assigning the game's or Zenith's search `TextBox.Text`; Last Letter's own controller serializes its packet payload, while Word Battle may use its verified match remote. A second rapid activation copies the suggestion instead. Confirmed/attempted words from both players are remembered and excluded when used-word filtering is enabled. A transparent settings control exposes Auto Type, adjustable WPM, Cambridge definitions, optional uncapped results, automatic game-input detection, and used-word filtering. Generated input is cancelled across Roblox menu, focus, letter-selection, and turn transitions. Touch devices use a smaller window, a reduced result-rendering budget, and recoverable off-screen dragging to minimize mobile load; suggestions can be ranked by frequency or length, and detection never plays or submits a word by itself.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Models/arena/cbc36148-models/ZenithVocabulary.txt", true))()
```

`ZenithHub.txt` remains as a compatibility dispatcher: it loads Chess in the three supported chess Place IDs, Vocabulary only in Word Battle or Last Letter, and reports unsupported Place IDs instead of installing the wrong adapter.
