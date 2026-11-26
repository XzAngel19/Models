#!/usr/bin/env python3
"""Run the actual Last Letter auto-type branch with deterministic Luau mocks.
Usage: python3 tools/test_zenith_last_letter.py /path/to/luau
These are logic tests, not a Roblox/executor integration test.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

source = (Path(__file__).resolve().parents[1] / "ZenithVocabulary.txt").read_text()
start = source.index('\t\tif currentPlaceId == LAST_LETTER_PLACE_ID then', source.index('typeWordIntoGame = function'))
end = source.index('\n\n\t\tlocal textActions', start)
branch = source[start:end]
harness = '''
local currentPlaceId, LAST_LETTER_PLACE_ID = 1, 1
local searchBox, Config = {}, {Muted = 0}
local visible, clock, sends, acknowledge, cancel = "", 0, 0, true, false
local os = {clock = function() return clock end}
local task = {wait = function() clock += 0.1 end}
local userInputService = {GetFocusedTextBox = function() return nil end}
local WordHelper = {autoTypeGeneration = 0, inputEpoch = 0}
local function normalizeLetters(s) return string.lower(s):gsub("[^a-z]", "") end
local function readLastLetterVisibleWord() return visible end
local function isGameTextBox() return false end
local function setStatus() end
WordHelper.AutoTypeStillValid = function(generation, epoch, validator)
    return not cancel and generation == WordHelper.autoTypeGeneration
        and epoch == WordHelper.inputEpoch and validator()
end
WordHelper.SendUniversalAction = function(action)
    sends += 1
    if acknowledge then visible ..= action end
    return true
end
WordHelper.BeginAutoTyping = function(actions, sender, word, method, validator)
    WordHelper.autoTypeGeneration += 1
    for _, action in ipairs(actions) do
        if not validator() or not sender(action) then return false end
    end
    return true
end
local function attempt(word)
''' + branch + '''
end
local function reset(text)
    visible, clock, sends, acknowledge, cancel = text, 0, 0, true, false
end
reset("")
assert(attempt("apple") == true and visible == "apple" and sends == 5, "empty entry")
reset("ap")
assert(attempt("apple") == true and visible == "apple" and sends == 3, "prefix suffix")
reset("apple")
assert(attempt("apple") == true and sends == 0, "already complete")
reset("pear")
assert(attempt("apple") == false and sends == 0, "mismatched prefix")
reset(nil)
assert(attempt("apple") == false and sends == 0, "unavailable entry")
reset("")
acknowledge = false
assert(attempt("apple") == false and sends == 1 and visible == "", "unacknowledged input must stop")
reset("")
cancel = true
assert(attempt("apple") == false and sends == 1, "cancellation during acknowledgment")
print("7 Last Letter auto-type logic tests passed")
'''
with tempfile.TemporaryDirectory(prefix="zenith-tests-") as directory:
    path = Path(directory) / "last_letter.luau"
    path.write_text(harness)
    subprocess.run([sys.argv[1], str(path)], check=True)
