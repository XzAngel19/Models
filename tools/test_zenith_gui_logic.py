#!/usr/bin/env python3
"""Extract production helpers and test with Luau mocks; no Roblox integration implied."""
from pathlib import Path
import subprocess
import sys
import tempfile

source = (Path(__file__).resolve().parents[1] / 'ZenithVocabulary.txt').read_text()
def section(start, end):
    pos = source.index(start)
    return source[pos:source.index(end, pos)]

interval = section('WordHelper.TypingInterval = function()', '\n\tWordHelper.BeginAutoTyping')
used = section('markUsed = function(word)', '\n\tlocal function matchParticipantKey')
reader = section('local function readLastLetterVisibleWord()', '\n\tWordHelper.ReadVisibleGameWord')
harness = '''
local Settings = {wpm = 180, legitAutoType = false, legitMinWPM = 160, legitMaxWPM = 180}
local WordHelper = {usedWords = {}, pendingUsedWords = {}, usedCount = 0,
    lastVisualWord = "", lastTypedAction = "", lastTypingActivity = 0}
local refreshed, chipUpdates = 0, 0
local function normalizeLetters(s) return s:lower():gsub("[^a-z]", "") end
local function updateUsedChip() chipUpdates += 1 end
local function scheduleRefresh() refreshed += 1 end
local markUsed
''' + interval + '\n' + used + '''
local duration, wpm = WordHelper.TypingInterval()
assert(wpm == 180 and math.abs(duration - 60 / 900) < 0.000001)
Settings.wpm = 300
assert(select(2, WordHelper.TypingInterval()) == 300, "normal WPM not shared")
Settings.legitAutoType = true
local varied = {}
for _ = 1, 1000 do
    local delay, chosen = WordHelper.TypingInterval()
    assert(chosen >= 160 and chosen <= 180)
    assert(math.abs(delay - 60 / (chosen * 5)) < 0.000001)
    varied[chosen] = true
end
local different = 0
for _ in pairs(varied) do different += 1 end
assert(different > 1, "range must vary")
Settings.legitMinWPM, Settings.legitMaxWPM = 170, 170
assert(select(2, WordHelper.TypingInterval()) == 170)
markUsed("Yesterdayness")
markUsed("yesterdayness")
assert(WordHelper.usedCount == 1 and WordHelper.usedWords.yesterdayness, "rare submissions and dedup")
assert(chipUpdates == 1 and refreshed == 1, "used chip/filter refresh")
markUsed("a")
assert(WordHelper.usedCount == 1)

local currentPlaceId, LAST_LETTER_PLACE_ID = 1, 1
local root = {Text = ""}
local children = {}
root.GetDescendants = function() return children end
local playerGui = {FindFirstChild = function(_, name)
    if name == "CurrentWord" then return root end
end}
local function guiObjectVisible() return true end
local function visibleText(object) return object.Text or "" end
local Vector2 = {new = function(x, y) return {X = x, Y = y} end}
local userInputService = {GetFocusedTextBox = function() return nil end}
local searchBox = {}
local function isGameTextBox() return false end
local lastQuery = nil
local function applyDetectedQuery(word) lastQuery = word end
''' + reader + '''
children = {
    {Text = "b", LayoutOrder = 0, AbsolutePosition = {X = 20, Y = 0}},
    {Text = "a", LayoutOrder = 99, AbsolutePosition = {X = 10, Y = 2}},
    {Text = "c", LayoutOrder = -2, AbsolutePosition = {X = 30, Y = 1}},
}
assert(readLastLetterVisibleWord() == "abc", "screen order must beat mixed LayoutOrder")
root.Text = "actual"
assert(readLastLetterVisibleWord() == "actual", "whole word must beat child animation")
root.Text = "abc"
pollVisibleGameWord()
assert(lastQuery == nil, "first transient sample must not appear")
pollVisibleGameWord()
assert(lastQuery == "abc", "stable sample must appear")
root.Text = "cba"
pollVisibleGameWord()
assert(lastQuery == "abc", "transient reversed sample must not appear")
root.Text = "abcd"
pollVisibleGameWord()
pollVisibleGameWord()
assert(lastQuery == "abcd")
print("Zenith GUI logic checks passed: WPM, range, used memory, visual order/stability")
'''
with tempfile.TemporaryDirectory(prefix='zenith-gui-tests-') as directory:
    path = Path(directory) / 'gui_logic.luau'
    path.write_text(harness)
    subprocess.run([sys.argv[1], str(path)], check=True)
