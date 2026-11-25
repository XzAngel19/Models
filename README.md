# Zenith

Zenith is split into two independent scripts:

## Zenith Chess

Automatic read-only chess analysis for the supported Roblox chess games. It reads the board, calls Chess-API, displays evaluation and the best move, and draws visual guidance without moving a piece.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Models/arena/cbc36148-models/ZenithChess.txt", true))()
```

## Zenith Vocabulary

Compact automatic word-game helper with the single `Search words...` input. It watches normal text boxes, custom on-screen keyboards, the confirmed local-player turn/per-letter protocol (with a conservative visible prompt fallback) in Place ID `74300432420573`, and the visible `CurrentWord` interface / validated packet input in Place ID `129866685202296`. One click or tap types a suggestion into the active game input; a second rapid activation copies it instead. Generated input is cancelled across Roblox menu, focus, and turn transitions. Touch devices use a smaller window, a reduced result-rendering budget, and recoverable off-screen dragging to minimize mobile load; suggestions can be ranked by frequency or length, saved/used words are hidden until reset, and detection never plays or submits a word by itself.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Models/arena/cbc36148-models/ZenithVocabulary.txt", true))()
```

`ZenithHub.txt` remains as a compatibility dispatcher: it loads Chess in the three supported chess Place IDs and Vocabulary everywhere else.
