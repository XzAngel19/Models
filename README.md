# Zenith

Zenith is split into two independent scripts:

## Zenith Chess

Automatic read-only chess analysis for the supported Roblox chess games. It reads the board, calls Chess-API, displays evaluation and the best move, and draws visual guidance without moving a piece.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Models/arena/cbc36148-models/ZenithChess.txt", true))()
```

## Zenith Vocabulary

Compact automatic vocabulary helper with the single `Search words...` input.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Models/arena/cbc36148-models/ZenithVocabulary.txt", true))()
```

`ZenithHub.txt` remains as a compatibility dispatcher: it loads Chess in the three supported chess Place IDs and Vocabulary everywhere else.
