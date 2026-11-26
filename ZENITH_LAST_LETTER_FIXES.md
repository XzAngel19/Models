# ZenithVocabulary — Last Letter input fixes

Imported `ZenithVocabulary.txt` from `arena/cbc36148-models` using GitHub's
contents API, then edited locally on `arena/e4da32c5-models`.

## Changes

- Empty visible CurrentWord is valid; it is no longer confused with unavailable UI.
- Auto Type does not treat Zenith's search query as text already entered in the game.
- Each generated letter must appear in CurrentWord within 0.8 seconds before the
  next letter is sent. Timeout stops the sequence; no blind retries.
- External edits, cancellation, missing UI, and focus in chat/search stop generation.
- Hardware/button/heuristic Packet detection yields to the visible game word while
  CurrentWord is available, preventing competing observers from appending twice.
- Polling does not overwrite manual search/chat input while those boxes have focus.
- Sender exceptions terminate auto typing instead of leaving isAutoTyping stuck.

## Limits

This is NOT a verified decoder for Last Letter's shared Packet.RemoteEvent.
No guessed binary packets were added or replayed. The existing heuristic remote
fallback remains only when the visible CurrentWord cannot be read. It is not
proof of a typing protocol. Auto Type now refuses to guess without CurrentWord.
A changed UI path or an input API that returns successfully without activating
the game's controller still requires an in-game trace to fix the integration.
No automatic word submission was added. Other games' remote protocols are unchanged.

## Validation

- Full file compiled with upstream luau-compile at -O0 and -O1.
- Seven deterministic tests execute the actual Last Letter auto-type branch:
  empty entry, existing prefix, already complete, mismatched prefix, missing UI,
  unacknowledged key, and cancellation while waiting for acknowledgment.
- Run: `python3 tools/test_zenith_last_letter.py /path/to/luau`.
- Tests use mocks: they do not validate Roblox GUI layout, executor APIs or server acceptance.

## In-game checks still required

1. Launch a fresh copy, enable Auto Detect, close chat, and type into the custom
   game keyboard. Zenith should match CurrentWord without double letters.
2. Backspace and clear the word. Zenith should follow the displayed word.
3. Choose a suggestion with an empty entry, then with a matching existing prefix.
4. If the first generated letter is not accepted, generation must stop rather than
   report the entire word as written.
5. Focus chat and Zenith search: neither should be interpreted as game typing.
6. If CurrentWord cannot be found, capture its current PlayerGui hierarchy and a
   short log of manual typing (including deletion), rather than guessing Packet IDs.

## GUI/settings follow-up

- Removed the W image/fallback and its asset resolution; reserved more trailing
  space between the used count and save icon.
- Added Enable Derivations (off by default): a small explicit list of rare forms,
  not an arbitrary suffix generator. No promise of server dictionary acceptance.
  Includes yesterdayness/selfness. Uses the existing contains/prefix and used filters.
- Added Legit Auto Type toggle and separate Min/Max WPM sliders (mouse/touch,
  integer values within 30–600, min cannot exceed max). Enabling it enables Auto
  Type; disabling Auto Type also disables Legit. Normal typing and suggestion
  clicks use the same timing helper. Legit samples a random WPM per character.
  Input acknowledgment time is subtracted from the pacing delay; game latency
  can still make actual speed slower than requested.
- Fixed an earlier regression: the visible-entry early return swallowed the
  submission key before recording it, so Used tracking never saw the action.
  Activity is now recorded before yielding to the visual observer.
- Used tracks observed submissions even outside the local dictionary and refreshes
  filtered suggestions. This is not confirmation that a server accepted the word.
  Word Battle still uses its existing server-confirmation handler.
- Visual letters use left-to-right screen order instead of inconsistent mixed
  LayoutOrder/position comparisons; a stable second sample suppresses transient
  layout reversal. A root text field takes precedence over animated descendants.
- Last Letter prefers virtual hardware input when available rather than assuming
  firing Activated triggered a ContextAction controller. No binary protocol guessed.
- Opening Settings cancels an ongoing generated sequence.

Additional regression command:
`python3 tools/test_zenith_gui_logic.py /path/to/luau`.
Tests exercise production timing, used-memory and visual-reader helpers with mocks.
All runtime GUI controls, mobile hit targets and the live remote/input integration
still require an in-game check. Slider/UI appearance was not rendered in the sandbox.
