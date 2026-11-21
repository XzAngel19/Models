-- ============================================================================
-- Luau Mini IDE — a full in-game code editor for Roblox executors (client side)
-- Single file. Only Instances + UserInputService + RunService + TweenService.
-- Every entry point runs under xpcall. Re-executing the script cleans up the
-- previous instance through a shared guard in getgenv().
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Character-level (UTF-8 aware) helpers. Columns everywhere are 1-based
--    character columns. Plain Lua, no dependency on the utf8 library.
-- ----------------------------------------------------------------------------
local UTF8 = {}

local function codepointStep(b)
	if b < 0x80 then return 1 elseif b >= 0xF0 then return 4 elseif b >= 0xE0 then return 3 else return 2 end
end

function UTF8.len(s)
	local n = 0
	for i = 1, #s do
		local b = string.byte(s, i)
		if b < 0x80 or b >= 0xC0 then n = n + 1 end -- count lead bytes only
	end
	return n
end

-- Byte index of the codepoint that starts at 0-based character index `charIndex`.
function UTF8.charToByte(s, charIndex)
	local i = 1
	for _ = 1, charIndex do
		local b = string.byte(s, i)
		if not b then return #s + 1 end
		i = i + codepointStep(b)
	end
	return i
end

-- Inclusive 1-based character columns.
function UTF8.sub(s, fromChar, toChar)
	if fromChar > toChar then return "" end
	local a = UTF8.charToByte(s, fromChar - 1)
	local b = UTF8.charToByte(s, toChar) - 1
	return string.sub(s, a, b)
end

function UTF8.byteToCharCol(s, bytePos) -- 1-based char column of byte position
	local col, i = 1, 1
	while i < bytePos and i <= #s do
		i = i + codepointStep(string.byte(s, i))
		col = col + 1
	end
	return col
end

local TAB_WIDTH = 4
UTF8.TAB_WIDTH = TAB_WIDTH

-- Expand tabs to spaces. Returns expanded string, map[charCol]=displayCol (1-based),
-- byteMap[charCol]=byte offset of prefix end, total char count.
function UTF8.expandTabs(s)
	local out, map, byteMap = {}, {}, {}
	local dcol, blen = 1, 0
	local ccol = 1
	local i = 1
	while i <= #s do
		local b = string.byte(s, i)
		local step = codepointStep(b)
		map[ccol] = dcol
		byteMap[ccol] = blen
		if b == 9 then -- \t
			local spaces = TAB_WIDTH - ((dcol - 1) % TAB_WIDTH)
			out[#out + 1] = string.rep(" ", spaces)
			dcol = dcol + spaces
			blen = blen + spaces
			ccol = ccol + 1
		else
			local chunk = string.sub(s, i, i + step - 1)
			out[#out + 1] = chunk
			dcol = dcol + 1
			blen = blen + step
			ccol = ccol + 1
		end
		i = i + step
	end
	map[ccol] = dcol
	byteMap[ccol] = blen
	return table.concat(out), map, byteMap, ccol - 1
end

-- ----------------------------------------------------------------------------
-- 2. Local utilities
-- ----------------------------------------------------------------------------
-- defensive: some minimal environments lack math.clamp
if not math.clamp then
	math.clamp = function(v, lo, hi)
		if v < lo then return lo end
		if v > hi then return hi end
		return v
	end
end

local Util = {}

function Util.clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

function Util.splitLines(text)
	-- Normalizes CRLF/CR/LF and always returns at least one line.
	local lines = {}
	local start = 1
	text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
	while true do
		local s, e = string.find(text, "\n", start, true)
		if not s then
			lines[#lines + 1] = text:sub(start)
			break
		end
		lines[#lines + 1] = text:sub(start, s - 1)
		start = e + 1
	end
	return lines
end

-- Splice `repl` into `lines`, replacing `count` entries starting at `first`.
-- Moves the tail in the safe direction so indices never get clobbered.
function Util.spliceLines(lines, first, count, repl)
	repl = repl or {}
	local n = #lines
	local delta = #repl - count
	local newLen = n + delta
	if delta >= 0 then
		for read = n, first + count, -1 do
			lines[read + delta] = lines[read]
		end
	else
		for read = first + count, n do
			lines[read + delta] = lines[read]
		end
	end
	for i = 1, #repl do
		lines[first + i - 1] = repl[i]
	end
	for i = newLen + 1, n do
		lines[i] = nil
	end
	return lines
end

-- Extent of `text` inserted at (sLine, sCol); returns endLine, endCol.
function Util.textExtent(sLine, sCol, text)
	local parts = Util.splitLines(text)
	if #parts == 1 then
		return sLine, sCol + UTF8.len(parts[1])
	end
	return sLine + #parts - 1, UTF8.len(parts[#parts]) + 1
end

function Util.comma(n)
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function Util.trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- ----------------------------------------------------------------------------
-- 3. Maid — tracks cleanup tasks (functions, connections, instances, threads)
-- ----------------------------------------------------------------------------
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _items = {}, _cleaned = false }, Maid)
end

function Maid:Give(item)
	if self._cleaned then
		self:_clean(item)
		return item
	end
	self._items[#self._items + 1] = item
	return item
end

function Maid:GiveTask(fn)
	self._items[#self._items + 1] = fn
	return fn
end

function Maid:_clean(item)
	local t = typeof(item)
	if t == "function" then
		pcall(item)
	elseif t == "RBXScriptConnection" then
		pcall(function() item:Disconnect() end)
	elseif t == "Instance" then
		pcall(function() item:Destroy() end)
	elseif t == "thread" then
		pcall(task.cancel, item)
	elseif t == "table" and item ~= nil then
		if typeof(item.Destroy) == "function" then
			pcall(function() item:Destroy() end)
		elseif typeof(item.DoCleaning) == "function" then
			pcall(function() item:DoCleaning() end)
		end
	end
end

function Maid:DoCleaning()
	if self._cleaned then return end
	self._cleaned = true
	for i = #self._items, 1, -1 do
		self:_clean(self._items[i])
		self._items[i] = nil
	end
end

-- ----------------------------------------------------------------------------
-- 4. TextBuffer — array of lines, UTF-8 char columns, O(tail) splices
-- ----------------------------------------------------------------------------
local TextBuffer = {}
TextBuffer.__index = TextBuffer

function TextBuffer.new()
	return setmetatable({ Lines = { "" }, version = 0 }, TextBuffer)
end

function TextBuffer:GetLineCount()
	return #self.Lines
end

function TextBuffer:GetLine(index)
	return self.Lines[index] or ""
end

function TextBuffer:SetLines(lines)
	if #lines == 0 then lines = { "" } end
	self.Lines = lines
	self.version = self.version + 1
end

function TextBuffer:SetText(text)
	self:SetLines(Util.splitLines(text))
end

function TextBuffer:GetText()
	return table.concat(self.Lines, "\n")
end

function TextBuffer:GetLineLength(index) -- in characters
	return UTF8.len(self.Lines[index] or "")
end

function TextBuffer:GetTextRange(sLine, sCol, eLine, eCol)
	if sLine > eLine or (sLine == eLine and sCol >= eCol) then
		return ""
	end
	if sLine == eLine then
		return UTF8.sub(self.Lines[sLine], sCol, eCol - 1)
	end
	local parts = { UTF8.sub(self.Lines[sLine], sCol, UTF8.len(self.Lines[sLine])) }
	for i = sLine + 1, eLine - 1 do
		parts[#parts + 1] = self.Lines[i]
	end
	if eCol > 1 then
		parts[#parts + 1] = UTF8.sub(self.Lines[eLine], 1, eCol - 1)
	else
		parts[#parts + 1] = "" -- range ends exactly at a line boundary: keep the trailing newline
	end
	return table.concat(parts, "\n")
end

-- Inserts text (may contain newlines); returns endLine, endCol of the insertion.
function TextBuffer:InsertText(line, col, text)
	text = tostring(text):gsub("\r\n", "\n"):gsub("\r", "\n")
	local cur = self.Lines[line]
	local startByte = UTF8.charToByte(cur, col - 1)
	local before, after = cur:sub(1, startByte - 1), cur:sub(startByte)
	local chunks = Util.splitLines(text)
	if #chunks == 1 then
		self.Lines[line] = before .. chunks[1] .. after
		self.version = self.version + 1
		return line, col + UTF8.len(chunks[1])
	end
	local repl = { before .. chunks[1] }
	for i = 2, #chunks - 1 do
		repl[#repl + 1] = chunks[i]
	end
	repl[#repl + 1] = chunks[#chunks] .. after
	Util.spliceLines(self.Lines, line, 1, repl)
	self.version = self.version + 1
	return line + #chunks - 1, UTF8.len(chunks[#chunks]) + 1
end

-- Deletes [sLine,sCol .. eLine,eCol); returns the deleted text.
function TextBuffer:DeleteRange(sLine, sCol, eLine, eCol)
	local deleted = self:GetTextRange(sLine, sCol, eLine, eCol)
	if deleted == "" then return "" end
	local sByte = UTF8.charToByte(self.Lines[sLine], sCol - 1)
	local eByte = UTF8.charToByte(self.Lines[eLine], eCol - 1)
	local merged = self.Lines[sLine]:sub(1, sByte - 1) .. self.Lines[eLine]:sub(eByte)
	Util.spliceLines(self.Lines, sLine, eLine - sLine + 1, { merged })
	self.version = self.version + 1
	return deleted
end

-- Ordered comparison: -1 / 0 / 1
function TextBuffer.posCompare(aLine, aCol, bLine, bCol)
	if aLine ~= bLine then return aLine < bLine and -1 or 1 end
	if aCol ~= bCol then return aCol < bCol and -1 or 1 end
	return 0
end

-- ----------------------------------------------------------------------------
-- 5. UndoStack — grouped transactions of plain {sLine,sCol,oldText,newText}
--    edits. Typing groups coalesce; replace-all undoes/redos in reverse
--    document order so original coordinates stay valid.
-- ----------------------------------------------------------------------------
local UndoStack = {}
UndoStack.__index = UndoStack

local MERGE_WINDOW = 1.2 -- seconds of slack for grouping consecutive typing

function UndoStack.new()
	return setmetatable({ undo = {}, redo = {}, limit = 300 }, UndoStack)
end

-- mergeKind: "Typing" | "Backspace" | "Delete" | nil (never merge)
function UndoStack:Push(edit, mergeKind)
	edit.sLine = edit.sLine or 1
	edit.sCol = edit.sCol or 1
	edit.oldText = edit.oldText or ""
	edit.newText = edit.newText or ""
	self.redo = {}
	local now = os.clock()
	local top = self.undo[#self.undo]
	if top and mergeKind and top.mergeKind == mergeKind and (now - top.time) < MERGE_WINDOW then
		local lastEdit = top.edits[#top.edits]
		if mergeKind == "Typing" then
			local l, c = Util.textExtent(lastEdit.sLine, lastEdit.sCol, lastEdit.newText)
			if l == edit.sLine and c == edit.sCol and not edit.newText:find("\n", 1, true) then
				lastEdit.newText = lastEdit.newText .. edit.newText
				top.time = now
				return top
			end
		elseif mergeKind == "Backspace" then
			-- deleting backward: new edit ends exactly where the previous one started
			local l, c = Util.textExtent(edit.sLine, edit.sCol, edit.oldText)
			if l == lastEdit.sLine and c == lastEdit.sCol and not edit.oldText:find("\n", 1, true) then
				lastEdit.sLine, lastEdit.sCol = edit.sLine, edit.sCol
				lastEdit.oldText = edit.oldText .. lastEdit.oldText
				top.time = now
				return top
			end
		elseif mergeKind == "Delete" then
			-- forward delete: new edit starts exactly where the previous one ended
			local l, c = Util.textExtent(lastEdit.sLine, lastEdit.sCol, lastEdit.oldText)
			if l == edit.sLine and c == edit.sCol and not edit.oldText:find("\n", 1, true) then
				lastEdit.oldText = lastEdit.oldText .. edit.oldText
				top.time = now
				return top
			end
		end
	end
	local trans = { edits = { edit }, mergeKind = mergeKind, time = now }
	self.undo[#self.undo + 1] = trans
	if #self.undo > self.limit then
		table.remove(self.undo, 1)
	end
	return trans
end

function UndoStack:HasUndo()
	return #self.undo > 0
end

function UndoStack:HasRedo()
	return #self.redo > 0
end

local function applyInverse(buffer, edit) -- for undo: remove newText, restore oldText
	local endL, endC = Util.textExtent(edit.sLine, edit.sCol, edit.newText)
	buffer:DeleteRange(edit.sLine, edit.sCol, endL, endC)
	buffer:InsertText(edit.sLine, edit.sCol, edit.oldText)
end

local function applyForward(buffer, edit) -- for redo: remove oldText, insert newText
	local endL, endC = Util.textExtent(edit.sLine, edit.sCol, edit.oldText)
	buffer:DeleteRange(edit.sLine, edit.sCol, endL, endC)
	buffer:InsertText(edit.sLine, edit.sCol, edit.newText)
end

-- Storage order is APPLICATION order. Undo replays exact inverse operations
-- in reverse application order (each inverse restores its pre-edit state),
-- while redo replays the forward operations again in storage order. Both keep
-- positions valid by construction, even for length-changing batch edits.
function UndoStack:Undo(buffer)
	local trans = table.remove(self.undo)
	if not trans then return nil end
	for i = #trans.edits, 1, -1 do
		applyInverse(buffer, trans.edits[i])
	end
	self.redo[#self.redo + 1] = trans
	return trans
end

function UndoStack:Redo(buffer)
	local trans = table.remove(self.redo)
	if not trans then return nil end
	for i = 1, #trans.edits do
		applyForward(buffer, trans.edits[i])
	end
	self.undo[#self.undo + 1] = trans
	return trans
end

-- Build one atomic transaction from many edits (replace-all). Edits must be
-- recorded in APPLICATION order; undo replays exact inverses in reverse.
function UndoStack:PushBatch(edits)
	self.redo = {}
	local trans = { edits = edits, mergeKind = nil, time = os.clock() }
	self.undo[#self.undo + 1] = trans
	if #self.undo > self.limit then
		table.remove(self.undo, 1)
	end
	return trans
end

-- ----------------------------------------------------------------------------
-- 6. Tokenizer — hand-written Luau lexer with per-line state cache.
--    State key: "n" normal, "sN" inside long string at level N, "cN" inside
--    long comment at level N. Tokens carry byte ranges over the raw line and
--    cover it completely (gaps become "gap" tokens).
-- ----------------------------------------------------------------------------
local KEYWORDS = {
	["and"] = true, ["break"] = true, ["continue"] = true, ["do"] = true,
	["else"] = true, ["elseif"] = true, ["end"] = true, ["false"] = true,
	["for"] = true, ["function"] = true, ["if"] = true, ["in"] = true,
	["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
	["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
	["until"] = true, ["while"] = true,
}

local BUILTINS = {
	print = true, warn = true, error = true, assert = true, type = true,
	typeof = true, tostring = true, tonumber = true, select = true,
	pairs = true, ipairs = true, next = true, unpack = true, rawget = true,
	rawset = true, rawequal = true, rawlen = true, setmetatable = true,
	getmetatable = true, pcall = true, xpcall = true, require = true,
	tick = true, time = true, wait = true, spawn = true, delay = true,
	collectgarbage = true, gcinfo = true, newproxy = true, ypcall = true,
	game = true, workspace = true, script = true, Instance = true,
	Color3 = true, BrickColor = true, Enum = true, Ray = true, UDim = true,
	UDim2 = true, Vector2 = true, Vector3 = true, CFrame = true,
	TweenInfo = true, Random = true, DateTime = true, Drawing = true,
	NumberRange = true, NumberSequence = true, ColorSequence = true,
	table = true, string = true, math = true, os = true, io = true,
	coroutine = true, bit32 = true, utf8 = true, task = true, debug = true,
	_G = true, _ENV = true, shared = true, settings = true,
}

local MULTI_OPS = { "...", "..=", "//=", "..", "==", "~=", "<=", ">=", "::", "+=", "-=", "*=", "/=", "%=", "^=", "//" }

-- returns level, index after opening brackets, or nil
local function matchLongOpen(line, i)
	if string.byte(line, i) ~= 91 then return nil end -- '['
	local j = i + 1
	local level = 0
	while string.byte(line, j) == 61 do
		level = level + 1
		j = j + 1
	end
	if string.byte(line, j) == 91 then
		return level, j + 1
	end
	return nil
end

local function findLongClose(line, fromByte, level)
	local needle = "]" .. string.rep("=", level) .. "]"
	return string.find(line, needle, fromByte, true)
end

local function isDigitByte(b)
	return b ~= nil and b >= 48 and b <= 57
end

local function scanNumber(line, i)
	local len = #line
	local b = string.byte(line, i)
	-- hex / binary
	if b == 48 then -- '0'
		local b2 = string.byte(line, i + 1)
		if b2 == 120 or b2 == 88 then -- x X
			local j = i + 2
			local seen = false
			while j <= len do
				local c = string.byte(line, j)
				if (c >= 48 and c <= 57) or (c >= 65 and c <= 70) or (c >= 97 and c <= 102) or c == 95 then
					j = j + 1
					seen = true
				else
					break
				end
			end
			return seen and j or i + 1
		elseif b2 == 98 or b2 == 66 then -- b B
			local j = i + 2
			local seen = false
			while j <= len do
				local c = string.byte(line, j)
				if c == 48 or c == 49 or c == 95 then
					j = j + 1
					seen = true
				else
					break
				end
			end
			return seen and j or i + 1
		end
	end
	local j = i
	while j <= len do
		local c = string.byte(line, j)
		if isDigitByte(c) or c == 95 then j = j + 1 else break end
	end
	if string.byte(line, j) == 46 then -- '.'
		j = j + 1
		while j <= len do
			local c = string.byte(line, j)
			if isDigitByte(c) or c == 95 then j = j + 1 else break end
		end
	end
	local c = string.byte(line, j)
	if c == 101 or c == 69 then -- e E
		local m = j + 1
		local sign = string.byte(line, m)
		if sign == 43 or sign == 45 then m = m + 1 end
		local digits = 0
		while m <= len do
			local d = string.byte(line, m)
			if isDigitByte(d) or d == 95 then m = m + 1 digits = digits + 1 else break end
		end
		if digits > 0 then j = m end -- otherwise leave 'e' alone
	end
	return j
end

local function fillGaps(tokens, len)
	local out = {}
	local prev = 1
	for _, tok in ipairs(tokens) do
		-- drop degenerate tokens (can occur for empty lines inside long strings)
		if tok.s >= 1 and tok.e >= tok.s then
			if tok.s > prev then
				out[#out + 1] = { s = prev, e = tok.s - 1, t = "gap" }
			end
			out[#out + 1] = tok
			prev = tok.e + 1
		end
	end
	if prev <= len then
		out[#out + 1] = { s = prev, e = len, t = "gap" }
	end
	return out
end

-- Tokenize one line given an in-state key. Returns tokens, outKey.
local function tokenizeLine(line, inKey)
	local len = #line
	local tokens = {}
	local i = 1
	local outKey = "n"

	local function finish(outState)
		return fillGaps(tokens, len), outState or "n"
	end

	-- Continue a multi-line string/comment from the previous line.
	if inKey and inKey ~= "n" then
		local kind = inKey:sub(1, 1)
		local level = tonumber(inKey:sub(2)) or 0
		local s, e = findLongClose(line, 1, level)
		if s then
			tokens[#tokens + 1] = { s = 1, e = e, t = (kind == "s") and "string" or "comment" }
			i = e + 1
		else
			tokens[#tokens + 1] = { s = 1, e = len, t = (kind == "s") and "string" or "comment" }
			return finish(inKey)
		end
	end

	while i <= len do
		local b = string.byte(line, i)

		-- comments: -- [[ ]] long or line
		if b == 45 and string.byte(line, i + 1) == 45 then
			local level, afterOpen = matchLongOpen(line, i + 2)
			if level then
				local s, e = findLongClose(line, afterOpen, level)
				if s then
					tokens[#tokens + 1] = { s = i, e = e, t = "comment" }
					i = e + 1
				else
					tokens[#tokens + 1] = { s = i, e = len, t = "comment" }
					return finish("c" .. level)
				end
			else
				tokens[#tokens + 1] = { s = i, e = len, t = "comment" }
				return finish("n")
			end

		-- long string opened directly
		elseif b == 91 then
			local level, afterOpen = matchLongOpen(line, i)
			if level then
				local s, e = findLongClose(line, afterOpen, level)
				if s then
					tokens[#tokens + 1] = { s = i, e = e, t = "string" }
					i = e + 1
				else
					tokens[#tokens + 1] = { s = i, e = len, t = "string" }
					return finish("s" .. level)
				end
			else
				tokens[#tokens + 1] = { s = i, e = i, t = "operator" }
				i = i + 1
			end

		-- short strings with escape awareness
		elseif b == 34 or b == 39 then
			local quote = b
			local j = i + 1
			while j <= len do
				local bj = string.byte(line, j)
				if bj == 92 then -- backslash escape consumes next byte
					j = j + 2
				elseif bj == quote then
					break
				else
					j = j + 1
				end
			end
			local e = math.min(j, len)
			tokens[#tokens + 1] = { s = i, e = e, t = "string" }
			i = e + 1

		-- numbers
		elseif isDigitByte(b) or (b == 46 and isDigitByte(string.byte(line, i + 1))) then
			local e = scanNumber(line, i)
			tokens[#tokens + 1] = { s = i, e = e - 1, t = "number" }
			i = e

		-- identifiers / keywords / builtins / function calls
		elseif (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95 then
			local j = i + 1
			while j <= len do
				local bj = string.byte(line, j)
				if isDigitByte(bj) or (bj >= 65 and bj <= 90) or (bj >= 97 and bj <= 122) or bj == 95 then
					j = j + 1
				else
					break
				end
			end
			local word = line:sub(i, j - 1)
			local t
			if KEYWORDS[word] then
				t = "keyword"
			elseif BUILTINS[word] then
				t = "builtin"
			else
				-- identifier immediately (or with spaces) followed by '(' → function
				local k = j
				while string.byte(line, k) == 32 do k = k + 1 end
				if string.byte(line, k) == 40 then
					t = "function"
				else
					t = "ident"
				end
			end
			tokens[#tokens + 1] = { s = i, e = j - 1, t = t }
			i = j

		-- multi-char operators (longest match wins)
		else
			local matched
			for _, op in ipairs(MULTI_OPS) do
				if line:sub(i, i + #op - 1) == op then
					matched = op
					break
				end
			end
			if matched then
				tokens[#tokens + 1] = { s = i, e = i + #matched - 1, t = "operator" }
				i = i + #matched
			elseif b == 32 or b == 9 or b == 13 then
				tokens[#tokens + 1] = { s = i, e = i, t = "gap" }
				i = i + 1
			else
				tokens[#tokens + 1] = { s = i, e = i, t = "operator" }
				i = i + 1
			end
		end
	end
	return finish("n")
end

local Tokenizer = {}
Tokenizer.__index = Tokenizer

function Tokenizer.new()
	return setmetatable({ LineCache = {}, FirstDirty = 1 }, Tokenizer)
end

function Tokenizer:InvalidateFrom(line)
	line = math.max(1, line or 1)
	if self.FirstDirty > line then
		self.FirstDirty = line
	end
end

function Tokenizer:InvalidateAll()
	for k in pairs(self.LineCache) do
		self.LineCache[k] = nil
	end
	self.FirstDirty = 1
end

function Tokenizer:Prune(lineCount)
	for k in pairs(self.LineCache) do
		if k > lineCount then self.LineCache[k] = nil end
	end
	if self.FirstDirty > lineCount + 1 then
		self.FirstDirty = lineCount + 1
	end
end

-- Sync cache from FirstDirty; stops early once propagated state matches the
-- cached in-state again, so cost is proportional to what actually changed.
function Tokenizer:Sync(buffer, minTarget)
	minTarget = math.max(1, minTarget or 1)
	local lineCount = buffer:GetLineCount()
	local i = self.FirstDirty
	if i > lineCount + 1 then
		-- buffer shrank underneath the cache: rescan from the top
		self:InvalidateAll()
		i = 1
	end
	if i > lineCount then
		self.FirstDirty = lineCount + 1
		return
	end
	local stateKey = (i <= 1) and "n" or ((self.LineCache[i] and self.LineCache[i].inKey) or "n")
	while i <= lineCount do
		local line = buffer:GetLine(i)
		local tokens, outKey = tokenizeLine(line, stateKey)
		local cache = self.LineCache[i]
		local unchanged = cache ~= nil
			and cache.line == line
			and cache.inKey == stateKey
			and cache.outKey == outKey
		self.LineCache[i] = { line = line, inKey = stateKey, tokens = tokens, outKey = outKey }
		i = i + 1
		stateKey = outKey
		local nextCache = self.LineCache[i]
		if unchanged and (i - 1) >= minTarget and nextCache ~= nil and nextCache.inKey == stateKey then
			self.FirstDirty = lineCount + 1
			return
		end
	end
	self.FirstDirty = lineCount + 1
end

function Tokenizer:GetLineTokens(buffer, line)
	if line < 1 then return {} end
	self:Sync(buffer, line)
	local c = self.LineCache[line]
	return c and c.tokens or {}
end

function Tokenizer:GetLineOutState(buffer, line)
	self:Sync(buffer, line)
	local c = self.LineCache[line]
	return c and c.outKey or "n"
end

local function escapeRichText(s)
	s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return s
end

-- Build a RichText string; `colors` maps token type → "#rrggbb".
-- byteLimit optionally truncates the rendered prefix at a byte boundary.
function Tokenizer.BuildRichText(tokens, line, colors, byteLimit)
	byteLimit = byteLimit or #line
	local parts = {}
	for _, tok in ipairs(tokens) do
		if tok.s > byteLimit then break end
		local e = math.min(tok.e, byteLimit)
		local seg = escapeRichText(line:sub(tok.s, e))
		local color = colors[tok.t]
		if color then
			parts[#parts + 1] = '<font color="' .. color .. '">' .. seg .. "</font>"
		else
			parts[#parts + 1] = seg
		end
	end
	return table.concat(parts)
end

-- ----------------------------------------------------------------------------
-- 7. Finder — literal substring search (never patterns), plain-find based.
--    Case-insensitive matching lowercases both sides (ASCII-precise).
-- ----------------------------------------------------------------------------
local Finder = {}
Finder.__index = Finder

function Finder.new()
	return setmetatable({
		query = "",
		replacement = "",
		caseSensitive = false,
		wholeWord = false,
		matches = {}, -- { line, col (char), len (chars) } ascending
		index = 0,
	}, Finder)
end

local function isWordByte(b)
	return b == 95
		or (b ~= nil and ((b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122)))
end

-- Scan a single buffer line and append matches. Returns nothing; fills out.
local function scanFinderLine(line, needle, caseSensitive, wholeWord, out, lineIndex)
	local hay = caseSensitive and line or line:lower()
	local len = #hay
	local init = 1
	while init <= len do
		local s, e = string.find(hay, needle, init, true)
		if not s then break end
		local isWord = true
		if wholeWord then
			local before = string.byte(line, s - 1)
			local after = string.byte(line, e + 1)
			if isWordByte(before) or isWordByte(after) then
				isWord = false
			end
		end
		if isWord then
			local col = UTF8.byteToCharCol(line, s)
			out[#out + 1] = { line = lineIndex, col = col, len = UTF8.len(line:sub(s, e)) }
		end
		init = e + 1 -- non-overlapping (replace-all safe)
	end
end

function Finder:Refresh(buffer)
	self.matches = {}
	self.index = 0
	if self.query == "" then
		return 0
	end
	local needle = self.caseSensitive and self.query or self.query:lower()
	for i = 1, buffer:GetLineCount() do
		scanFinderLine(buffer:GetLine(i), needle, self.caseSensitive, self.wholeWord, self.matches, i)
	end
	return #self.matches
end

-- Position-aware navigation: returns the next match index (wrapping).
function Finder:Next(fromLine, fromCol)
	if #self.matches == 0 then return nil end
	for i, m in ipairs(self.matches) do
		if (m.line > fromLine) or (m.line == fromLine and m.col >= fromCol) then
			self.index = i
			return m
		end
	end
	self.index = 1
	return self.matches[1]
end

function Finder:Prev(fromLine, fromCol)
	if #self.matches == 0 then return nil end
	for i = #self.matches, 1, -1 do
		local m = self.matches[i]
		if (m.line < fromLine) or (m.line == fromLine and m.col < fromCol) then
			self.index = i
			return m
		end
	end
	self.index = #self.matches
	return self.matches[#self.matches]
end

function Finder:GetCurrent()
	return self.matches[self.index]
end

-- One undo transaction for the whole operation.
function Finder:ReplaceAll(buffer, undoStack, replacement)
	self:Refresh(buffer)
	local count = #self.matches
	if count == 0 then return 0 end
	local edits = {}
	for i = #self.matches, 1, -1 do
		local m = self.matches[i]
		local original = buffer:GetTextRange(m.line, m.col, m.line, m.col + m.len)
		buffer:DeleteRange(m.line, m.col, m.line, m.col + m.len)
		buffer:InsertText(m.line, m.col, replacement)
		-- record in APPLICATION order (descending positions); undo replays the
		-- exact inverse sequence, keeping every position valid by construction
		edits[#edits + 1] = { sLine = m.line, sCol = m.col, oldText = original, newText = replacement }
	end
	undoStack:PushBatch(edits)
	self:Refresh(buffer)
	return count
end

function Finder:ReplaceCurrent(buffer, undoStack, replacement)
	local m = self:GetCurrent()
	if not m then return false end
	local original = buffer:GetTextRange(m.line, m.col, m.line, m.col + m.len)
	buffer:DeleteRange(m.line, m.col, m.line, m.col + m.len)
	buffer:InsertText(m.line, m.col, replacement)
	undoStack:PushBatch({ { sLine = m.line, sCol = m.col, oldText = original, newText = replacement } })
	self:Refresh(buffer)
	return true
end

-- ----------------------------------------------------------------------------
-- 8. Code folding — token-based block detection (string/comment safe).
--    Blocks: function / if / for / while / repeat / bare do … end|until.
-- ----------------------------------------------------------------------------

local function computeFolds(buffer, tokenizer)
	local count = buffer:GetLineCount()
	tokenizer:Sync(buffer, count)
	local folds, stack = {}, {}
	for li = 1, count do
		local line = buffer:GetLine(li)
		local cache = tokenizer.LineCache[li]
		local words = {}
		if cache then
			for _, t in ipairs(cache.tokens) do
				if t.t == "keyword" then
					words[#words + 1] = line:sub(t.s, t.e)
				end
			end
		end
		local hasForWhile = false
		for _, w in ipairs(words) do
			if w == "for" or w == "while" then hasForWhile = true break end
		end
		for _, w in ipairs(words) do
			if w == "function" or w == "if" or w == "for" or w == "while" or w == "repeat" then
				stack[#stack + 1] = li
			elseif w == "do" then
				if not hasForWhile then
					stack[#stack + 1] = li
				end
			elseif w == "end" or w == "until" then
				local top = table.remove(stack)
				if top and top < li then
					folds[#folds + 1] = { startLine = top, endLine = li }
				end
			end
		end
	end
	table.sort(folds, function(a, b) return a.startLine < b.startLine end)
	return folds
end

-- Indent width in characters (tabs count as TabWidth) of a raw line.
local function indentOf(line)
	local col = 0
	for i = 1, #line do
		local b = string.byte(line, i)
		if b == 9 then
			col = col + TAB_WIDTH
		elseif b == 32 then
			col = col + 1
		else
			break
		end
	end
	return col
end

-- ----------------------------------------------------------------------------
-- 9. Keyboard map (US layout) — built lazily so Enum stays untouched in tests
-- ----------------------------------------------------------------------------
local keymapCache
local function getKeymap()
	if keymapCache then return keymapCache end
	local map = {}
	for letter = 65, 90 do
		local ch = string.char(letter)
		local key = Enum.KeyCode[ch]
		if key then
			map[key] = { lower = ch:lower(), upper = ch }
		end
	end
	local pairs2 = {
		{ "One", "1", "!" }, { "Two", "2", "@" }, { "Three", "3", "#" },
		{ "Four", "4", "$" }, { "Five", "5", "%" }, { "Six", "6", "^" },
		{ "Seven", "7", "&" }, { "Eight", "8", "*" }, { "Nine", "9", "(" },
		{ "Zero", "0", ")" }, { "Minus", "-", "_" }, { "Equals", "=", "+" },
		{ "LeftBracket", "[", "{" }, { "RightBracket", "]", "}" },
		{ "BackSlash", "\\", "|" }, { "Semicolon", ";", ":" },
		{ "Quote", "'", '"' }, { "Comma", ",", "<" }, { "Period", ".", ">" },
		{ "Slash", "/", "?" }, { "Backquote", "`", "~" },
	}
	for _, p in ipairs(pairs2) do
		local key = Enum.KeyCode[p[1]]
		if key then
			map[key] = { lower = p[2], upper = p[3] }
		end
	end
	if Enum.KeyCode.Space then
		map[Enum.KeyCode.Space] = { lower = " ", upper = " " }
	end
	keymapCache = map
	return map
end

-- ----------------------------------------------------------------------------
-- 10. Themes — built lazily; all values are Color3 (needs Roblox globals)
--     Light/dark switchable with tweened transitions.
-- ----------------------------------------------------------------------------
local themesCache
local function getThemes()
	if themesCache then return themesCache end
	local function c(r, g, b) return Color3.fromRGB(r, g, b) end
	themesCache = {
		Dark = {
			name = "Dark",
			WindowBg = c(30, 30, 38),
			PanelBg = c(24, 24, 31),
			TitleBar = c(26, 26, 34),
			TabBar = c(22, 22, 28),
			TabActive = c(30, 30, 38),
			TabInactive = c(26, 26, 33),
			Gutter = c(36, 36, 46),
			GutterText = c(118, 118, 140),
			Stroke = c(52, 52, 66),
			Text = c(212, 214, 224),
			TextDim = c(140, 142, 160),
			Accent = c(88, 166, 255),
			AccentHover = c(110, 184, 255),
			Hover = c(44, 44, 56),
			Button = c(36, 36, 46),
			CurrentLine = c(255, 255, 255),
			CurrentLineAlpha = 0.945,             -- CurrentLine rendered at 5.5% opacity
			Selection = c(56, 96, 150),
			SelectionAlpha = 0.35,
			Match = c(120, 110, 60),
			MatchAlpha = 0.45,
			MatchCurrent = c(150, 130, 60),
			MatchCurrentAlpha = 0.5,
			Caret = c(235, 235, 240),
			ScrollTrack = c(30, 30, 38),
			ScrollThumb = c(84, 84, 108),
			ScrollThumbHover = c(110, 110, 140),
			StatusBar = c(26, 26, 34),
			MinimapBg = c(24, 24, 30),
			MinimapInk = c(150, 152, 175),
			MinimapViewport = c(88, 166, 255),
			MinimapViewportAlpha = 0.82,
			Shadow = c(0, 0, 0),
			ModifiedDot = c(229, 192, 123),
			Danger = c(224, 108, 117),
			Ok = c(152, 195, 121),
			Syntax = {
				keyword = "#569CD6", builtin = "#4EC9B0", string = "#CE9178",
				number = "#B5CEA8", comment = "#6A9955", function_ = "#DCDCAA",
				["function"] = "#DCDCAA", operator = "#D4D4D4", ident = "#D4D4D4",
				gap = nil, plain = "#D4D4D4",
			},
		},
		Light = {
			name = "Light",
			WindowBg = c(255, 255, 255),
			PanelBg = c(243, 243, 246),
			TitleBar = c(236, 236, 240),
			TabBar = c(228, 228, 233),
			TabActive = c(255, 255, 255),
			TabInactive = c(233, 233, 238),
			Gutter = c(248, 248, 250),
			GutterText = c(150, 150, 160),
			Stroke = c(206, 206, 214),
			Text = c(30, 30, 36),
			TextDim = c(120, 120, 132),
			Accent = c(0, 102, 204),
			AccentHover = c(30, 124, 226),
			Hover = c(228, 228, 236),
			Button = c(233, 233, 238),
			CurrentLine = c(0, 84, 180),
			CurrentLineAlpha = 0.93,
			Selection = c(173, 214, 255),
			SelectionAlpha = 0.55,
			Match = c(255, 235, 140),
			MatchAlpha = 0.55,
			MatchCurrent = c(255, 213, 79),
			MatchCurrentAlpha = 0.65,
			Caret = c(0, 0, 0),
			ScrollTrack = c(250, 250, 250),
			ScrollThumb = c(186, 186, 198),
			ScrollThumbHover = c(150, 150, 170),
			StatusBar = c(236, 236, 240),
			MinimapBg = c(243, 243, 247),
			MinimapInk = c(120, 122, 140),
			MinimapViewport = c(0, 102, 204),
			MinimapViewportAlpha = 0.8,
			Shadow = c(0, 0, 0),
			ModifiedDot = c(214, 140, 32),
			Danger = c(203, 36, 49),
			Ok = c(26, 127, 55),
			Syntax = {
				keyword = "#AF00DB", builtin = "#267F99", string = "#A31515",
				number = "#098658", comment = "#008000", function_ = "#795E26",
				["function"] = "#795E26", operator = "#1E1E1E", ident = "#1E1E1E",
				gap = nil, plain = "#1E1E1E",
			},
		},
	}
	return themesCache
end

-- ----------------------------------------------------------------------------
-- 11. Filesystem persistence — everything lives in an "Editor" folder.
--     Backups for autosave are stored as ".backup_<name>" next to files.
-- ----------------------------------------------------------------------------
local FS = {}
FS.Folder = "Editor"

function FS.EnsureFolder()
	if type(makefolder) == "function" then
		pcall(makefolder, FS.Folder)
	end
end

function FS.CanUse()
	return type(writefile) == "function" and type(readfile) == "function"
end

function FS.ListFiles() -- returns { path, ... } non-backup files, sorted
	if type(listfiles) ~= "function" then return {} end
	local ok, files = pcall(listfiles, FS.Folder)
	if not ok or type(files) ~= "table" then return {} end
	local out = {}
	for _, path in ipairs(files) do
		if type(path) == "string" then
			local base = path:match("[^/\\]+$") or path
			if base:sub(1, 8) ~= ".backup_" then
				out[#out + 1] = path
			end
		end
	end
	table.sort(out)
	return out
end

function FS.ListBackups()
	if type(listfiles) ~= "function" then return {} end
	local ok, files = pcall(listfiles, FS.Folder)
	if not ok or type(files) ~= "table" then return {} end
	local out = {}
	for _, path in ipairs(files) do
		if type(path) == "string" and (path:match("[^/\\]+$") or ""):sub(1, 8) == ".backup_" then
			out[#out + 1] = path
		end
	end
	table.sort(out)
	return out
end

function FS.IsFile(path)
	if type(isfile) ~= "function" then return true end
	local ok, res = pcall(isfile, path)
	return ok and res == true
end

function FS.Read(path)
	local ok, data = pcall(readfile, path)
	if ok then return data end
	return nil, tostring(data)
end

function FS.Write(path, text)
	local ok, err = pcall(writefile, path, text)
	if ok then return true end
	-- some executors are picky about trailing slashes in nested paths
	local ok2, err2 = pcall(writefile, path:gsub("//", "/"), text)
	if ok2 then return true end
	return false, tostring(err) .. " | " .. tostring(err2)
end

function FS.Delete(path)
	if type(delfile) == "function" then
		pcall(delfile, path)
	end
end

function FS.BackupPath(name)
	local safe = name:gsub("[^%w%-%._ ]", "_")
	return FS.Folder .. "/.backup_" .. safe
end

function FS.PathFor(name) -- used by the Save As dialog
	local fixed = Util.trim(name):gsub("[^%w%-%._ ]", "_")
	if fixed == "" then fixed = "untitled" end
	if not fixed:match("%.[%w]+$") then fixed = fixed .. ".lua" end
	return FS.Folder .. "/" .. fixed
end

function FS.DisplayName(path)
	local base = path:match("[^/\\]+$") or path
	return base
end

-- ============================================================================
-- 12. IDE construction — only runs on the client under Roblox.
-- ============================================================================
local WELCOME_TEXT -- assigned below build (forward declaration)

local BuildInterior
local function BuildIDE()
	local s = {}

	local Players = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local TextService = game:GetService("TextService")

	s.maid = Maid.new()
	s.focused = true
	s.minimized = false
	s.pasting = false
	s.tabs = {}
	s.activeTab = nil
	s.tabCounter = 0
	s.untitledCounter = 0
	s.themeName = "Dark"
	s.lineHeight = 19
	s.fontSize = 13
	s.renderDirty = true
	s.held = {}            -- KeyCode -> os.clock() of press (for key repeat)
	s.lastRepeat = {}      -- KeyCode -> os.clock() of last repeat fire
	s.caretBlink = 0
	s.caretVisible = true
	s.autosaveClock = 0
	s.foldRecomputeClock = 0
	s.foldsDirty = true
	s.minimapDirty = true
	s.identifierScan = 0   -- buffer version at last identifier rescan
	s.identifierCache = {}
	s.closing = false

	local okMono, monoFont = pcall(function() return Enum.Font.RobotoMono end)
	local okG, uiFont = pcall(function() return Enum.Font.GothamMedium end)
	local okGB, uiBold = pcall(function() return Enum.Font.GothamBold end)
	s.mono = (okMono and monoFont) or Enum.Font.SourceSans
	s.uiFont = (okG and uiFont) or Enum.Font.SourceSans
	s.uiBold = (okGB and uiBold) or s.uiFont

	local function measure(text, size, font)
		size = size or s.fontSize
		font = font or s.mono
		local ok, vec = pcall(function()
			return TextService:GetTextSize(text, size, font, Vector2.new(100000, 100000))
		end)
		if ok and vec then return vec.X end
		return #text * (size * 0.6)
	end
	s.measure = measure

	local function mk(class, props, parent)
		local inst = Instance.new(class)
		for k, v in pairs(props or {}) do
			local ok = pcall(function() inst[k] = v end)
			if not ok then
				warn("MiniIDE: property set failed:", class, k)
			end
			if k == "Parent" then parent = nil end
		end
		if parent then inst.Parent = parent end
		return inst
	end
	s.mk = mk

	local function tween(inst, info, props)
		local t = TweenService:Create(inst, info, props)
		t:Play()
		return t
	end
	s.tween = tween

	local TWEEN_FAST = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local TWEEN_MED = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local TWEEN_POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	-- ---------------------------------------------------------------- shell
	local uiParent
	local okUi, hui = pcall(function()
		return (typeof(gethui) == "function") and gethui() or game:GetService("CoreGui")
	end)
	uiParent = okUi and hui or game:GetService("CoreGui")

	local screen = nil
	pcall(function()
		screen = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
	end)
	screen = screen or Vector2.new(1280, 720)

	local WIN_W, WIN_H = math.floor(math.min(900, screen.X * 0.66)), math.floor(math.min(560, screen.Y * 0.72))
	WIN_W = math.max(WIN_W, 620)
	WIN_H = math.max(WIN_H, 380)
	s.winW, s.winH = WIN_W, WIN_H

	local gui = mk("ScreenGui", {
		Name = "MiniIDE_" .. tostring(math.random(100000, 999999)),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, uiParent)
	gui.DisplayOrder = 1000
	s.gui = gui
	s.maid:Give(gui)

	-- fake drop shadow (layered translucent frames, no external assets)
	local shadow = mk("Frame", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
	}, gui)
	mk("UICorner", { CornerRadius = UDim.new(0, 12) }, shadow)

	local window = mk("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(math.floor((screen.X - WIN_W) / 2), math.floor((screen.Y - WIN_H) / 2)),
		Size = UDim2.fromOffset(WIN_W, WIN_H),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, gui)
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, window)
	local windowStroke = mk("UIStroke", { Thickness = 1, Transparency = 0.35 }, window)
	s.window = window
	s.windowStroke = windowStroke


	-- layout constants
	local TITLE_H, TABS_H, STATUS_H = 36, 34, 24
	local GUTTER_W = 54
	local MINIMAP_W = 92
	local SCROLLBAR = 10
	s.TITLE_H, s.TABS_H, s.STATUS_H = TITLE_H, TABS_H, STATUS_H
	s.GUTTER_W, s.MINIMAP_W, s.SCROLLBAR = GUTTER_W, MINIMAP_W, SCROLLBAR

	-- ------------------------------------------------------------ title bar
	local titleBar = mk("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, TITLE_H),
		BorderSizePixel = 0,
	}, window)

	local iconChip = mk("Frame", {
		Position = UDim2.fromOffset(10, 7),
		Size = UDim2.fromOffset(22, 22),
		BorderSizePixel = 0,
	}, titleBar)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, iconChip)
	local iconGlyph = mk("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = ">_",
		Font = s.mono,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
	}, iconChip)

	local titleLabel = mk("TextLabel", {
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -280, 1, 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Luau Mini IDE",
		Font = s.uiBold,
		TextSize = 13,
	}, titleBar)
	s.titleLabel = titleLabel

	-- window control buttons (custom vector glyphs drawn from frames)
	local function makeTitleButton(offsetRight, dangerHover)
		local btn = mk("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -offsetRight, 0.5, 0),
			Size = UDim2.fromOffset(34, 24),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
		}, titleBar)
		mk("UICorner", { CornerRadius = UDim.new(0, 5) }, btn)
		return btn
	end

	local closeBtn = makeTitleButton(8, true)
	local closeBarA = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(13, 2),
		Rotation = 45,
		BorderSizePixel = 0,
	}, closeBtn)
	local closeBarB = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(13, 2),
		Rotation = -45,
		BorderSizePixel = 0,
	}, closeBtn)

	local minBtn = makeTitleButton(46, false)
	local minBar = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(12, 2),
		BorderSizePixel = 0,
	}, minBtn)

	local themeBtn = makeTitleButton(84, false)
	-- crescent moon drawn from two circles (no font glyphs needed)
	local themeCircle = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(13, 13),
		BorderSizePixel = 0,
	}, themeBtn)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, themeCircle)
	local themeCutout = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 3, 0.5, -2),
		Size = UDim2.fromOffset(11, 11),
		BorderSizePixel = 0,
	}, themeBtn)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, themeCutout)
	s.themeCutout = themeCutout

	s.titleBar, s.iconChip, s.iconGlyph = titleBar, iconChip, iconGlyph
	s.closeBarA, s.closeBarB, s.minBar = closeBarA, closeBarB, minBar
	s.themeCircle, s.themeCutout = themeCircle, themeCutout
	s.closeBtn, s.minBtn, s.themeBtn = closeBtn, minBtn, themeBtn

	-- --------------------------------------------------------------- tab bar
	local tabBar = mk("Frame", {
		Name = "TabBar",
		Position = UDim2.fromOffset(0, TITLE_H),
		Size = UDim2.new(1, 0, 0, TABS_H),
		BorderSizePixel = 0,
	}, window)
	local tabList = mk("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, -44, 1, 0),
		BackgroundTransparency = 1,
	}, tabBar)
	mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabList)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, tabList)

	local newTabBtn = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(28, 24),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "+",
		Font = s.uiFont,
		TextSize = 17,
	}, tabBar)
	mk("UICorner", { CornerRadius = UDim.new(0, 5) }, newTabBtn)

	-- ----------------------------------------------------------------- body
	local body = mk("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, TITLE_H + TABS_H),
		Size = UDim2.new(1, 0, 1, -(TITLE_H + TABS_H + STATUS_H)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, window)

	-- collapsible file-explorer sidebar
	local sidebar = mk("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 178, 1, 0),
		BorderSizePixel = 0,
	}, body)
	local sideHeader = mk("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
	}, sidebar)
	local sideTitle = mk("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -70, 1, 0),
		BackgroundTransparency = 1,
		Text = "EXPLORER",
		Font = s.uiBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, sideHeader)
	local function sideButton(text, offsetX, tooltip)
		local b = mk("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -offsetX, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = text,
			Font = s.uiFont,
			TextSize = 13,
		}, sideHeader)
		mk("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
		return b
	end
	local sideNewBtn = sideButton("+", 4, "New file (saves into Editor/)")
	local sideRefreshBtn = sideButton("↻", 27, "Refresh file list")
	local sideCollapseBtn = sideButton("«", 50, "Collapse sidebar")
	local fileList = mk("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
	}, sidebar)
	mk("UIListLayout", {
		Padding = UDim.new(0, 1),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, fileList)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2) }, fileList)

	local sidebarExpandBtn = mk("TextButton", { -- shown only while collapsed
		Position = UDim2.fromOffset(2, 4),
		Size = UDim2.fromOffset(20, 22),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "»",
		Font = s.uiFont,
		TextSize = 13,
		Visible = false,
		ZIndex = 5,
	}, body)
	mk("UICorner", { CornerRadius = UDim.new(0, 4) }, sidebarExpandBtn)

	-- editor region
	local editorArea = mk("Frame", {
		Name = "EditorArea",
		Size = UDim2.new(1, 0, 1, 0), -- re-laid-out in layout()
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, body)

	local gutter = mk("Frame", {
		Name = "Gutter",
		Size = UDim2.new(0, GUTTER_W, 1, -SCROLLBAR),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
	}, editorArea)

	-- text clip doubles as a CanvasGroup so we can fade the whole editor on tab switch
	local okCanvas, textClip = pcall(function()
		return mk("CanvasGroup", {
			Name = "TextClip",
			Position = UDim2.fromOffset(GUTTER_W, 0),
			Size = UDim2.new(1, -(GUTTER_W + MINIMAP_W + SCROLLBAR), 1, -SCROLLBAR),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			GroupTransparency = 0,
		}, editorArea)
	end)
	if not okCanvas or not textClip then
		textClip = mk("Frame", {
			Name = "TextClip",
			Position = UDim2.fromOffset(GUTTER_W, 0),
			Size = UDim2.new(1, -(GUTTER_W + MINIMAP_W + SCROLLBAR), 1, -SCROLLBAR),
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, editorArea)
	end

	-- layers inside the text clip (z-order = creation order)
	local currentLineFrame = mk("Frame", {
		Name = "CurrentLine",
		BorderSizePixel = 0,
		Visible = false,
	}, textClip)
	local selectionLayer = mk("Frame", {
		Name = "SelectionLayer",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, textClip)
	local matchLayer = mk("Frame", {
		Name = "MatchLayer",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, textClip)
	local lineLayer = mk("Frame", {
		Name = "LineLayer",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, textClip)
	local caretFrame = mk("Frame", {
		Name = "Caret",
		BorderSizePixel = 0,
		Size = UDim2.new(0, 2, 0, s.lineHeight - 2),
	}, textClip)

	-- minimap
	local minimap = mk("Frame", {
		Name = "Minimap",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, MINIMAP_W, 1, -SCROLLBAR),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, editorArea)
	local minimapCanvas = mk("Frame", {
		Name = "Ink",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, minimap)
	local minimapViewport = mk("Frame", {
		Name = "Viewport",
		BorderSizePixel = 0,
	}, minimap)
	mk("UICorner", { CornerRadius = UDim.new(0, 3) }, minimapViewport)

	-- custom scrollbars
	local vTrack = mk("Frame", {
		Name = "VTrack",
		Position = UDim2.new(1, -(MINIMAP_W + SCROLLBAR), 0, 0),
		Size = UDim2.new(0, SCROLLBAR, 1, -SCROLLBAR),
		BorderSizePixel = 0,
	}, editorArea)
	local vThumb = mk("Frame", {
		Name = "VThumb",
		Size = UDim2.new(1, -2, 0, 40),
		BorderSizePixel = 0,
	}, vTrack)
	mk("UICorner", { CornerRadius = UDim.new(0, 5) }, vThumb)

	local hTrack = mk("Frame", {
		Name = "HTrack",
		Position = UDim2.fromOffset(GUTTER_W, 0),
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, -(GUTTER_W + MINIMAP_W + SCROLLBAR), 0, SCROLLBAR),
		BorderSizePixel = 0,
	}, editorArea)
	hTrack.Position = UDim2.new(0, GUTTER_W, 1, 0)
	local hThumb = mk("Frame", {
		Name = "HThumb",
		Size = UDim2.new(0, 80, 1, -2),
		BorderSizePixel = 0,
	}, hTrack)
	mk("UICorner", { CornerRadius = UDim.new(0, 5) }, hThumb)

	-- find & replace panel (top-right, floating)
	local findPanel = mk("Frame", {
		Name = "FindPanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(MINIMAP_W + SCROLLBAR + 8), 0, 6),
		Size = UDim2.fromOffset(0, 0), -- animated open
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
	}, editorArea)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, findPanel)
	local findStroke = mk("UIStroke", { Thickness = 1, Transparency = 0.4 }, findPanel)

	local function findRow(y)
		return UDim2.fromOffset(8, y)
	end
	local queryBox = mk("TextBox", {
		Position = findRow(8),
		Size = UDim2.fromOffset(150, 22),
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Text = "",
		PlaceholderText = "Find…",
		Font = s.uiFont,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	}, findPanel)
	mk("UICorner", { CornerRadius = UDim.new(0, 4) }, queryBox)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, queryBox)
	local matchLabel = mk("TextLabel", {
		Position = UDim2.fromOffset(162, 8),
		Size = UDim2.fromOffset(56, 22),
		BackgroundTransparency = 1,
		Text = "",
		Font = s.uiFont,
		TextSize = 11,
		ZIndex = 21,
	}, findPanel)
	local function findButton(text, x, y, w, tip)
		local b = mk("TextButton", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w or 24, 22),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = text,
			Font = s.uiFont,
			TextSize = 12,
			ZIndex = 21,
		}, findPanel)
		mk("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
		return b
	end
	local caseBtn = findButton("Aa", 222, 8, 24, "Match case")
	local wordBtn = findButton("W", 250, 8, 22, "Whole word")
	local prevBtn = findButton("↑", 276, 8, 22, "Previous match (Shift+Enter)")
	local nextBtn = findButton("↓", 302, 8, 22, "Next match (Enter)")
	local closeFindBtn = findButton("×", 328, 8, 22, "Close (Esc)")
	local replBox = mk("TextBox", {
		Position = findRow(36),
		Size = UDim2.fromOffset(150, 22),
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Text = "",
		PlaceholderText = "Replace…",
		Font = s.uiFont,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	}, findPanel)
	mk("UICorner", { CornerRadius = UDim.new(0, 4) }, replBox)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, replBox)
	local replaceBtn = findButton("Replace", 162, 36, 66, "Replace current (Ctrl+Shift+1)")
	local replaceAllBtn = findButton("All", 232, 36, 34, "Replace all (Ctrl+Shift+Enter)")
	findPanel.Size = UDim2.fromOffset(0, 0)

	-- autocomplete popup
	local acPopup = mk("Frame", {
		Name = "Autocomplete",
		Position = UDim2.fromOffset(GUTTER_W + 8, 60),
		Size = UDim2.fromOffset(240, 0),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 25,
		ClipsDescendants = true,
	}, editorArea)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, acPopup)
	local acStroke = mk("UIStroke", { Thickness = 1, Transparency = 0.35 }, acPopup)
	local acRows = {}
	for i = 1, 9 do
		local row = mk("TextButton", {
			Position = UDim2.fromOffset(0, (i - 1) * 22),
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = s.mono,
			TextSize = 12,
			Visible = false,
			ZIndex = 26,
		}, acPopup)
		mk("UIPadding", { PaddingLeft = UDim.new(0, 8) }, row)
		local tag = mk("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(60, 14),
			BackgroundTransparency = 1,
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = s.uiFont,
			TextSize = 10,
			ZIndex = 26,
		}, row)
		acRows[i] = { row = row, tag = tag }
	end
	s.acRows = acRows

	-- -------------------------------------------------------------- status bar
	local statusBar = mk("Frame", {
		Name = "StatusBar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, STATUS_H),
		BorderSizePixel = 0,
	}, window)

	local statusLeft = mk("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Ln 1, Col 1",
		Font = s.uiFont,
		TextSize = 11,
	}, statusBar)
	local statusCenter = mk("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0.34, 0, 1, 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Font = s.uiFont,
		TextSize = 11,
	}, statusBar)
	local statusRight = mk("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.new(0.42, 0, 1, 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Luau",
		Font = s.uiFont,
		TextSize = 11,
	}, statusBar)
	s.statusBar, s.statusLeft, s.statusCenter, s.statusRight = statusBar, statusLeft, statusCenter, statusRight

	-- toast bubble (bottom-center)
	local toast = mk("Frame", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(STATUS_H + 10)),
		Size = UDim2.fromOffset(0, 30),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 40,
	}, window)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, toast)
	local toastLabel = mk("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Font = s.uiFont,
		TextSize = 12,
		ZIndex = 41,
	}, toast)
	s.toast, s.toastLabel = toast, toastLabel

	-- resize grips (right / bottom / corner)
	local gripRight = mk("TextButton", {
		Name = "GripRight",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, TITLE_H),
		Size = UDim2.new(0, 5, 1, -TITLE_H),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 30,
	}, window)
	local gripBottom = mk("TextButton", {
		Name = "GripBottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 30,
	}, window)
	local gripCorner = mk("TextButton", {
		Name = "GripCorner",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 31,
	}, window)
	-- corner affordance: two diagonal dots
	for i = 0, 1 do
		mk("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -4 - i * 5, 1, -4 - i * 5),
			Size = UDim2.fromOffset(3, 3),
			BorderSizePixel = 0,
		}, gripCorner)
	end

	s.tabBar, s.tabList, s.newTabBtn = tabBar, tabList, newTabBtn
	s.sidebar, s.sideTitle, s.fileList = sidebar, sideTitle, fileList
	s.sideNewBtn, s.sideRefreshBtn, s.sideCollapseBtn, s.sidebarExpandBtn = sideNewBtn, sideRefreshBtn, sideCollapseBtn, sidebarExpandBtn
	s.body, s.editorArea, s.gutter, s.textClip = body, editorArea, gutter, textClip
	s.lineLayer, s.selectionLayer, s.matchLayer, s.currentLineFrame, s.caretFrame = lineLayer, selectionLayer, matchLayer, currentLineFrame, caretFrame
	s.minimap, s.minimapCanvas, s.minimapViewport = minimap, minimapCanvas, minimapViewport
	s.vTrack, s.vThumb, s.hTrack, s.hThumb = vTrack, vThumb, hTrack, hThumb
	s.findPanel, s.queryBox, s.replBox, s.matchLabel = findPanel, queryBox, replBox, matchLabel
	s.caseBtn, s.wordBtn, s.prevBtn, s.nextBtn, s.closeFindBtn = caseBtn, wordBtn, prevBtn, nextBtn, closeFindBtn
	s.replaceBtn, s.replaceAllBtn = replaceBtn, replaceAllBtn
	s.findStroke = findStroke
	s.acPopup, s.acStroke = acPopup, acStroke
	s.gripRight, s.gripBottom, s.gripCorner = gripRight, gripBottom, gripCorner
	s.shadow = shadow


	-- hand off to the interior builder (separate scope: avoids Lua's 200-local limit)
	return BuildInterior(s, {
		window = window, screen = screen, gui = gui,
		mk = mk, tween = tween,
		TWEEN_FAST = TWEEN_FAST, TWEEN_MED = TWEEN_MED, TWEEN_POP = TWEEN_POP,
		TITLE_H = TITLE_H, TABS_H = TABS_H, STATUS_H = STATUS_H,
		GUTTER_W = GUTTER_W, MINIMAP_W = MINIMAP_W, SCROLLBAR = SCROLLBAR,
	})
end

BuildInterior = function(s, env)
	local window = env.window
	local screen = env.screen
	local gui = env.gui
	local mk = env.mk
	local tween = env.tween
	local TWEEN_FAST, TWEEN_MED, TWEEN_POP = env.TWEEN_FAST, env.TWEEN_MED, env.TWEEN_POP
	local TITLE_H, TABS_H, STATUS_H = env.TITLE_H, env.TABS_H, env.STATUS_H
	local GUTTER_W, MINIMAP_W, SCROLLBAR = env.GUTTER_W, env.MINIMAP_W, env.SCROLLBAR
	-- services (module-level scope: BuildIDE's locals are not visible here)
	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local body = s.body
	local sidebar = s.sidebar
	local gutter = s.gutter
	local minimap = s.minimap
	local shadow = s.shadow
	local measure = s.measure

	-- ------------------------------------------------- theme bindings & layout
	local themeBindings = {}
	local function bindTheme(inst, prop, key)
		themeBindings[#themeBindings + 1] = { inst = inst, prop = prop, key = key }
	end

	bindTheme(window, "BackgroundColor3", "WindowBg")
	bindTheme(s.windowStroke, "Color", "Stroke")
	bindTheme(s.shadow, "BackgroundColor3", "Shadow")
	bindTheme(s.titleBar, "BackgroundColor3", "TitleBar")
	bindTheme(s.tabBar, "BackgroundColor3", "TabBar")
	bindTheme(s.iconChip, "BackgroundColor3", "Accent")
	bindTheme(s.titleLabel, "TextColor3", "Text")
	bindTheme(s.newTabBtn, "TextColor3", "Text")
	bindTheme(s.newTabBtn, "BackgroundColor3", "TabBar")
	bindTheme(s.sidebar, "BackgroundColor3", "PanelBg")
	bindTheme(s.sideTitle, "TextColor3", "TextDim")
	bindTheme(s.sideNewBtn, "BackgroundColor3", "Button")
	bindTheme(s.sideNewBtn, "TextColor3", "Text")
	bindTheme(s.sideRefreshBtn, "BackgroundColor3", "Button")
	bindTheme(s.sideRefreshBtn, "TextColor3", "Text")
	bindTheme(s.sideCollapseBtn, "BackgroundColor3", "Button")
	bindTheme(s.sideCollapseBtn, "TextColor3", "Text")
	bindTheme(s.sidebarExpandBtn, "BackgroundColor3", "Button")
	bindTheme(s.sidebarExpandBtn, "TextColor3", "Text")
	bindTheme(s.gutter, "BackgroundColor3", "Gutter")
	bindTheme(s.vTrack, "BackgroundColor3", "ScrollTrack")
	bindTheme(s.hTrack, "BackgroundColor3", "ScrollTrack")
	bindTheme(s.vThumb, "BackgroundColor3", "ScrollThumb")
	bindTheme(s.hThumb, "BackgroundColor3", "ScrollThumb")
	bindTheme(s.findPanel, "BackgroundColor3", "PanelBg")
	bindTheme(s.findStroke, "Color", "Stroke")
	bindTheme(s.queryBox, "BackgroundColor3", "Button")
	bindTheme(s.queryBox, "TextColor3", "Text")
	bindTheme(s.queryBox, "PlaceholderColor3", "TextDim")
	bindTheme(s.replBox, "BackgroundColor3", "Button")
	bindTheme(s.replBox, "TextColor3", "Text")
	bindTheme(s.replBox, "PlaceholderColor3", "TextDim")
	bindTheme(s.matchLabel, "TextColor3", "TextDim")
	bindTheme(s.prevBtn, "BackgroundColor3", "Button")
	bindTheme(s.prevBtn, "TextColor3", "Text")
	bindTheme(s.nextBtn, "BackgroundColor3", "Button")
	bindTheme(s.nextBtn, "TextColor3", "Text")
	bindTheme(s.closeFindBtn, "BackgroundColor3", "Button")
	bindTheme(s.closeFindBtn, "TextColor3", "Text")
	bindTheme(s.replaceBtn, "BackgroundColor3", "Button")
	bindTheme(s.replaceBtn, "TextColor3", "Text")
	bindTheme(s.replaceAllBtn, "BackgroundColor3", "Button")
	bindTheme(s.replaceAllBtn, "TextColor3", "Text")
	bindTheme(s.acPopup, "BackgroundColor3", "PanelBg")
	bindTheme(s.acStroke, "Color", "Stroke")
	bindTheme(s.statusBar, "BackgroundColor3", "StatusBar")
	bindTheme(s.statusLeft, "TextColor3", "Text")
	bindTheme(s.statusCenter, "TextColor3", "TextDim")
	bindTheme(s.statusRight, "TextColor3", "TextDim")
	bindTheme(s.toast, "BackgroundColor3", "PanelBg")
	bindTheme(s.toastLabel, "TextColor3", "Text")
	bindTheme(s.minimap, "BackgroundColor3", "MinimapBg")
	bindTheme(s.themeBtn, "BackgroundColor3", "TitleBar")
	bindTheme(s.minBtn, "BackgroundColor3", "TitleBar")
	bindTheme(s.closeBtn, "BackgroundColor3", "TitleBar")
	bindTheme(s.themeCircle, "BackgroundColor3", "Text")
	bindTheme(s.minBar, "BackgroundColor3", "Text")
	bindTheme(s.closeBarA, "BackgroundColor3", "Text")
	bindTheme(s.closeBarB, "BackgroundColor3", "Text")

	-- hover tween helper for buttons (background <-> Hover color)
	local function addHover(btn, normalKey, hoverKey)
		hoverKey = hoverKey or "Hover"
		normalKey = normalKey or "Button"
		btn.MouseEnter:Connect(function()
			local t = s.theme
			tween(btn, TWEEN_FAST, { BackgroundColor3 = t[hoverKey] or t.Hover })
		end)
		btn.MouseLeave:Connect(function()
			local t = s.theme
			tween(btn, TWEEN_FAST, { BackgroundColor3 = t[normalKey] or t.Button })
		end)
	end
	s.addHover = addHover
	for _, b in ipairs({ s.newTabBtn, s.sideNewBtn, s.sideRefreshBtn, s.sideCollapseBtn, s.sidebarExpandBtn,
		s.prevBtn, s.nextBtn, s.closeFindBtn, s.replaceBtn, s.replaceAllBtn }) do
		addHover(b)
	end
	-- title buttons sit on the title bar: rest on TitleBar, brighten on hover
	addHover(s.themeBtn, "TitleBar", "Hover")
	addHover(s.minBtn, "TitleBar", "Hover")
	-- close button hovers with its own danger logic
	s.closeBtn.MouseEnter:Connect(function()
		tween(s.closeBtn, TWEEN_FAST, { BackgroundColor3 = s.theme.Danger })
	end)
	s.closeBtn.MouseLeave:Connect(function()
		tween(s.closeBtn, TWEEN_FAST, { BackgroundColor3 = s.theme.TitleBar })
	end)

	s.theme = getThemes()[s.themeName]

	local function applyThemeAll(name, animate)
		local themes = getThemes()
		local theme = themes[name]
		if not theme then return end
		s.theme = theme
		s.themeName = name
		for _, b in ipairs(themeBindings) do
			local target = theme[b.key]
			if typeof(target) == "Color3" then
				if animate then
					tween(b.inst, TWEEN_MED, { [b.prop] = target })
				else
					b.inst[b.prop] = target
				end
			end
		end
		s.currentLineFrame.BackgroundColor3 = theme.CurrentLine
		s.currentLineFrame.BackgroundTransparency = theme.CurrentLineAlpha
		s.caretFrame.BackgroundColor3 = theme.Caret
		-- fold arrow glyph colors are read at render time
		-- theme button cutout must match titlebar to fake a crescent
		s.themeCutout.BackgroundColor3 = theme.TitleBar
		s.minimapViewport.BackgroundColor3 = theme.MinimapViewport
		s.minimapViewport.BackgroundTransparency = theme.MinimapViewportAlpha
		s.renderDirty = true
		s.minimapDirty = true
		return theme
	end

	local sidebarWidth = 178
	local function layout()
		local size = window.AbsoluteSize
		local width, height = math.max(size.X, 1), math.max(size.Y, 1)
		s.sizeX, s.sizeY = width, height
		local minimized = s.minimized == true
		local bodyH = height - TITLE_H - TABS_H - STATUS_H
		body.Size = UDim2.new(1, 0, 0, math.max(bodyH, 0))
		body.Position = UDim2.fromOffset(0, TITLE_H + TABS_H)
		-- sidebar
		local sbW = s.sidebarCollapsed and 0 or sidebarWidth
		s.sidebarWidth = sbW
		s.sidebar.Size = UDim2.new(0, sbW, 1, 0)
		s.sidebar.ClipsDescendants = true
		s.sidebar.Visible = sbW > 0
		s.sidebarExpandBtn.Visible = s.sidebarCollapsed
		-- editor area
		s.editorArea.Position = UDim2.fromOffset(sbW, 0)
		s.editorArea.Size = UDim2.new(1, -sbW, 1, 0)
		local edW = math.max(width - sbW, 1)
		local edH = math.max(bodyH, 1)
		s.editorWidth, s.editorHeight = edW, edH
		local textW = math.max(edW - GUTTER_W - MINIMAP_W - SCROLLBAR, 1)
		local textH = math.max(edH - SCROLLBAR, 1)
		s.textWidth, s.textHeight = textW, textH
		s.gutter.Size = UDim2.fromOffset(GUTTER_W, textH)
		s.textClip.Size = UDim2.fromOffset(textW, textH)
		s.textClip.Position = UDim2.fromOffset(GUTTER_W, 0)
		s.minimap.Size = UDim2.fromOffset(MINIMAP_W, textH)
		s.minimap.Position = UDim2.new(1, 0, 0, 0)
		s.minimap.Visible = textH > 40
		s.vTrack.Position = UDim2.fromOffset(GUTTER_W + textW, 0)
		s.vTrack.Size = UDim2.fromOffset(SCROLLBAR, textH)
		s.hTrack.Position = UDim2.fromOffset(GUTTER_W, edH)
		s.hTrack.Size = UDim2.fromOffset(textW, SCROLLBAR)
		-- shadow tracks the window (13px even bleed)
		local wx, wy = window.Position.X.Offset, window.Position.Y.Offset
		s.shadow.Position = UDim2.fromOffset(wx - 13, wy - 13)
		s.shadow.Size = UDim2.fromOffset(width + 26, height + 26)
		s.renderDirty = true
		s.minimapDirty = true
		if not minimized then
			-- nothing else; minimap/scrollbars refresh next render
		end
	end
	s.layout = layout

	local function refreshLayoutSoon()
		layout()
		if s.renderAll then s.renderAll() end
	end

	-- toast (transient, auto-hides)
	local toastSerial = 0
	local function toastMsg(msg, isError)
		toastSerial = toastSerial + 1
		local my = toastSerial
		s.toastLabel.Text = msg
		s.toastLabel.TextColor3 = isError and s.theme.Danger or s.theme.Ok
		s.toast.Visible = true
		local textW = math.max(measure(msg, 12, s.uiFont) + 40, 120)
		s.toast.Size = UDim2.fromOffset(textW, 30)
		s.toast.BackgroundTransparency = 1
		tween(s.toast, TWEEN_FAST, { BackgroundTransparency = 0.08 })
		task.delay(3.2, function()
			if toastSerial == my and s.toast then
				s.toast.Visible = false
			end
		end)
	end
	s.toastMsg = toastMsg

	local statusClearSerial = 0
	local function setStatus(msg, sticky)
		s.statusCenter.Text = msg or ""
		statusClearSerial = statusClearSerial + 1
		if msg and not sticky and msg ~= "" then
			local my = statusClearSerial
			task.delay(4, function()
				if statusClearSerial == my then
					s.statusCenter.Text = ""
				end
			end)
		end
	end
	s.setStatus = setStatus

	-- ----------------------------------------------------- tabs & doc model
	local function currentTab()
		return s.activeTab
	end

	local function newTabData()
		s.tabCounter = s.tabCounter + 1
		return {
			id = s.tabCounter,
			path = nil,
			name = nil,
			buffer = TextBuffer.new(),
			undo = UndoStack.new(),
			tokenizer = Tokenizer.new(),
			finder = Finder.new(),
			caretLine = 1,
			caretCol = 1,
			goalCol = nil,
			anchor = nil,
			scrollX = 0,
			scrollY = 0,
			modified = false,
			folds = {},
			hiddenMap = {},
			hiddenPrefix = {},
			visibleLines = { 1 },
			totalRows = 1,
			backupPath = nil,
			foldsDirty = true,
		}
	end

	local function getSelection(tab)
		if not tab.anchor then return nil end
		local aL, aC = tab.anchor.line, tab.anchor.col
		local cL, cC = tab.caretLine, tab.caretCol
		if aL == cL and aC == cC then return nil end -- collapsed anchor: no selection
		if aL > cL or (aL == cL and aC > cC) then
			return cL, cC, aL, aC
		end
		return aL, aC, cL, cC
	end
	s.getSelection = getSelection

	local function selectionLength(tab)
		local a, b, c, d = getSelection(tab)
		if not a then return 0 end
		local text = tab.buffer:GetTextRange(a, b, c, d)
		return UTF8.len(text)
	end
	s.selectionLength = selectionLength

	-- rebuild hidden-line map / row lookup from fold state
	local function rebuildVisualMap(tab)
		local lineCount = tab.buffer:GetLineCount()
		local hidden = {}
		for _, fold in pairs(tab.folds) do
			if fold.collapsed then
				for li = fold.startLine + 1, math.min(fold.endLine, lineCount) do
					hidden[li] = true
				end
			end
		end
		local prefix, vis = {}, {}
		local acc = 0
		for li = 1, lineCount do
			prefix[li] = acc
			if hidden[li] then
				acc = acc + 1
			else
				vis[#vis + 1] = li
			end
		end
		tab.hiddenMap = hidden
		tab.hiddenPrefix = prefix
		tab.visibleLines = vis
		tab.totalRows = #vis
		tab.hiddenCount = acc
	end
	s.rebuildVisualMap = rebuildVisualMap

	local function lineToRow(tab, line)
		-- number of visible lines strictly before `line`, clamped
		line = math.clamp(line, 1, tab.buffer:GetLineCount())
		return line - (tab.hiddenPrefix[line] or 0) - 1
	end
	s.lineToRow = lineToRow

	local function rowToLine(tab, row)
		return tab.visibleLines[row + 1] or tab.buffer:GetLineCount()
	end
	s.rowToLine = rowToLine

	local function isLineVisible(tab, line)
		return not tab.hiddenMap[line]
	end
	s.isLineVisible = isLineVisible

	local function recomputeFolds(tab)
		local folds = computeFolds(tab.buffer, tab.tokenizer)
		local old = tab.folds
		local new = {}
		for _, f in ipairs(folds) do
			local prev = old[f.startLine]
			local collapsed = prev ~= nil and prev.collapsed == true and prev.endLine == f.endLine
			new[f.startLine] = { startLine = f.startLine, endLine = f.endLine, collapsed = collapsed }
		end
		tab.folds = new
		rebuildVisualMap(tab)
	end
	s.recomputeFolds = recomputeFolds

	local function toggleFold(tab, startLine)
		local fold = tab.folds[startLine]
		if not fold then return end
		fold.collapsed = not fold.collapsed
		-- if the caret hides inside a fold that just collapsed, move it to the fold line
		if fold.collapsed and tab.caretLine > fold.startLine and tab.caretLine <= fold.endLine then
			tab.caretLine = fold.startLine
			tab.caretCol = tab.buffer:GetLineLength(fold.startLine) + 1
			tab.anchor = nil
		end
		rebuildVisualMap(tab)
		s.renderDirty = true
		s.minimapDirty = true
	end
	s.toggleFold = toggleFold

	-- after any buffer mutation: invalidate caches, mark modified, refresh chrome
	local function afterEdit(tab, fromLine)
		tab.modified = true
		tab.tokenizer:InvalidateFrom(fromLine or 1)
		tab.tokenizer:Prune(tab.buffer:GetLineCount())
		tab.foldsDirty = true
		tab.minimapDirty = true
		tab.finderDirty = tab.finder.query ~= ""
		s.renderDirty = true
		if s.updateTabChrome then s.updateTabChrome() end
	end

	-- ------------------------------------------------------------ tab chrome
	local function addTabButton(tab)
		local btn = mk("TextButton", {
			Name = "Tab_" .. tab.id,
			Size = UDim2.fromOffset(150, 26),
			BackgroundColor3 = s.theme.TabInactive,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = tab.id,
		}, s.tabList)
		mk("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)
		local dot = mk("Frame", {
			Name = "ModifiedDot",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(7, 7),
			BorderSizePixel = 0,
			Visible = true,
		}, btn)
		mk("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
		local label = mk("TextLabel", {
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -44, 1, 0),
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = tab.name or "Untitled",
			Font = s.uiFont,
			TextSize = 12,
			TextColor3 = s.theme.Text,
		}, btn)
		local closeBtn = mk("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "×",
			Font = s.uiFont,
			TextSize = 14,
			TextColor3 = s.theme.TextDim,
			ZIndex = 3,
		}, btn)
		tab._button = btn
		tab._dot = dot
		tab._label = label
		tab._close = closeBtn
		closeBtn.MouseButton1Click:Connect(function()
			s.lastCloseClick = os.clock()
			if s.closeTab then s.closeTab(tab) end
		end)
		btn.MouseButton1Click:Connect(function()
			if os.clock() - (s.lastCloseClick or 0) < 0.12 then return end
			if s.switchTab then s.switchTab(tab) end
		end)
		btn.MouseEnter:Connect(function()
			if s.activeTab ~= tab then
				tween(btn, TWEEN_FAST, { BackgroundColor3 = s.theme.Hover })
			end
		end)
		btn.MouseLeave:Connect(function()
			if s.activeTab ~= tab then
				tween(btn, TWEEN_FAST, { BackgroundColor3 = s.theme.TabInactive })
			end
		end)
		return btn
	end

	local function updateTabChrome()
		for _, tab in ipairs(s.tabs) do
			local btn = tab._button
			if btn then
				local active = (tab == s.activeTab)
				btn.BackgroundColor3 = active and s.theme.TabActive or s.theme.TabInactive
				btn._activeBg = active
				tab._dot.Visible = tab.modified
				tab._label.Text = (tab.name or "Untitled")
				tab._label.TextColor3 = active and s.theme.Text or s.theme.TextDim
				tab._dot.BackgroundColor3 = s.theme.ModifiedDot
				tab._close.TextColor3 = s.theme.TextDim
			end
		end
		local tab = s.activeTab
		if tab then
			local prefix = tab.modified and "● " or ""
			s.titleLabel.Text = prefix .. (tab.name or "Untitled") .. " — Luau Mini IDE"
		end
	end
	s.updateTabChrome = updateTabChrome

	local function markTabModified()
		updateTabChrome()
	end
	s.markTabModified = markTabModified

	local function switchTab(tab)
		if s.activeTab == tab then
			updateTabChrome()
			return
		end
		s.activeTab = tab
		if s.hideAutocomplete then s.hideAutocomplete() end
		-- move find panel finder reference; folds/visual map revalidate
		recomputeFolds(tab)
		s.renderDirty = true
		updateTabChrome()
		-- subtle fade-in for the whole editor canvas
		local clip = s.textClip
		if typeof(clip) == "Instance" and clip:IsA("CanvasGroup") then
			clip.GroupTransparency = 0.85
			tween(clip, TWEEN_FAST, { GroupTransparency = 0 })
		end
		s.caretBlink = os.clock()
		if s.updateStatusBar then s.updateStatusBar() end
		if s.renderAll then s.renderAll() end
	end
	s.switchTab = switchTab

	local function finalizeNewTab(tab)
		s.tabs[#s.tabs + 1] = tab
		addTabButton(tab)
		switchTab(tab)
		return tab
	end

	local function newTab(name)
		local tab = newTabData()
		tab.name = name
		if not name then
			s.untitledCounter = s.untitledCounter + 1
			tab.name = "untitled-" .. s.untitledCounter .. ".lua"
		end
		rebuildVisualMap(tab)
		return finalizeNewTab(tab)
	end
	s.newTab = newTab

	local function closeTab(tab)
		if not tab then return end
		-- autosave a backup so nothing is lost
		if tab.modified then
			local backup = (tab.backupPath) or FS.BackupPath(tab.name or "untitled")
			local okWrite = FS.Write(backup, tab.buffer:GetText())
			if okWrite then
				s.toastMsg("Autosaved " .. (tab.name or "untitled") .. " before close")
				tab.backupPath = backup
			else
				s.toastMsg("Could not back up " .. (tab.name or "untitled") .. " — changes lost", true)
			end
		end
		-- remove from list
		local removeAt = 1
		for i, t in ipairs(s.tabs) do
			if t == tab then
				removeAt = i
				table.remove(s.tabs, i)
				break
			end
		end
		if tab._button then tab._button:Destroy() end
		if #s.tabs == 0 then
			newTab()
		else
			switchTab(s.tabs[math.min(removeAt, #s.tabs)])
		end
		updateTabChrome()
		s.renderDirty = true
		if s.renderAll then s.renderAll() end
	end
	s.closeTab = closeTab

	-- save As dialog (overlay modal) -----------------------------------------
	local inputOverlay, inputBox, inputTitle
	local function showInputDialog(titleText, placeholder, defaultText, onAccept)
		if not inputOverlay then
			inputOverlay = mk("Frame", {
				Name = "InputOverlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				ZIndex = 50,
			}, window)
			local panel = mk("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(320, 110),
				BorderSizePixel = 0,
				ZIndex = 51,
			}, inputOverlay)
			mk("UICorner", { CornerRadius = UDim.new(0, 8) }, panel)
			mk("UIStroke", { Thickness = 1, Transparency = 0.4 }, panel)
			s.inputPanel = panel
			inputTitle = mk("TextLabel", {
				Position = UDim2.fromOffset(12, 8),
				Size = UDim2.new(1, -24, 0, 18),
				BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = s.uiBold,
				TextSize = 12,
				ZIndex = 52,
			}, panel)
			inputBox = mk("TextBox", {
				Position = UDim2.fromOffset(12, 32),
				Size = UDim2.new(1, -24, 0, 24),
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				Font = s.uiFont,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 52,
			}, panel)
			mk("UICorner", { CornerRadius = UDim.new(0, 4) }, inputBox)
			mk("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, inputBox)
			local okBtn = mk("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 66),
				Size = UDim2.fromOffset(70, 26),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "Save",
				Font = s.uiBold,
				TextSize = 12,
				ZIndex = 52,
			}, panel)
			mk("UICorner", { CornerRadius = UDim.new(0, 5) }, okBtn)
			local cancelBtn = mk("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -90, 0, 66),
				Size = UDim2.fromOffset(70, 26),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "Cancel",
				Font = s.uiFont,
				TextSize = 12,
				ZIndex = 52,
			}, panel)
			mk("UICorner", { CornerRadius = UDim.new(0, 5) }, cancelBtn)
			s.inputPanel = panel
			s.inputOkBtn = okBtn
			s.inputCancelBtn = cancelBtn
			s.inputOverlay = inputOverlay
			s.inputBox = inputBox
			s.inputTitle = inputTitle
			s.inputAcceptHandler = nil
			bindTheme(panel, "BackgroundColor3", "PanelBg")
			bindTheme(okBtn, "BackgroundColor3", "Accent")
			bindTheme(okBtn, "TextColor3", "WindowBg")
			bindTheme(cancelBtn, "BackgroundColor3", "Button")
			bindTheme(cancelBtn, "TextColor3", "Text")
			bindTheme(inputBox, "BackgroundColor3", "Button")
			bindTheme(inputBox, "TextColor3", "Text")
			bindTheme(inputTitle, "TextColor3", "Text")
			local function accept()
				local text = Util.trim(s.inputBox.Text)
				inputOverlay.Visible = false
				if s.inputAcceptHandler and text ~= "" then
					s.inputAcceptHandler(text)
				end
			end
			okBtn.MouseButton1Click:Connect(accept)
			cancelBtn.MouseButton1Click:Connect(function()
				inputOverlay.Visible = false
			end)
			inputBox.FocusLost:Connect(function(enterPressed)
				if enterPressed then accept() end
			end)
		end
		inputTitle.Text = titleText
		inputBox.PlaceholderText = placeholder or ""
		inputBox.Text = defaultText or ""
		s.inputAcceptHandler = onAccept
		inputOverlay.Visible = true
		applyThemeAll(s.themeName, false) -- repaint including overlay bindings
		task.defer(function()
			if s.inputBox then s.inputBox:CaptureFocus() end
		end)
	end
	s.showInputDialog = showInputDialog

	-- ------------------------------------------------------ editing actions
	local function setCaretRaw(tab, line, col, extend)
		if extend then
			if not tab.anchor then
				tab.anchor = { line = tab.caretLine, col = tab.caretCol }
			end
		else
			tab.anchor = nil
		end
		line = math.clamp(line, 1, tab.buffer:GetLineCount())
		local lineLen = tab.buffer:GetLineLength(line)
		col = math.clamp(col, 1, lineLen + 1)
		tab.caretLine, tab.caretCol = line, col
		tab.goalCol = nil
		s.caretBlink = os.clock()
		s.caretVisible = true
		s.renderDirty = true
	end
	s.setCaretRaw = setCaretRaw

	local function deleteSelectionCommon(tab)
		local a, b, c, d = getSelection(tab)
		if not a then return false end
		local deleted = tab.buffer:GetTextRange(a, b, c, d)
		tab.buffer:DeleteRange(a, b, c, d)
		tab.undo:Push({ sLine = a, sCol = b, oldText = deleted, newText = "" }, nil)
		tab.caretLine, tab.caretCol, tab.anchor = a, b, nil
		tab.goalCol = nil
		afterEdit(tab, a)
		return true
	end

	local function insertTextCommon(tab, text, mergeKind)
		local edits = {}
		local sel = getSelection(tab)
		if sel then
			local a, b, c, d = getSelection(tab)
			local deleted = tab.buffer:GetTextRange(a, b, c, d)
			tab.buffer:DeleteRange(a, b, c, d)
			table.insert(edits, { sLine = a, sCol = b, oldText = deleted, newText = "" })
			tab.caretLine, tab.caretCol = a, b
			tab.anchor = nil
		end
		local sL, sC = tab.caretLine, tab.caretCol
		local eL, eC = tab.buffer:InsertText(sL, sC, text)
		table.insert(edits, { sLine = sL, sCol = sC, oldText = "", newText = text })
		tab.caretLine, tab.caretCol = eL, eC
		tab.goalCol = nil
		if #edits > 1 then
			tab.undo:PushBatch(edits)
		else
			tab.undo:Push(edits[1], mergeKind)
		end
		afterEdit(tab, sL)
		return eL, eC
	end
	s.insertTextCommon = insertTextCommon

	local PAIR = { ["("] = ")", ["["] = "]", ["{"] = "}", ['"'] = '"', ["'"] = "'" }
	local CLOSE = { [")"] = true, ["]"] = true, ["}"] = true, ['"'] = true, ["'"] = true }

	local function typeChar(tab, ch)
		-- skip over an existing closer instead of duplicating it
		if CLOSE[ch] and not getSelection(tab) then
			local lineText = tab.buffer:GetLine(tab.caretLine)
			local nextCh = UTF8.sub(lineText, tab.caretCol, tab.caretCol)
			if nextCh == ch then
				tab.caretCol = tab.caretCol + 1
				tab.goalCol = nil
				s.renderDirty = true
				return
			end
		end
		-- wrapping a selection with a pair
		local sel = getSelection(tab)
		if sel and PAIR[ch] then
			local a, b, c, d = getSelection(tab)
			local inner = tab.buffer:GetTextRange(a, b, c, d)
			local wrapped = ch .. inner .. PAIR[ch]
			tab.buffer:DeleteRange(a, b, c, d)
			tab.buffer:InsertText(a, b, wrapped)
			tab.undo:PushBatch({
				{ sLine = a, sCol = b, oldText = inner, newText = "" },
				{ sLine = a, sCol = b, oldText = "", newText = wrapped },
			})
			local closeAt = UTF8.len(wrapped)
			tab.anchor = { line = a, col = b + 1 }
			tab.caretLine, tab.caretCol = a, b + closeAt - 1
			afterEdit(tab, a)
			return
		end
		if PAIR[ch] and not sel then
			insertTextCommon(tab, ch .. PAIR[ch], nil)
			tab.caretCol = tab.caretCol - 1 -- sit between the pair
			s.renderDirty = true
			return
		end
		insertTextCommon(tab, ch, "Typing")
	end
	s.typeChar = typeChar

	local function backspace(tab)
		if deleteSelectionCommon(tab) then return true end
		local lineText = tab.buffer:GetLine(tab.caretLine)
		if tab.caretCol > 1 then
			local prevCh = UTF8.sub(lineText, tab.caretCol - 1, tab.caretCol - 1)
			local nextCh = UTF8.sub(lineText, tab.caretCol, tab.caretCol)
			if PAIR[prevCh] and PAIR[prevCh] == nextCh then
				tab.buffer:DeleteRange(tab.caretLine, tab.caretCol - 1, tab.caretLine, tab.caretCol + 1)
				tab.undo:PushBatch({ { sLine = tab.caretLine, sCol = tab.caretCol - 1, oldText = prevCh .. nextCh, newText = "" } })
				tab.caretCol = tab.caretCol - 1
				afterEdit(tab, tab.caretLine)
				return true
			end
			tab.buffer:DeleteRange(tab.caretLine, tab.caretCol - 1, tab.caretLine, tab.caretCol)
			tab.undo:Push({ sLine = tab.caretLine, sCol = tab.caretCol - 1, oldText = prevCh, newText = "" }, "Backspace")
			tab.caretCol = tab.caretCol - 1
			tab.goalCol = nil
			afterEdit(tab, tab.caretLine)
			return true
		end
		-- join with previous line
		if tab.caretLine > 1 then
			local prevLine = tab.caretLine - 1
			local prevLen = tab.buffer:GetLineLength(prevLine)
			tab.buffer:DeleteRange(prevLine, prevLen + 1, tab.caretLine, 1)
			tab.undo:Push({ sLine = prevLine, sCol = prevLen + 1, oldText = "\n", newText = "" }, nil)
			tab.caretLine, tab.caretCol = prevLine, prevLen + 1
			afterEdit(tab, prevLine)
			return true
		end
		return false
	end
	s.backspace = backspace

	local function deleteForward(tab)
		if deleteSelectionCommon(tab) then return true end
		local lineText = tab.buffer:GetLine(tab.caretLine)
		local lineLen = UTF8.len(lineText)
		if tab.caretCol <= lineLen then
			local ch = UTF8.sub(lineText, tab.caretCol, tab.caretCol)
			tab.buffer:DeleteRange(tab.caretLine, tab.caretCol, tab.caretLine, tab.caretCol + 1)
			tab.undo:Push({ sLine = tab.caretLine, sCol = tab.caretCol, oldText = ch, newText = "" }, "Delete")
			afterEdit(tab, tab.caretLine)
			return true
		end
		if tab.caretLine < tab.buffer:GetLineCount() then
			tab.buffer:DeleteRange(tab.caretLine, lineLen + 1, tab.caretLine + 1, 1)
			tab.undo:Push({ sLine = tab.caretLine, sCol = lineLen + 1, oldText = "\n", newText = "" }, nil)
			afterEdit(tab, tab.caretLine)
			return true
		end
		return false
	end
	s.deleteForward = deleteForward

	local function deleteWordBackward(tab)
		if deleteSelectionCommon(tab) then return true end
		local lineText = tab.buffer:GetLine(tab.caretLine)
		local i = tab.caretCol
		local function isWc(ch)
			return ch ~= "" and ch:match("^[%w_]$") ~= nil
		end
		local start = i
		-- consume trailing word chars
		while start > 1 do
			local ch = UTF8.sub(lineText, start - 1, start - 1)
			if isWc(ch) then start = start - 1 else break end
		end
		if start == i then
			-- consume whitespace run instead
			while start > 1 do
				local ch = UTF8.sub(lineText, start - 1, start - 1)
				if ch == " " or ch == "\t" then start = start - 1 else break end
			end
		end
		if start < i then
			local deleted = UTF8.sub(lineText, start, i - 1)
			tab.buffer:DeleteRange(tab.caretLine, start, tab.caretLine, i)
			tab.undo:Push({ sLine = tab.caretLine, sCol = start, oldText = deleted, newText = "" }, nil)
			tab.caretCol = start
			afterEdit(tab, tab.caretLine)
			return true
		end
		return false
	end
	s.deleteWordBackward = deleteWordBackward

	-- Enter with auto-indent + pair expansion
	local MATCHING = { ["("] = ")", ["{"] = "}", ["["] = "]" }
	local function pressEnter(tab)
		local lineText = tab.buffer:GetLine(tab.caretLine)
		local col = tab.caretCol
		local lineLen = UTF8.len(lineText)
		local before = UTF8.sub(lineText, 1, col - 1)
		local after = UTF8.sub(lineText, col, lineLen)
		local indent = before:match("^[ \t]*") or ""
		local trimmed = (before:gsub("[ \t]+$", ""))
		local extra = ""
		local lastChar = trimmed:sub(-1)
		if lastChar == "(" or lastChar == "{" or lastChar == "["
			or trimmed:match("%f[%a]then$") or trimmed:match("%f[%a]do$")
			or trimmed:match("%f[%a]repeat$") or trimmed:match("%f[%a]function$")
			or trimmed:match("%f[%a]function[%w_%.%:]*%([^%)]*$") then
			extra = "\t"
		end
		if MATCHING[lastChar] and MATCHING[lastChar] == after:sub(1, 1) then
			-- expanding "(|)" into a block
			insertTextCommon(tab, "\n" .. indent .. "\t" .. "\n" .. indent, nil)
			tab.caretLine = tab.caretLine - 1
			tab.caretCol = UTF8.len(indent .. "\t") + 1
			tab.goalCol = nil
			s.renderDirty = true
			return
		end
		insertTextCommon(tab, "\n" .. indent .. extra, nil)
	end
	s.pressEnter = pressEnter

	-- Tab / Shift+Tab on selected lines
	local function indentLines(tab, outdent)
		local sLine, eLine = tab.caretLine, tab.caretLine
		local selA, selB, selC, selD = getSelection(tab)
		if selA then sLine, eLine = selA, selC end
		local edits = {}
		for li = sLine, eLine do
			local lineText = tab.buffer:GetLine(li)
			if outdent then
				if lineText:sub(1, 1) == "\t" then
					tab.buffer:DeleteRange(li, 1, li, 2)
					table.insert(edits, { sLine = li, sCol = 1, oldText = "\t", newText = "" })
					if tab.caretLine == li then tab.caretCol = math.max(1, tab.caretCol - 1) end
					if tab.anchor and tab.anchor.line == li then tab.anchor.col = math.max(1, tab.anchor.col - 1) end
				else
					local spaces = #(lineText:match("^ +") or "")
					local remove = math.min(spaces, TAB_WIDTH)
					if remove > 0 then
						local rm = lineText:sub(1, remove)
						tab.buffer:DeleteRange(li, 1, li, remove + 1)
						table.insert(edits, { sLine = li, sCol = 1, oldText = rm, newText = "" })
						if tab.caretLine == li then tab.caretCol = math.max(1, tab.caretCol - remove) end
						if tab.anchor and tab.anchor.line == li then tab.anchor.col = math.max(1, tab.anchor.col - remove) end
					end
				end
			else
				tab.buffer:InsertText(li, 1, "\t")
				table.insert(edits, { sLine = li, sCol = 1, oldText = "", newText = "\t" })
				if tab.caretLine == li then tab.caretCol = tab.caretCol + 1 end
				if tab.anchor and tab.anchor.line == li then tab.anchor.col = tab.anchor.col + 1 end
			end
		end
		if #edits > 0 then
			tab.undo:PushBatch(edits)
			afterEdit(tab, sLine)
		end
	end
	s.indentLines = indentLines

	local function performUndo(tab)
		local trans = tab.undo:Undo(tab.buffer)
		if not trans then
			setStatus("Nothing to undo")
			return false
		end
		local e = trans.edits[1]
		local endL, endC = Util.textExtent(e.sLine, e.sCol, e.oldText)
		tab.caretLine, tab.caretCol = endL, endC
		tab.anchor = nil
		tab.goalCol = nil
		afterEdit(tab, math.min(e.sLine, tab.buffer:GetLineCount()))
		tab.scrollToCaret = true
		return true
	end
	s.performUndo = performUndo

	local function performRedo(tab)
		local trans = tab.undo:Redo(tab.buffer)
		if not trans then
			setStatus("Nothing to redo")
			return false
		end
		local e = trans.edits[1]
		local endL, endC = Util.textExtent(e.sLine, e.sCol, e.newText)
		tab.caretLine, tab.caretCol = endL, endC
		tab.anchor = nil
		tab.goalCol = nil
		afterEdit(tab, math.min(e.sLine, tab.buffer:GetLineCount()))
		tab.scrollToCaret = true
		return true
	end
	s.performRedo = performRedo

	-- clipboard --------------------------------------------------------------
	local function copySelectionToClipboard()
		local tab = currentTab()
		if not tab then return end
		local a, b, c, d = getSelection(tab)
		if not a then
			setStatus("Nothing selected")
			return
		end
		local text = tab.buffer:GetTextRange(a, b, c, d)
		local ok, res = pcall(function()
			if typeof(setclipboard) == "function" then
				setclipboard(text)
				return true
			end
			return false, "setclipboard unavailable"
		end)
		if ok and res then
			setStatus("Copied " .. Util.comma(UTF8.len(text)) .. " chars")
		else
			setStatus("Clipboard unavailable in this executor", true)
		end
	end
s.copySelectionToClipboard = copySelectionToClipboard

	-- Paste: prefer getclipboard(); otherwise a hidden TextBox focused with a
	-- synthesized Ctrl+V via the executor's keypress/makepatched APIs.
	local function readClipboard()
		local ok, res = pcall(function()
			if type(getclipboard) == "function" then
				local clip = getclipboard()
				if type(clip) == "string" then return clip end
			end
			local box = Instance.new("TextBox")
			box.Name = "MiniIDE_PasteCatcher"
			box.Size = UDim2.fromOffset(1, 1)
			box.Position = UDim2.fromOffset(-1000, -1000)
			box.Text = ""
			box.ClearTextOnFocus = false
			box.Visible = true
			box.Parent = s.gui
			box:CaptureFocus()
			if type(keypress) == "function" and type(keyrelease) == "function" then
				keypress(17) -- VK_CONTROL
				keypress(86) -- VK_V
				keyrelease(86)
				keyrelease(17)
				task.wait(0.06)
			end
			local clip = box.Text
			box:Destroy()
			return clip
		end)
		if ok and type(res) == "string" then
			return res
		end
		return ""
	end
	s.readClipboard = readClipboard

	local LARGE_PASTE = 6000
	local CHUNK_SIZE = 2048
	local function pasteClipboard()
		local tab = currentTab()
		if not tab or s.pasting then return end
		local text = readClipboard()
		if text == "" then
			setStatus("Clipboard empty or unavailable", true)
			return
		end
		text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
		if #text <= LARGE_PASTE then
			insertTextCommon(tab, text, nil)
			tab.scrollToCaret = true
			return
		end
		-- large paste: chunk across frames so the game never freezes
		s.pasting = true
		setStatus("Pasting " .. Util.comma(#text) .. " characters…", true)
		local startL, startC = tab.caretLine, tab.caretCol
		local edits = {}
		local sel = getSelection(tab)
		if sel then
			local a, b, c, d = getSelection(tab)
			local deleted = tab.buffer:GetTextRange(a, b, c, d)
			tab.buffer:DeleteRange(a, b, c, d)
			table.insert(edits, { sLine = a, sCol = b, oldText = deleted, newText = "" })
			tab.caretLine, tab.caretCol = a, b
			tab.anchor = nil
		end
		local pos = 1
		local curL, curC = tab.caretLine, tab.caretCol
		task.spawn(function()
			while pos <= #text do
				local target = math.min(pos + CHUNK_SIZE - 1, #text)
				local boundary = target
				-- back off to a UTF-8 codepoint boundary
				while boundary > pos and boundary < #text do
					local b = string.byte(text, boundary + 1)
					if b < 0x80 or b >= 0xC0 then break end
					boundary = boundary - 1
				end
				if boundary < pos then boundary = target end
				local piece = text:sub(pos, boundary)
				local eL, eC = tab.buffer:InsertText(curL, curC, piece)
				curL, curC = eL, eC
				pos = boundary + 1
				tab.tokenizer:InvalidateFrom(curL)
				tab.minimapDirty = true
				tab.modified = true
				s.renderDirty = true
				task.wait() -- yield a frame per chunk
			end
			tab.caretLine, tab.caretCol = curL, curC
			table.insert(edits, { sLine = startL, sCol = startC, oldText = "", newText = text })
			tab.undo:PushBatch(edits)
			afterEdit(tab, startL)
			tab.scrollToCaret = true
			s.pasting = false
			setStatus("Pasted " .. Util.comma(#text) .. " characters")
			updateTabChrome()
		end)
	end
	s.pasteClipboard = pasteClipboard

	-- ---------------------------------------------------------------- rendering
	local updateStatusBar -- forward declaration (assigned below)
	local LINE_PAD = 8
	local RENDER_BYTE_CAP = 4096
	local pools = {
		labels = {},      -- text labels (visible lines)
		gutter = {},      -- line number labels
		fold = {},        -- fold arrow buttons
		selection = {},   -- selection rectangles
		match = {},       -- find match rectangles
		minimapRows = {}, -- minimap ink bars
	}
	s.pools = pools

	local function ensureIn(pool, i, maker)
		local inst = pool[i]
		if not inst then
			inst = maker()
			pool[i] = inst
		end
		inst.Visible = true
		return inst
	end

	local function hideFrom(pool, firstHidden)
		for i = firstHidden, #pool do
			pool[i].Visible = false
		end
	end

	s.caretFrame.ZIndex = 6
	s.currentLineFrame.ZIndex = 0

	local function ensuredCaretFrame()
		return s.caretFrame
	end

	local function makeLineLabel()
		local lbl = mk("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Font = s.mono,
			TextSize = s.fontSize,
			ZIndex = 3,
		}, s.lineLayer)
		return lbl
	end

	local function makeGutterLabel()
		local lbl = mk("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Center,
			Font = s.mono,
			TextSize = 11,
			ZIndex = 3,
		}, s.gutter)
		return lbl
	end

	local function makeFoldButton()
		local btn = mk("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "▾",
			Font = s.uiFont,
			TextSize = 12,
			ZIndex = 4,
		}, s.gutter)
		btn.MouseButton1Click:Connect(function()
			local tab = s.activeTab
			if tab and btn.Line then
				toggleFold(tab, btn.Line)
				s.renderAll()
			end
		end)
		return btn
	end

	local function makeSelFrame()
		return mk("Frame", {
			BackgroundColor3 = s.theme.Selection,
			BackgroundTransparency = s.theme.SelectionAlpha,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, s.selectionLayer)
	end

	local function makeMatchFrame()
		return mk("Frame", {
			BackgroundColor3 = s.theme.Match,
			BackgroundTransparency = s.theme.MatchAlpha,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, s.matchLayer)
	end

	-- Build RichText for an expanded line from original-byte token ranges.
	local function buildExpandedRich(line, tokens, colors, expanded, byteMap)
		local parts = {}
		local expLen = #expanded
		local capByte = RENDER_BYTE_CAP
		for _, tok in ipairs(tokens) do
			local sc = UTF8.byteToCharCol(line, tok.s)
			local ec = UTF8.byteToCharCol(line, tok.e + 1)
			local eStart = (byteMap[sc] or 0) + 1
			local eEnd = byteMap[ec] or expLen
			if eStart > capByte then break end
			eEnd = math.min(eEnd, capByte)
			if eEnd >= eStart then
				local seg = expanded:sub(eStart, eEnd)
				seg = seg:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
				local color = colors[tok.t]
				if color then
					parts[#parts + 1] = '<font color="' .. color .. '">' .. seg .. "</font>"
				else
					parts[#parts + 1] = seg
				end
			end
		end
		return table.concat(parts)
	end

	local function renderAll()
		local tab = s.activeTab
		if not tab then return end
		local theme = s.theme
		if tab.foldsDirty then
			recomputeFolds(tab)
			tab.foldsDirty = false
		end
		rebuildVisualMap(tab)
		local buffer = tab.buffer
		local lineCount = buffer:GetLineCount()
		local totalRows = tab.totalRows
		local viewH = s.textHeight or 1
		local viewW = s.textWidth or 1
		local totalH = totalRows * s.lineHeight
		tab.scrollY = math.clamp(tab.scrollY, 0, math.max(0, totalH - viewH))
		tab.scrollX = math.clamp(tab.scrollX, 0, math.max(0, (tab.contentWidth or 0) - viewW + LINE_PAD * 2))
		local firstRow = math.max(0, math.floor(tab.scrollY / s.lineHeight))
		local visibleRowCount = math.ceil(viewH / s.lineHeight) + 1
		local lastRow = math.min(totalRows - 1, firstRow + visibleRowCount)

		-- sync tokenizer exactly as far as we need to render
		if lastRow >= firstRow then
			buffer:GetLine(1)
			local lastNeeded = rowToLine(tab, lastRow)
			tab.tokenizer:Sync(buffer, lastNeeded)
		end

		local expandCache = {}
		local function expandOf(li, lineText)
			local c = expandCache[li]
			if not c then
				local expanded, map, byteMap, charCount = UTF8.expandTabs(lineText)
				c = { expanded = expanded, byteMap = byteMap, charCount = charCount }
				expandCache[li] = c
			end
			return c
		end

		local colors = theme.Syntax
		local gutterText = theme.GutterText
		local accent = theme.Accent
		local yBase = firstRow * s.lineHeight - tab.scrollY
		local maxTextWidth = 0
		local labelIdx, gutterIdx, foldIdx = 0, 0, 0
		local caretRow = lineToRow(tab, tab.caretLine)
		local selectionA, selectionB, selectionC, selectionD = getSelection(tab)
		local matchCurrentIndex = tab.finder.index

		-- precompute match rows (only matches in visible range)
		local matchesByLine = {}
		if #tab.finder.matches > 0 then
			local lo, hi = rowToLine(tab, firstRow), rowToLine(tab, lastRow)
			for mi, m in ipairs(tab.finder.matches) do
				if m.line > hi then break end
				if m.line >= lo then
					local bucket = matchesByLine[m.line]
					if not bucket then
						bucket = {}
						matchesByLine[m.line] = bucket
					end
					bucket[#bucket + 1] = { m = m, index = mi }
				end
			end
		end

		for row = firstRow, lastRow do
			local line = rowToLine(tab, row)
			local lineText = buffer:GetLine(line)
			local y = yBase + (row - firstRow) * s.lineHeight
			local info = expandOf(line, lineText)
			local expanded, byteMap = info.expanded, info.byteMap

			-- line label (RichText)
			labelIdx = labelIdx + 1
			local label = ensureIn(pools.labels, labelIdx, makeLineLabel)
			local tokens = tab.tokenizer:GetLineTokens(buffer, line)
			label.Text = buildExpandedRich(lineText, tokens, colors, expanded, byteMap)
			label.Position = UDim2.fromOffset(LINE_PAD - tab.scrollX, y)
			label.Size = UDim2.fromOffset(viewW + tab.scrollX + 400, s.lineHeight)
			label.TextColor3 = theme.Text
			label.TextSize = s.fontSize
			label.Font = s.mono
			label.ZIndex = 3

			local lineWidth = s.measure(expanded:sub(1, math.min(#expanded, 2048)), s.fontSize, s.mono)
			if lineWidth > maxTextWidth then maxTextWidth = lineWidth end

			-- gutter number
			gutterIdx = gutterIdx + 1
			local numLabel = ensureIn(pools.gutter, gutterIdx, makeGutterLabel)
			numLabel.Text = tostring(line)
			numLabel.Position = UDim2.fromOffset(0, y)
			numLabel.Size = UDim2.fromOffset(s.GUTTER_W - 18, s.lineHeight)
			numLabel.TextColor3 = (row == caretRow) and accent or gutterText
			numLabel.Font = s.mono
			numLabel.TextSize = 11

			-- fold arrow (only on fold-start lines)
			local fold = tab.folds[line]
			if fold then
				foldIdx = foldIdx + 1
				local arrow = ensureIn(pools.fold, foldIdx, makeFoldButton)
				arrow.Text = fold.collapsed and "▸" or "▾"
				arrow.Position = UDim2.fromOffset(s.GUTTER_W - 17, y + 1)
				arrow.Size = UDim2.fromOffset(15, s.lineHeight - 2)
				arrow.TextColor3 = theme.TextDim
				arrow.Line = line
			end
		end
		hideFrom(pools.labels, labelIdx + 1)
		hideFrom(pools.gutter, gutterIdx + 1)
		hideFrom(pools.fold, foldIdx + 1)

		-- current line highlight
		if caretRow >= firstRow and caretRow <= lastRow then
			s.currentLineFrame.Visible = true
			s.currentLineFrame.Size = UDim2.fromOffset(viewW, s.lineHeight)
			s.currentLineFrame.Position = UDim2.fromOffset(0, yBase + (caretRow - firstRow) * s.lineHeight)
		else
			s.currentLineFrame.Visible = false
		end

		-- selection rectangles
		local selIdx = 0
		if selectionA then
			for row = firstRow, lastRow do
				local line = rowToLine(tab, row)
				if line >= selectionA and line <= selectionC then
					local lineText = buffer:GetLine(line)
					local info = expandCache[line]
					if not info then
						local expanded, map, byteMap = UTF8.expandTabs(lineText)
						info = { expanded = expanded, byteMap = byteMap }
					end
					local y = yBase + (row - firstRow) * s.lineHeight
					local x1, x2
					if line == selectionA then
						x1 = LINE_PAD + s.measure(info.expanded:sub(1, info.byteMap[selectionB] or 0), s.fontSize, s.mono) - tab.scrollX
					else
						x1 = 0
					end
					if line == selectionC then
						x2 = LINE_PAD + s.measure(info.expanded:sub(1, info.byteMap[selectionD] or 0), s.fontSize, s.mono) - tab.scrollX
					else
						x2 = viewW
					end
					if x2 < x1 then x2 = x1 + 2 end
					selIdx = selIdx + 1
					local frame = ensureIn(pools.selection, selIdx, makeSelFrame)
					frame.BackgroundColor3 = theme.Selection
					frame.BackgroundTransparency = theme.SelectionAlpha
					frame.Position = UDim2.fromOffset(x1, y)
					frame.Size = UDim2.fromOffset(math.max(x2 - x1, 1), s.lineHeight)
				end
			end
		end
		hideFrom(pools.selection, selIdx + 1)

		-- find match rectangles
		local matchIdx = 0
		for line, bucket in pairs(matchesByLine) do
			local row = lineToRow(tab, line)
			if row >= firstRow and row <= lastRow then
				local y = yBase + (row - firstRow) * s.lineHeight
				local lineText = buffer:GetLine(line)
				local info = expandCache[line]
				if not info then
					local expanded, map, byteMap = UTF8.expandTabs(lineText)
					info = { expanded = expanded, byteMap = byteMap }
				end
				for _, entry in ipairs(bucket) do
					local m = entry.m
					local x1 = LINE_PAD + s.measure(info.expanded:sub(1, info.byteMap[m.col] or 0), s.fontSize, s.mono) - tab.scrollX
					local x2 = LINE_PAD + s.measure(info.expanded:sub(1, info.byteMap[m.col + m.len] or 0), s.fontSize, s.mono) - tab.scrollX
					matchIdx = matchIdx + 1
					local frame = ensureIn(pools.match, matchIdx, makeMatchFrame)
					local isCurrent = (entry.index == matchCurrentIndex)
					frame.BackgroundColor3 = isCurrent and theme.MatchCurrent or theme.Match
					frame.BackgroundTransparency = isCurrent and theme.MatchCurrentAlpha or theme.MatchAlpha
					frame.Position = UDim2.fromOffset(x1, y)
					frame.Size = UDim2.fromOffset(math.max(x2 - x1, 4), s.lineHeight)
				end
			end
		end
		hideFrom(pools.match, matchIdx + 1)

		-- caret
		local caretInfo = expandCache[tab.caretLine]
		if not caretInfo then
			local lineText = buffer:GetLine(tab.caretLine)
			local expanded, map, byteMap = UTF8.expandTabs(lineText)
			caretInfo = { expanded = expanded, byteMap = byteMap }
		end
		if caretRow >= firstRow and caretRow <= lastRow then
			local caretX = LINE_PAD + s.measure(caretInfo.expanded:sub(1, caretInfo.byteMap[tab.caretCol] or 0), s.fontSize, s.mono) - tab.scrollX
			s.caretFrame.Position = UDim2.fromOffset(caretX, yBase + (caretRow - firstRow) * s.lineHeight + 1)
			s.caretFrame.Size = UDim2.fromOffset(2, s.lineHeight - 2)
			s.caretFrame.Visible = s.caretVisible and s.focused
		else
			s.caretFrame.Visible = false
		end

		if s.renderBracketMatch then
			s.renderBracketMatch()
		end

		tab.contentWidth = maxTextWidth + LINE_PAD * 2 + 20

		-- scrollbars
		local totalTrackH = viewH
		local totalPx = math.max(totalH, 1)
		local thumbH = math.clamp(totalTrackH * (viewH / totalPx), 24, totalTrackH)
		local range = totalPx - viewH
		local thumbY = range > 0 and ((tab.scrollY / range) * (totalTrackH - thumbH)) or 0
		s.vThumb.Size = UDim2.new(1, -2, 0, thumbH)
		s.vThumb.Position = UDim2.fromOffset(1, thumbY)

		local contentW = math.max(tab.contentWidth, viewW)
		local hThumbW = math.clamp(viewW * (viewW / contentW), 24, viewW)
		local hRange = contentW - viewW
		local hThumbX = hRange > 0 and ((tab.scrollX / hRange) * (viewW - hThumbW)) or 0
		s.hThumb.Size = UDim2.new(0, hThumbW, 1, -2)
		s.hThumb.Position = UDim2.fromOffset(hThumbX, 1)

		updateStatusBar()
	end
	s.renderAll = renderAll

	-- status bar updater (assigned to the forward-declared local from 5g)
	updateStatusBar = function()
		local tab = s.activeTab
		if not tab then return end
		local a, b, c, d = getSelection(tab)
		local selLen = 0
		if a then
			selLen = UTF8.len(tab.buffer:GetTextRange(a, b, c, d))
		end
		local left = string.format("Ln %d, Col %d", tab.caretLine, tab.caretCol)
		if selLen > 0 then
			left = left .. string.format("   |   Sel %d", selLen)
		end
		s.statusLeft.Text = left
		local total = tab.buffer:GetLineCount()
		s.statusRight.Text = string.format("%s lines   ·   Luau   ·   %s", Util.comma(total), tab.modified and "modified" or "saved")
		if not s.focused then
			if s.statusCenter.Text == "" then
				s.statusCenter.Text = "click editor to focus"
			end
		end
	end
	s.updateStatusBar = updateStatusBar

	-- ------------------------------------------------------------------ minimap
	local MINI_ROW_H = 3
	local function updateMinimapViewport()
		local tab = s.activeTab
		if not tab then return end
		local mapH = s.minimapCanvas.AbsoluteSize.Y
		if mapH < 4 then return end
		local totalPx = math.max(tab.totalRows * s.lineHeight, 1)
		local viewH = math.max(s.textHeight or 1, 1)
		local vh = math.clamp(mapH * viewH / totalPx, 14, mapH)
		local range = totalPx - viewH
		local vy = 0
		if range > 0 then
			vy = (tab.scrollY / range) * (mapH - vh)
		end
		s.minimapViewport.Size = UDim2.fromOffset(s.MINIMAP_W - 4, vh)
		s.minimapViewport.Position = UDim2.fromOffset(2, vy)
	end
	s.updateMinimapViewport = updateMinimapViewport

	local function rebuildMinimap()
		local tab = s.activeTab
		if not tab then return end
		if not s.minimap.Visible then s.minimapDirty = false return end
		local mapH = s.minimapCanvas.AbsoluteSize.Y
		if mapH < 10 then return end
		local rows = math.max(1, math.floor(mapH / MINI_ROW_H))
		local lineCount = tab.buffer:GetLineCount()
		local lines = tab.buffer.Lines
		local theme = s.theme
		local maxW = s.MINIMAP_W - 10
		for r = 1, rows do
			local frame = pools.minimapRows[r]
			if not frame then
				frame = mk("Frame", {
					BackgroundColor3 = theme.MinimapInk,
					BorderSizePixel = 0,
				}, s.minimapCanvas)
				pools.minimapRows[r] = frame
			end
			frame.Visible = true
			frame.Position = UDim2.fromOffset(0, (r - 1) * MINI_ROW_H)
			frame.Size = UDim2.fromOffset(1, MINI_ROW_H - 1)
			local from = math.floor((r - 1) * lineCount / rows) + 1
			local to = math.max(from, math.floor(r * lineCount / rows))
			local maxLen = 0
			for li = from, math.min(to, lineCount) do
				local l = #(lines[li] or "")
				if l > maxLen then maxLen = l end
			end
			if maxLen == 0 then
				frame.Visible = false
			else
				frame.BackgroundColor3 = theme.MinimapInk
				frame.BackgroundTransparency = 0.2
				frame.Size = UDim2.fromOffset(math.min(math.max(math.floor(maxLen * 0.85), 2), maxW), MINI_ROW_H - 1)
			end
		end
		for i = rows + 1, #pools.minimapRows do
			pools.minimapRows[i].Visible = false
		end
		s.minimapDirty = false
		updateMinimapViewport()
	end
	s.rebuildMinimap = rebuildMinimap

	-- keep caret in view (vertical + horizontal), called when tab.scrollToCaret
	local function ensureCaretVisible(tab)
		local row = lineToRow(tab, tab.caretLine)
		local y = row * s.lineHeight
		if y < tab.scrollY then
			tab.scrollY = y
		elseif y + s.lineHeight > tab.scrollY + s.textHeight then
			tab.scrollY = y + s.lineHeight - s.textHeight
		end
		tab.scrollY = math.max(0, tab.scrollY)
		local lineText = tab.buffer:GetLine(tab.caretLine)
		local expanded, _, byteMap = UTF8.expandTabs(lineText)
		local x = s.measure(expanded:sub(1, byteMap[tab.caretCol] or 0), s.fontSize, s.mono)
		if x + 40 > tab.scrollX + s.textWidth then
			tab.scrollX = x + 40 - s.textWidth
		end
		if x < tab.scrollX then
			tab.scrollX = math.max(0, x - 40)
		end
		tab.scrollToCaret = false
		s.renderDirty = true
	end
	s.ensureCaretVisible = ensureCaretVisible

	local function scrollToRow(tab, row)
		local totalH = math.max(tab.totalRows * s.lineHeight, 1)
		tab.scrollY = math.clamp(row * s.lineHeight, 0, math.max(0, totalH - s.textHeight))
		s.renderDirty = true
	end

	local function moveVertical(tab, deltaRows, extend)
		local goal = tab.goalCol or tab.caretCol
		local row = lineToRow(tab, tab.caretLine)
		local targetRow = math.clamp(row + deltaRows, 0, tab.totalRows - 1)
		local newLine = rowToLine(tab, targetRow)
		local newCol = math.clamp(goal, 1, tab.buffer:GetLineLength(newLine) + 1)
		setCaretRaw(tab, newLine, newCol, extend)
		tab.goalCol = goal -- preserve sticky column across repeated vertical moves
		tab.scrollToCaret = true
		s.renderDirty = true
	end

	local function moveHorizontal(tab, delta, extend, byWord)
		local lineText = tab.buffer:GetLine(tab.caretLine)
		local lineLen = UTF8.len(lineText)
		local col = tab.caretCol
		if byWord then
			local function isWc(ch)
				return ch:match("^[%w_]$") ~= nil
			end
			if delta < 0 then
				local i = col
				while i > 1 and not isWc(UTF8.sub(lineText, i - 1, i - 1)) do i = i - 1 end
				while i > 1 and isWc(UTF8.sub(lineText, i - 1, i - 1)) do i = i - 1 end
				col = i
			else
				local i = col
				while i <= lineLen and not isWc(UTF8.sub(lineText, i, i)) do i = i + 1 end
				while i <= lineLen and isWc(UTF8.sub(lineText, i, i)) do i = i + 1 end
				col = i
			end
			setCaretRaw(tab, tab.caretLine, col, extend)
			tab.scrollToCaret = true
			return
		end
		col = col + delta
		if col > lineLen + 1 then
			if tab.caretLine < tab.buffer:GetLineCount() then
				setCaretRaw(tab, tab.caretLine + 1, 1, extend)
			else
				setCaretRaw(tab, tab.caretLine, lineLen + 1, extend)
			end
		elseif col < 1 then
			if tab.caretLine > 1 then
				local prevLine = tab.caretLine - 1
				setCaretRaw(tab, prevLine, tab.buffer:GetLineLength(prevLine) + 1, extend)
			else
				setCaretRaw(tab, 1, 1, extend)
			end
		else
			setCaretRaw(tab, tab.caretLine, col, extend)
		end
		tab.scrollToCaret = true
	end

	local function moveSmartHomeEnd(tab, toEnd, extend)
		local line = tab.caretLine
		local lineText = tab.buffer:GetLine(line)
		if toEnd then
			setCaretRaw(tab, line, UTF8.len(lineText) + 1, extend)
		else
			-- first non-whitespace col; toggle to col 1 if already there
			local firstNonWs = lineText:match("^[ \t]*()")
			local target = (firstNonWs and tonumber(firstNonWs)) or 1
			local targetCol = UTF8.byteToCharCol(lineText, target)
			if tab.caretCol == targetCol then targetCol = 1 end
			setCaretRaw(tab, line, targetCol, extend)
		end
		tab.scrollToCaret = true
	end
	s.moveVertical, s.moveHorizontal, s.moveSmartHomeEnd = moveVertical, moveHorizontal, moveSmartHomeEnd

	-- -------------------------------------------------------------------- input
	local function isShiftDown()
		return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	end
	local function isCtrlDown()
		return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	end
	local function textEntryFocused()
		local ok, foc = pcall(function()
			return UserInputService:GetFocusedTextBox()
		end)
		return ok and foc ~= nil
	end

	local function wordRangeAt(lineText, col)
		local len = UTF8.len(lineText)
		local function isWc(c)
			local ch = UTF8.sub(lineText, c, c)
			return ch:match("^[%w_]$") ~= nil
		end
		local i = col
		if i > len then i = len end
		if i < 1 then return nil end
		if (not isWc(i)) and i > 1 and isWc(i - 1) then
			i = i - 1
		end
		if not isWc(i) then return nil end
		local a = i
		while a > 1 and isWc(a - 1) do a = a - 1 end
		local b = i
		while b < len and isWc(b + 1) do b = b + 1 end
		return a, b + 1
	end
	s.wordRangeAt = wordRangeAt

	local function selectAll(tab)
		tab.anchor = { line = 1, col = 1 }
		local last = tab.buffer:GetLineCount()
		tab.caretLine = last
		tab.caretCol = tab.buffer:GetLineLength(last) + 1
		tab.goalCol = nil
		tab.scrollToCaret = true
		s.renderDirty = true
	end
s.selectAll = selectAll

	local function selectCurrentLine(tab)
		local line = tab.caretLine
		tab.anchor = { line = line, col = 1 }
		tab.caretCol = tab.buffer:GetLineLength(line) + 1
		tab.goalCol = nil
		s.renderDirty = true
	end

	local function cutSelection()
		local tab = s.activeTab
		if not tab then return end
		local a, b, c, d = getSelection(tab)
		if not a then
			setStatus("Nothing selected")
			return
		end
		s.copySelectionToClipboard()
		deleteSelectionCommon(tab)
	end
	s.cutSelection = cutSelection

	local function pageRows()
		return math.max(1, math.floor((s.textHeight or 400) / s.lineHeight) - 1)
	end

	-- duplicate the current line (or every line the selection touches) below it
	local function duplicateLines(tab)
		local a, b = tab.caretLine, tab.caretLine
		local selLineA, _, selLineB = getSelection(tab)
		if selLineA then
			a, b = selLineA, selLineB
		end
		local parts = {}
		for i = a, b do
			parts[#parts + 1] = tab.buffer:GetLine(i)
		end
		local text = table.concat(parts, "\n")
		local endOfB = tab.buffer:GetLineLength(b) + 1
		local inserted = "\n" .. text
		tab.buffer:InsertText(b, endOfB, inserted)
		tab.undo:PushBatch({ { sLine = b, sCol = endOfB, oldText = "", newText = inserted } })
		local lineDelta = b - a + 1
		tab.caretLine = tab.caretLine + lineDelta
		tab.anchor = nil
		tab.goalCol = nil
		afterEdit(tab, b)
		tab.scrollToCaret = true
	end
	s.duplicateLines = duplicateLines

	local function repeatableKey(keyCode)
		if keyCode == Enum.KeyCode.Backspace or keyCode == Enum.KeyCode.Delete
			or keyCode == Enum.KeyCode.Left or keyCode == Enum.KeyCode.Right
			or keyCode == Enum.KeyCode.Up or keyCode == Enum.KeyCode.Down
			or keyCode == Enum.KeyCode.Home or keyCode == Enum.KeyCode.End
			or keyCode == Enum.KeyCode.PageUp or keyCode == Enum.KeyCode.PageDown
			or keyCode == Enum.KeyCode.Enter then
			return true
		end
		local map = getKeymap()
		return map[keyCode] ~= nil
	end
	s.repeatableKey = repeatableKey

	-- single, unified key action (used by both InputBegan and key repeat)
	local function fireKeyAction(keyCode)
		local tab = s.activeTab
		if not tab or s.minimized then return end
		local shift = isShiftDown()
		local ctrl = isCtrlDown()
		local map = getKeymap()

		-- character keys
		local entry = map[keyCode]
		if entry and not ctrl then
			typeChar(tab, shift and entry.upper or entry.lower)
			tab.scrollToCaret = true
			return
		end

		if keyCode == Enum.KeyCode.Backspace then
			if ctrl then deleteWordBackward(tab) else backspace(tab) end
			tab.scrollToCaret = true
			return
		end
		if keyCode == Enum.KeyCode.Delete then
			deleteForward(tab)
			tab.scrollToCaret = true
			return
		end
		if keyCode == Enum.KeyCode.Enter then
			s.pressEnter(tab)
			tab.scrollToCaret = true
			return
		end
		if keyCode == Enum.KeyCode.Tab then
			indentLines(tab, shift)
			return
		end
		if keyCode == Enum.KeyCode.Left then
			moveHorizontal(tab, -1, shift, ctrl)
			return
		end
		if keyCode == Enum.KeyCode.Right then
			moveHorizontal(tab, 1, shift, ctrl)
			return
		end
		if keyCode == Enum.KeyCode.Up then
			moveVertical(tab, -1, shift)
			return
		end
		if keyCode == Enum.KeyCode.Down then
			moveVertical(tab, 1, shift)
			return
		end
		if keyCode == Enum.KeyCode.PageUp then
			moveVertical(tab, -pageRows(), shift)
			return
		end
		if keyCode == Enum.KeyCode.PageDown then
			moveVertical(tab, pageRows(), shift)
			return
		end
		if keyCode == Enum.KeyCode.Home then
			if ctrl then
				setCaretRaw(tab, 1, 1, shift)
				tab.scrollToCaret = true
				s.renderDirty = true
			else
				moveSmartHomeEnd(tab, false, shift)
			end
			return
		end
		if keyCode == Enum.KeyCode.End then
			if ctrl then
				local last = tab.buffer:GetLineCount()
				setCaretRaw(tab, last, tab.buffer:GetLineLength(last) + 1, shift)
				tab.scrollToCaret = true
				s.renderDirty = true
			else
				moveSmartHomeEnd(tab, true, shift)
			end
			return
		end
	end
	s.fireKeyAction = fireKeyAction

	local function registerHeld(keyCode)
		s.held[keyCode] = os.clock()
		s.lastRepeat[keyCode] = os.clock()
	end

	local function clearHeld()
		for k in pairs(s.held) do s.held[k] = nil end
		for k in pairs(s.lastRepeat) do s.lastRepeat[k] = nil end
	end
	s.clearHeld = clearHeld

	local function updateKeyRepeat()
		local now = os.clock()
		local initialDelay = 0.42
		local interval = 0.03
		for keyCode, pressedAt in pairs(s.held) do
			if now - pressedAt >= initialDelay then
				local last = s.lastRepeat[keyCode] or pressedAt
				if now - last >= interval then
					s.lastRepeat[keyCode] = now
					fireKeyAction(keyCode)
				end
			end
		end
	end
	s.updateKeyRepeat = updateKeyRepeat

	local function handleEscape()
		if s.acVisible then
			s.hideAutocomplete()
			return
		end
		if s.findOpen then
			s.closeFind()
			return
		end
		local tab = s.activeTab
		if tab and tab.anchor then
			tab.anchor = nil
			s.renderDirty = true
			return
		end
		s.focused = false
		s.clearHeld()
		s.renderDirty = true
		setStatus("Focus released — click the editor to type")
	end
	s.handleEscape = handleEscape

	-- global keyboard entry point ---------------------------------------------
	local function onInputBegan(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local keyCode = input.KeyCode
			-- Escape must work even while a text entry box (find, dialogs) has focus
			if keyCode == Enum.KeyCode.Escape then
				if s.inputOverlay and s.inputOverlay.Visible then
					s.inputOverlay.Visible = false
					pcall(function() s.inputBox:ReleaseFocus() end)
					s.focused = true
					s.renderDirty = true
					return
				end
				if s.findOpen or s.acVisible then
					handleEscape()
					return
				end
			end
			if textEntryFocused() then return end
			if keyCode == Enum.KeyCode.Unknown then return end

			-- focus tracking: any click outside the window blurs the editor
			local ctrl = isCtrlDown()
			local shift = isShiftDown()

			if not s.focused then return end
			if s.minimized then return end

			if ctrl then
				local tab = s.activeTab
				if keyCode == Enum.KeyCode.S then
					s.saveActive()
				elseif keyCode == Enum.KeyCode.F then
					s.openFind(false)
				elseif keyCode == Enum.KeyCode.H then
					s.openFind(true)
				elseif keyCode == Enum.KeyCode.A and tab then
					selectAll(tab)
				elseif keyCode == Enum.KeyCode.Z then
					if tab then if shift then performRedo(tab) else performUndo(tab) end end
				elseif keyCode == Enum.KeyCode.Y then
					if tab then performRedo(tab) end
				elseif keyCode == Enum.KeyCode.C then
					s.copySelectionToClipboard()
				elseif keyCode == Enum.KeyCode.X then
					cutSelection()
				elseif keyCode == Enum.KeyCode.V then
					s.pasteClipboard()
				elseif keyCode == Enum.KeyCode.N then
					s.newTab()
				elseif keyCode == Enum.KeyCode.W then
					if tab then s.closeTab(tab) end
				elseif keyCode == Enum.KeyCode.L and tab then
					selectCurrentLine(tab)
				elseif keyCode == Enum.KeyCode.D and tab then
					duplicateLines(tab)
				end
				return
			end

			if keyCode == Enum.KeyCode.Escape then
				handleEscape()
				return
			end
			if s.pasting then return end

			-- autocomplete navigation takes precedence when open
			if s.acVisible then
				if keyCode == Enum.KeyCode.Up then s.acMoveSelection(-1) return end
				if keyCode == Enum.KeyCode.Down then s.acMoveSelection(1) return end
				if keyCode == Enum.KeyCode.Return or keyCode == Enum.KeyCode.KeypadEnter or keyCode == Enum.KeyCode.Tab then
					s.acAccept()
					return
				end
			end

			-- find panel: Enter / Shift+Enter navigate matches
			if s.findOpen and (keyCode == Enum.KeyCode.Return or keyCode == Enum.KeyCode.KeypadEnter) then
				if isShiftDown() then s.findPrev() else s.findNext() end
				return
			end

			fireKeyAction(keyCode)
			if s.acRefresh then s.acRefresh() end
			if repeatableKey(keyCode) then
				registerHeld(keyCode)
			end
			return
		end

		-- mouse focus tracking -----------------------------------------------
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local pos = input.Position
			local absPos = window.AbsolutePosition
			local absSize = window.AbsoluteSize
			local inside = pos.X >= absPos.X and pos.Y >= absPos.Y
				and pos.X <= absPos.X + absSize.X and pos.Y <= absPos.Y + absSize.Y
			if inside then
				s.focused = true
			else
				s.focused = false
				s.clearHeld()
			end
			s.renderDirty = true
		end
	end
	s.maid:Give(UserInputService.InputBegan:Connect(onInputBegan))

	s.maid:Give(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			s.held[input.KeyCode] = nil
			s.lastRepeat[input.KeyCode] = nil
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local tab = s.activeTab
			if tab and tab.anchor and tab.anchor.line == tab.caretLine and tab.anchor.col == tab.caretCol then
				tab.anchor = nil
			end
			s.dragSelect = false
			s.vDrag = false
			s.hDrag = false
			s.minimapDrag = false
			s.windowDrag = nil
			s.resizeDrag = nil
		end
	end))

	-- window focus lost while keys are held: drop them all
	s.maid:Give(UserInputService.WindowFocusReleased:Connect(function()
		clearHeld()
	end))

	-- mouse helpers -----------------------------------------------------------
	local function relativeTo(frame, pos)
		local absPos = frame.AbsolutePosition
		return pos.X - absPos.X, pos.Y - absPos.Y
	end
	s.relativeTo = relativeTo

	local function hitTest(tab, clipX, clipY)
		local row = math.floor((clipY + tab.scrollY) / s.lineHeight)
		row = math.clamp(row, 0, tab.totalRows - 1)
		local line = rowToLine(tab, row)
		local lineText = tab.buffer:GetLine(line)
		local expanded, map, byteMap = UTF8.expandTabs(lineText)
		local targetX = clipX + tab.scrollX - LINE_PAD
		local len = UTF8.len(lineText)
		local lo, hi = 1, len + 1
		while lo < hi do
			local mid = math.floor((lo + hi) / 2)
			local w = s.measure(expanded:sub(1, byteMap[mid] or 0), s.fontSize, s.mono)
			if w >= targetX then hi = mid else lo = mid + 1 end
		end
		local col = lo
		local leftX = s.measure(expanded:sub(1, byteMap[col] or 0), s.fontSize, s.mono)
		if col > 1 then
			local prevX = s.measure(expanded:sub(1, byteMap[col - 1] or 0), s.fontSize, s.mono)
			if (targetX - prevX) < (leftX - targetX) then
				col = col - 1
			end
		end
		return row, line, col, lineText
	end
	s.hitTest = hitTest

	-- true when a screen-space point lies inside a GuiObject's absolute bounds
	local function pointInFrame(frame, pos)
		if typeof(frame) ~= "Instance" then return false end
		local ok, absPos, absSize = pcall(function()
			return frame.AbsolutePosition, frame.AbsoluteSize
		end)
		if not ok or not absPos or not absSize then return false end
		return pos.X >= absPos.X and pos.Y >= absPos.Y
			and pos.X <= absPos.X + absSize.X and pos.Y <= absPos.Y + absSize.Y
	end

	-- mouse down inside the text area: position caret / selection / drag
	local function onTextAreaDown(input)
		local tab = s.activeTab
		if not tab then return end
		-- clicks landing on a visible overlay belong to the overlay, not the caret
		if (s.acVisible and pointInFrame(s.acPopup, input.Position))
			or (s.findOpen and pointInFrame(s.findPanel, input.Position))
			or (s.inputOverlay and s.inputOverlay.Visible and pointInFrame(s.inputOverlay, input.Position)) then
			return
		end
		if s.hideAutocomplete then s.hideAutocomplete() end
		local shift = isShiftDown()
		s.focused = true
		local clipX, clipY = relativeTo(s.textClip, input.Position)
		local row, line, col, lineText = hitTest(tab, clipX, clipY)

		local now = os.clock()
		if now - (s.lastClickAt or 0) < 0.35
			and math.abs(input.Position.X - (s.lastClickX or 0)) < 6
			and math.abs(input.Position.Y - (s.lastClickY or 0)) < 6 then
			s.clickCount = (s.clickCount or 0) + 1
		else
			s.clickCount = 1
		end
		s.lastClickAt, s.lastClickX, s.lastClickY = now, input.Position.X, input.Position.Y

		if s.clickCount >= 3 then
			-- triple click: select the whole line (plus trailing newline when present)
			local lineCount = tab.buffer:GetLineCount()
			if line < lineCount then
				tab.anchor = { line = line, col = 1 }
				tab.caretLine, tab.caretCol = line + 1, 1
			else
				tab.anchor = { line = line, col = 1 }
				tab.caretLine, tab.caretCol = line, tab.buffer:GetLineLength(line) + 1
			end
			tab.goalCol = nil
			s.renderDirty = true
			return
		end
		if s.clickCount == 2 then
			local a, b = wordRangeAt(lineText, col)
			if a then
				tab.anchor = { line = line, col = a }
				tab.caretLine, tab.caretCol = line, b
				tab.goalCol = nil
				s.renderDirty = true
				return
			end
		end
		if shift then
			if not tab.anchor then
				tab.anchor = { line = tab.caretLine, col = tab.caretCol }
			end
		else
			-- anchor is the drag origin; cleared on mouse-up if the drag never moved
			tab.anchor = { line = line, col = col }
		end
		tab.caretLine, tab.caretCol = line, col
		tab.goalCol = nil
		s.caretBlink = os.clock()
		s.caretVisible = true
		s.dragSelect = true
		s.renderDirty = true
	end
s.onTextAreaDown = onTextAreaDown

	-- drag selection across the whole editor area (gutter included)
	local function onGlobalMouseMove(input)
		if s.dragSelect and s.activeTab then
			local tab = s.activeTab
			local clipX, clipY = relativeTo(s.textClip, input.Position)
			clipX = math.clamp(clipX, -50, (s.textWidth or 400) + 50)
			clipY = math.clamp(clipY, -200, (s.textHeight or 400) + 200)
			-- auto-scroll when dragging past the edges
			if clipY < 0 then
				tab.scrollY = math.max(0, tab.scrollY - 2 * s.lineHeight)
			elseif clipY > (s.textHeight or 400) then
				tab.scrollY = tab.scrollY + 2 * s.lineHeight
			end
			local _, line, col = hitTest(tab, clipX, math.clamp(clipY, 0, s.textHeight - 1))
			tab.caretLine, tab.caretCol = line, col
			tab.goalCol = nil
			s.renderDirty = true
			return
		end
		if s.vDrag then
			local tab = s.activeTab
			if not tab then return end
			local trackTop = s.vTrack.AbsolutePosition.Y
			local trackH = s.vTrack.AbsoluteSize.Y
			local thumbH = s.vThumb.AbsoluteSize.Y
			local relY = input.Position.Y - trackTop - (s.vDragOffset or 0)
			local range = math.max(trackH - thumbH, 1)
			local frac = math.clamp(relY / range, 0, 1)
			local totalH = math.max(tab.totalRows * s.lineHeight, 1)
			local vRange = math.max(totalH - s.textHeight, 0)
			tab.scrollY = frac * vRange
			s.renderDirty = true
			return
		end
		if s.hDrag then
			local tab = s.activeTab
			if not tab then return end
			local trackLeft = s.hTrack.AbsolutePosition.X
			local trackW = s.hTrack.AbsoluteSize.X
			local thumbW = s.hThumb.AbsoluteSize.X
			local relX = input.Position.X - trackLeft - (s.hDragOffset or 0)
			local range = math.max(trackW - thumbW, 1)
			local frac = math.clamp(relX / range, 0, 1)
			local contentW = math.max(tab.contentWidth or s.textWidth, s.textWidth)
			local hRange = math.max(contentW - s.textWidth, 0)
			tab.scrollX = frac * hRange
			s.renderDirty = true
			return
		end
		if s.minimapDrag then
			local tab = s.activeTab
			if not tab then return end
			local mapH = s.minimapCanvas.AbsoluteSize.Y
			local mapTop = s.minimapCanvas.AbsolutePosition.Y
			local totalH = math.max(tab.totalRows * s.lineHeight, 1)
			local vRange = math.max(totalH - s.textHeight, 0)
			local caretCenter = s.textHeight / 2
			local frac = math.clamp((input.Position.Y - mapTop) / math.max(mapH, 1), 0, 1)
			tab.scrollY = math.clamp(frac * totalH - caretCenter, 0, vRange)
			s.renderDirty = true
			return
		end
		if s.windowDrag then
			local drag = s.windowDrag
			local dx = input.Position.X - drag.startInput.X
			local dy = input.Position.Y - drag.startInput.Y
			local newX = drag.startPosX + dx
			local newY = drag.startPosY + dy
			-- keep at least part of the window on screen
			local screenW = screen.X
			local screenH = screen.Y
			newX = math.clamp(newX, -s.winW + 80, screenW - 80)
			newY = math.clamp(newY, 0, screenH - 40)
			window.Position = UDim2.fromOffset(newX, newY)
			s.shadow.Position = UDim2.fromOffset(newX - 13, newY - 13)
			return
		end
		if s.resizeDrag then
			local drag = s.resizeDrag
			local dx = input.Position.X - drag.startInput.X
			local dy = input.Position.Y - drag.startInput.Y
			local w = drag.startW
			local h = drag.startH
			if drag.mode == "right" or drag.mode == "corner" then
				w = math.clamp(drag.startW + dx, 560, screen.X)
			end
			if drag.mode == "bottom" or drag.mode == "corner" then
				h = math.clamp(drag.startH + dy, 320, screen.Y)
			end
			window.Size = UDim2.fromOffset(w, h)
			s.winW, s.winH = w, h -- remember user size so minimize/restore honors it
			layout()
			return
		end
	end
s.onGlobalMouseMove = onGlobalMouseMove

	s.maid:Give(UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			onGlobalMouseMove(input)
		end
	end))

	-- wheel scrolling (Shift for horizontal) -----------------------------------
	local function onWheel(input)
		local tab = s.activeTab
		if not tab then return end
		local z = input.Position.Z
		local sign = z >= 0 and 1 or -1
		if math.abs(z) > 10 then z = z / 120 end
		if isShiftDown() then
			tab.scrollX = math.clamp(tab.scrollX - sign * 160, 0, math.max(0, (tab.contentWidth or 0) - s.textWidth))
		else
			local totalH = math.max(tab.totalRows * s.lineHeight, 1)
			tab.scrollY = math.clamp(tab.scrollY - sign * 3.2 * s.lineHeight, 0, math.max(0, totalH - s.textHeight))
		end
		s.renderDirty = true
	end
	s.onWheel = onWheel

	s.textClip.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onTextAreaDown(input)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			onWheel(input)
		end
	end)
	s.gutter.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			onWheel(input)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			s.focused = true
			s.renderDirty = true
		end
	end)
	s.minimap.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			onWheel(input)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			s.minimapDrag = true
			s.focused = true
			local tab = s.activeTab
			if tab then
				local mapH = s.minimapCanvas.AbsoluteSize.Y
				local mapTop = s.minimapCanvas.AbsolutePosition.Y
				local totalH = math.max(tab.totalRows * s.lineHeight, 1)
				local vRange = math.max(totalH - s.textHeight, 0)
				local frac = math.clamp((input.Position.Y - mapTop) / math.max(mapH, 1), 0, 1)
				tab.scrollY = math.clamp(frac * totalH - s.textHeight / 2, 0, vRange)
				s.renderDirty = true
			end
		end
	end)

	-- scrollbar thumb drags
	s.vThumb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			s.vDrag = true
			s.vDragOffset = input.Position.Y - s.vThumb.AbsolutePosition.Y
		end
	end)
	s.hThumb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			s.hDrag = true
			s.hDragOffset = input.Position.X - s.hThumb.AbsolutePosition.X
		end
	end)

	-- titlebar drag / minimize / close / theme ---------------------------------
	local function pointInButton(btn, pos)
		local p, sz = btn.AbsolutePosition, btn.AbsoluteSize
		return pos.X >= p.X and pos.Y >= p.Y and pos.X <= p.X + sz.X and pos.Y <= p.Y + sz.Y
	end
	s.titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- ignore presses that started on a title button (event bubbles up from children)
			for _, btn in ipairs({ s.minBtn, s.closeBtn, s.themeBtn }) do
				if pointInButton(btn, input.Position) then
					return
				end
			end
			s.windowDrag = {
				startInput = input.Position,
				startPosX = window.Position.X.Offset,
				startPosY = window.Position.Y.Offset,
			}
			s.focused = true
		end
	end)
	local function startResize(mode)
		return function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				s.resizeDrag = {
					mode = mode,
					startInput = input.Position,
					startW = window.AbsoluteSize.X,
					startH = window.AbsoluteSize.Y,
				}
			end
		end
	end
	s.gripRight.InputBegan:Connect(startResize("right"))
	s.gripBottom.InputBegan:Connect(startResize("bottom"))
	s.gripCorner.InputBegan:Connect(startResize("corner"))

	-- ------------------------------------------------------------- find & replace
	local FIND_H = 70
	local function paintToggleButton(btn, active)
		if active then
			btn.BackgroundColor3 = s.theme.Accent
			btn.TextColor3 = Color3.new(1, 1, 1)
		else
			btn.BackgroundColor3 = s.theme.Button
			btn.TextColor3 = s.theme.Text
		end
	end

	local function updateFindCounter()
		local tab = s.activeTab
		if not tab then return end
		local f = tab.finder
		if s.queryBox.Text == "" then
			s.matchLabel.Text = ""
		elseif #f.matches == 0 then
			s.matchLabel.Text = "0/0"
		elseif f.index > 0 then
			s.matchLabel.Text = string.format("%d/%d", f.index, #f.matches)
		else
			s.matchLabel.Text = string.format("%d match%s", #f.matches, #f.matches == 1 and "" or "es")
		end
	end

	local function refreshFindMatches()
		local tab = s.activeTab
		if not tab then return end
		local f = tab.finder
		f.query = s.queryBox.Text
		f.caseSensitive = s.caseActive == true
		f.wholeWord = s.wordActive == true
		f:Refresh(tab.buffer)
		updateFindCounter()
		s.renderDirty = true
	end
	s.refreshFindMatches = refreshFindMatches

	local function selectMatch(tab, m)
		tab.anchor = { line = m.line, col = m.col }
		tab.caretLine, tab.caretCol = m.line, m.col + m.len
		tab.goalCol = nil
		tab.scrollToCaret = true
		s.renderDirty = true
		updateFindCounter()
	end

	local function findNext()
		local tab = s.activeTab
		if not tab then return end
		local f = tab.finder
		local m = f:Next(tab.caretLine, tab.caretCol)
		if m then selectMatch(tab, m) end
	end
	s.findNext = findNext

	local function findPrev()
		local tab = s.activeTab
		if not tab then return end
		local f = tab.finder
		local m = f:Prev(tab.caretLine, tab.caretCol)
		if m then selectMatch(tab, m) end
	end
	s.findPrev = findPrev

	local function openFind(replaceMode)
		local tab = s.activeTab
		if not tab then return end
		s.findOpen = true
		-- seed the query with the current selection when it is single-line
		local a, b, c, d = getSelection(tab)
		if a then
			local sel = tab.buffer:GetTextRange(a, b, c, d)
			if not sel:find("\n", 1, true) and #sel <= 200 then
				s.queryBox.Text = sel
			end
		end
		local panel = s.findPanel
		panel.Visible = true
		panel.Size = UDim2.fromOffset(356, FIND_H)
		panel.BackgroundTransparency = 1
		tween(panel, TWEEN_POP, { BackgroundTransparency = 0 })
		refreshFindMatches()
		task.defer(function()
			if s.queryBox then
				s.queryBox:CaptureFocus()
				s.queryBox.CursorPosition = #s.queryBox.Text + 1
				s.queryBox.SelectionStart = 1
			end
		end)
	end
	s.openFind = openFind

	local function closeFind()
		s.findOpen = false
		local tab = s.activeTab
		if tab then
			tab.finder.matches = {}
			tab.finder.index = 0
		end
		local panel = s.findPanel
		tween(panel, TWEEN_FAST, { BackgroundTransparency = 1 })
		task.delay(0.16, function()
			if not s.findOpen then
				panel.Visible = false
			end
		end)
		s.renderDirty = true
		-- release the find box so typing goes back to the editor immediately
		if s.queryBox then
			pcall(function() s.queryBox:ReleaseFocus() end)
		end
		-- restore focus to the editor
		s.focused = true
	end
	s.closeFind = closeFind

	local function afterFinderReplaceAll(tab, fromLine)
		tab.modified = true
		tab.tokenizer:InvalidateFrom(fromLine or 1)
		tab.tokenizer:Prune(tab.buffer:GetLineCount())
		tab.foldsDirty = true
		tab.minimapDirty = true
		tab.finderDirty = false
		updateTabChrome()
		s.renderDirty = true
	end

	s.queryBox:GetPropertyChangedSignal("Text"):Connect(function()
		if s.findOpen then
			refreshFindMatches()
		end
	end)

	s.caseBtn.MouseButton1Click:Connect(function()
		s.caseActive = not s.caseActive
		paintToggleButton(s.caseBtn, s.caseActive)
		refreshFindMatches()
	end)
	s.wordBtn.MouseButton1Click:Connect(function()
		s.wordActive = not s.wordActive
		paintToggleButton(s.wordBtn, s.wordActive)
		refreshFindMatches()
	end)
	s.prevBtn.MouseButton1Click:Connect(findPrev)
	s.nextBtn.MouseButton1Click:Connect(findNext)
	s.closeFindBtn.MouseButton1Click:Connect(closeFind)
	s.replaceBtn.MouseButton1Click:Connect(function()
		local tab = s.activeTab
		if not tab then return end
		local f = tab.finder
		f.replacement = s.replBox.Text
		if f:ReplaceCurrent(tab.buffer, tab.undo, s.replBox.Text) then
			afterFinderReplaceAll(tab, 1)
			refreshFindMatches()
		else
			setStatus("No current match — press Enter to find next")
		end
	end)
	s.replaceAllBtn.MouseButton1Click:Connect(function()
		local tab = s.activeTab
		if not tab then return end
		local f = tab.finder
		f.replacement = s.replBox.Text
		local n = f:ReplaceAll(tab.buffer, tab.undo, s.replBox.Text)
		afterFinderReplaceAll(tab, 1)
		refreshFindMatches()
		setStatus(string.format("Replaced %d occurrence%s", n, n == 1 and "" or "s"))
		if n > 0 then
			s.toastMsg(string.format("Replaced %d occurrence%s", n, n == 1 and "" or "s"))
		end
	end)

	-- ----------------------------------------------------------- bracket match
	local BRACKETS = {
		["("] = { close = ")", open = true },
		["["] = { close = "]", open = true },
		["{"] = { close = "}", open = true },
		[")"] = { close = "(", open = false },
		["]"] = { close = "[", open = false },
		["}"] = { close = "{", open = false },
	}
	local MAX_BRACKET_SCAN = 4000
	pools.bracket = {}

	local function findBracketAt(tab)
		local lineText = tab.buffer:GetLine(tab.caretLine)
		local lineLen = UTF8.len(lineText)
		local col = tab.caretCol
		local ch = (col <= lineLen) and UTF8.sub(lineText, col, col) or ""
		local atCol = col
		if not BRACKETS[ch] then
			local back = (col > 1) and UTF8.sub(lineText, col - 1, col - 1) or ""
			if BRACKETS[back] then
				ch = back
				atCol = col - 1
			else
				return nil
			end
		end
		return ch, atCol
	end

	local function scanForBracket(tab, ch, atCol, lineIdx)
		local info = BRACKETS[ch]
		local isOpen = info.open
		local pair = info.close
		local fromByte = UTF8.charToByte(tab.buffer:GetLine(lineIdx), atCol)
		local i = lineIdx
		local depth = 0
		local scanned = 0
		while i >= 1 and i <= tab.buffer:GetLineCount() and scanned < MAX_BRACKET_SCAN do
			scanned = scanned + 1
			tab.tokenizer:Sync(tab.buffer, i)
			local cache = tab.tokenizer.LineCache[i]
			local lineText = tab.buffer:GetLine(i)
			local events = {}
			if cache then
				for _, t in ipairs(cache.tokens) do
					if t.t == "operator" then
						for j = t.s, t.e do
							local c = lineText:sub(j, j)
							if c == ch or c == pair then
								events[#events + 1] = { byte = j, isSelf = (c == ch) }
							end
						end
					end
				end
			end
			if not isOpen then
				local rev = {}
				for k = #events, 1, -1 do
					rev[#rev + 1] = events[k]
				end
				events = rev
			end
			for _, ev in ipairs(events) do
				local skip = false
				if i == lineIdx then
					if isOpen and ev.byte <= fromByte then
						skip = true
					elseif not isOpen and ev.byte >= fromByte then
						skip = true
					end
				end
				if not skip then
					if ev.isSelf then
						depth = depth + 1
					else
						depth = depth - 1
					end
					if depth < 0 then
						return i, UTF8.byteToCharCol(lineText, ev.byte)
					end
				end
			end
			i = i + (isOpen and 1 or -1)
		end
		return nil
	end

	local function computeBracketMatch(tab)
		local ch, atCol = findBracketAt(tab)
		if not ch then return nil end
		local pairLine, pairCol = scanForBracket(tab, ch, atCol, tab.caretLine)
		if not pairLine then
			return { { line = tab.caretLine, col = atCol, unmatched = true } }
		end
		return {
			{ line = tab.caretLine, col = atCol, unmatched = false },
			{ line = pairLine, col = pairCol, unmatched = false },
		}
	end

	local renderBracketFrames -- forward declaration

	local function renderBracketMatch()
		local tab = s.activeTab
		if not tab then
			hideFrom(pools.bracket, 1)
			return
		end
		local key = table.concat({ tab.id, tab.caretLine, tab.caretCol, tab.buffer.version }, ":")
		if s.bracketCacheKey ~= key then
			s.bracketCacheKey = key
			s.bracketCache = computeBracketMatch(tab)
		end
		renderBracketFrames(tab, s.bracketCache)
	end

	renderBracketFrames = function(tab, match)
		if not match then
			hideFrom(pools.bracket, 1)
			return
		end
		local idx = 0
		local firstRow = math.max(0, math.floor(tab.scrollY / s.lineHeight))
		local lastRow = firstRow + math.ceil((s.textHeight or 1) / s.lineHeight) + 1
		for _, m in ipairs(match) do
			local row = lineToRow(tab, m.line)
			if row >= firstRow and row <= lastRow then
				local lineText = tab.buffer:GetLine(m.line)
				local expanded, map, byteMap = UTF8.expandTabs(lineText)
				local x = LINE_PAD + s.measure(expanded:sub(1, byteMap[m.col] or 0), s.fontSize, s.mono) - tab.scrollX
				local w = s.measure(expanded:sub((byteMap[m.col] or 0) + 1, byteMap[m.col + 1] or #expanded), s.fontSize, s.mono)
				idx = idx + 1
				local frame = pools.bracket[idx]
				if not frame then
					frame = mk("Frame", {
						BackgroundTransparency = 0.72,
						BorderSizePixel = 0,
						ZIndex = 4,
					}, s.textClip)
					mk("UICorner", { CornerRadius = UDim.new(0, 2) }, frame)
					pools.bracket[idx] = frame
				end
				frame.Visible = true
				frame.BackgroundColor3 = m.unmatched and s.theme.Danger or s.theme.Accent
				frame.Position = UDim2.fromOffset(x, row * s.lineHeight - tab.scrollY)
				frame.Size = UDim2.fromOffset(math.max(w, 5), s.lineHeight)
			end
		end
		hideFrom(pools.bracket, idx + 1)
	end

	s.renderBracketMatch = renderBracketMatch

	-- ------------------------------------------------------------- autocomplete
	local AC_MAX = 9
	local AC_KEYWORDS = {}
	for w in pairs(KEYWORDS) do
		AC_KEYWORDS[#AC_KEYWORDS + 1] = w
	end
	local AC_GLOBALS = {}
	for w in pairs(BUILTINS) do
		AC_GLOBALS[#AC_GLOBALS + 1] = w
	end
	table.sort(AC_KEYWORDS)
	table.sort(AC_GLOBALS)

	s.acVisible = false
	s.acIndex = 1
	s.acResults = {}
	s.acPrefixStart = 1
	s.acForce = false

	local function repaintAc()
		local theme = s.theme
		for i = 1, AC_MAX do
			local entry = s.acRows[i]
			if entry.row.Visible then
				local selected = (i == s.acIndex)
				entry.row.BackgroundColor3 = selected and theme.Accent or theme.PanelBg
				entry.row.BackgroundTransparency = selected and 0 or 1
				entry.row.TextColor3 = selected and Color3.new(1, 1, 1) or theme.Text
				entry.tag.TextColor3 = selected and Color3.new(1, 1, 1) or theme.TextDim
			end
		end
	end

	local function acHide()
		s.acVisible = false
		s.acForce = false
		s.acPopup.Visible = false
		s.acPopup.Size = UDim2.fromOffset(240, 0)
	end
	s.hideAutocomplete = acHide

	local function collectCandidates(tab)
		if s.acCache and s.acCache.version == tab.buffer.version then
			return s.acCache.list
		end
		local freq = {}
		local lineCount = tab.buffer:GetLineCount()
		tab.tokenizer:Sync(tab.buffer, lineCount)
		for i = 1, lineCount do
			local cache = tab.tokenizer.LineCache[i]
			if cache then
				local lineText = cache.line
				for _, t in ipairs(cache.tokens) do
					if t.t == "ident" or t.t == "function" then
						local w = lineText:sub(t.s, t.e)
						if UTF8.len(w) >= 2 and not KEYWORDS[w] then
							freq[w] = (freq[w] or 0) + 1
						end
					end
				end
			end
		end
		local list = {}
		local seen = {}
		for _, w in ipairs(AC_KEYWORDS) do
			list[#list + 1] = { text = w, lower = w, kind = "keyword", score = 50 }
			seen[w] = true
		end
		for _, w in ipairs(AC_GLOBALS) do
			if not seen[w] then
				list[#list + 1] = { text = w, lower = w:lower(), kind = "global", score = 40 }
				seen[w] = true
			end
		end
		for w, f in pairs(freq) do
			if not seen[w] then
				list[#list + 1] = { text = w, lower = w:lower(), kind = "ident", score = f }
				seen[w] = true
			end
		end
		s.acCache = { version = tab.buffer.version, list = list }
		return list
	end

	local function acRefresh()
		local tab = s.activeTab
		if not tab or s.minimized then
			acHide()
			return
		end
		local lineText = tab.buffer:GetLine(tab.caretLine)
		local col = tab.caretCol
		local startCol = col
		while startCol > 1 do
			local ch = UTF8.sub(lineText, startCol - 1, startCol - 1)
			if ch:match("^[%w_]$") then
				startCol = startCol - 1
			else
				break
			end
		end
		local prefix = UTF8.sub(lineText, startCol, col - 1)
		if not s.acForce and #prefix < 2 then
			acHide()
			return
		end
		local lp = prefix:lower()
		local candidates = collectCandidates(tab)
		local scored = {}
		for _, cand in ipairs(candidates) do
			if cand.lower:sub(1, #lp) == lp and cand.text ~= prefix then
				scored[#scored + 1] = cand
			end
		end
		table.sort(scored, function(a, b)
			if a.score ~= b.score then return a.score > b.score end
			return a.text < b.text
		end)
		local results = {}
		for i = 1, math.min(#scored, AC_MAX) do
			results[i] = scored[i]
		end
		if #results == 0 then
			acHide()
			return
		end
		local wasVisible = s.acVisible
		s.acResults = results
		s.acPrefixStart = startCol
		s.acIndex = math.clamp(s.acIndex, 1, #results)
		if not wasVisible then s.acIndex = 1 end

		local expanded, _, byteMap = UTF8.expandTabs(lineText)
		local caretX = s.measure(expanded:sub(1, byteMap[col] or 0), s.fontSize, s.mono)
		local row = lineToRow(tab, tab.caretLine)
		local lineTop = row * s.lineHeight - tab.scrollY
		local areaH = s.editorHeight or 400
		local popupH = #results * 22
		local popupY = lineTop + s.lineHeight + 2
		if popupY + popupH > areaH then
			popupY = lineTop - popupH - 2
		end
		local areaW = s.editorWidth or 600
		local popupX = math.clamp(s.GUTTER_W + LINE_PAD + caretX - tab.scrollX + 2, 4, math.max(4, areaW - 244))
		s.acPopup.Position = UDim2.fromOffset(popupX, math.max(popupY, 2))
		s.acPopup.Size = UDim2.fromOffset(240, popupH)
		for i = 1, AC_MAX do
			local entry = s.acRows[i]
			if i <= #results then
				entry.row.Visible = true
				entry.row.Text = results[i].text
				entry.tag.Text = results[i].kind
			else
				entry.row.Visible = false
			end
		end
		if not wasVisible then
			s.acPopup.Visible = true
			s.acPopup.BackgroundTransparency = 1
			tween(s.acPopup, TWEEN_POP, { BackgroundTransparency = 0 })
		end
		s.acVisible = true
		repaintAc()
	end
	s.acRefresh = acRefresh

	local function acMoveSelection(delta)
		if not s.acVisible then return end
		local n = #s.acResults
		if n == 0 then return end
		s.acIndex = ((s.acIndex - 1 + delta) % n) + 1
		repaintAc()
	end
	s.acMoveSelection = acMoveSelection

	local function acAccept()
		local tab = s.activeTab
		if not tab or not s.acVisible then return end
		local item = s.acResults[s.acIndex]
		if not item then
			acHide()
			return
		end
		local startCol = s.acPrefixStart
		local col = tab.caretCol
		local line = tab.caretLine
		local deleted = tab.buffer:GetTextRange(line, startCol, line, col)
		tab.buffer:DeleteRange(line, startCol, line, col)
		tab.buffer:InsertText(line, startCol, item.text)
		local inserted = UTF8.len(item.text)
		tab.undo:PushBatch({
			{ sLine = line, sCol = startCol, oldText = deleted, newText = "" },
			{ sLine = line, sCol = startCol, oldText = "", newText = item.text },
		})
		tab.caretLine, tab.caretCol = line, startCol + inserted
		tab.goalCol = nil
		afterEdit(tab, line)
		tab.scrollToCaret = true
		acHide()
	end
	s.acAccept = acAccept

	for i, entry in ipairs(s.acRows) do
		entry.row.MouseButton1Click:Connect(function()
			if s.acVisible then
				s.acIndex = i
				s.acAccept()
			end
		end)
		entry.row.MouseEnter:Connect(function()
			if s.acVisible and s.acIndex ~= i then
				s.acIndex = i
				repaintAc()
			end
		end)
	end

	-- ---------------------------------------------------- file explorer & saving
	local function openFile(path)
		for _, tab in ipairs(s.tabs) do
			if tab.path == path then
				switchTab(tab)
				return tab
			end
		end
		local tab = newTabData()
		tab.path = path
		tab.name = FS.DisplayName(path)
		local data, err = FS.Read(path)
		if not data then
			toastMsg("Read failed: " .. tostring(err), true)
			data = ""
		end
		tab.buffer:SetText(data)
		tab.tokenizer:InvalidateAll()
		tab.modified = false
		rebuildVisualMap(tab)
		return finalizeNewTab(tab)
	end
	s.openFile = openFile

	local fileButtons = {}
	local function refreshFileList()
		for _, b in ipairs(fileButtons) do
			b:Destroy()
		end
		fileButtons = {}
		local files = FS.ListFiles()
		for i, path in ipairs(files) do
			local name = FS.DisplayName(path)
			local btn = mk("TextButton", {
				Name = "File_" .. i,
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundColor3 = s.theme.Button,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "  " .. name,
				Font = s.uiFont,
				TextSize = 12,
				TextColor3 = s.theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = i,
			}, s.fileList)
			mk("UICorner", { CornerRadius = UDim.new(0, 4) }, btn)
			btn.MouseEnter:Connect(function()
				tween(btn, TWEEN_FAST, { BackgroundTransparency = 0.15 })
			end)
			btn.MouseLeave:Connect(function()
				tween(btn, TWEEN_FAST, { BackgroundTransparency = 0.55 })
			end)
			btn.MouseButton1Click:Connect(function()
				openFile(path)
			end)
			fileButtons[#fileButtons + 1] = btn
		end
		if #files == 0 then
			local hint = mk("TextLabel", {
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				Text = "No files yet\nCtrl+S saves into Editor/",
				Font = s.uiFont,
				TextSize = 11,
				TextColor3 = s.theme.TextDim,
				TextWrapped = true,
				LayoutOrder = 9999,
			}, s.fileList)
			fileButtons[#fileButtons + 1] = hint
		end
	end
	s.refreshFileList = refreshFileList

	local function saveActive()
		local tab = s.activeTab
		if not tab then return end
		if tab.path then
			local okWrite, err = FS.Write(tab.path, tab.buffer:GetText())
			if okWrite then
				tab.modified = false
				FS.Delete(FS.BackupPath(tab.name))
				tab.backupPath = nil
				updateTabChrome()
				setStatus("Saved " .. tab.path)
			else
				setStatus("Save failed: " .. tostring(err), true)
				toastMsg("Save failed", true)
			end
			return
		end
		showInputDialog("Save as", "File name (e.g. script.lua)", tab.name or "untitled.lua", function(name)
			local path = FS.PathFor(name)
			local okWrite, err = FS.Write(path, tab.buffer:GetText())
			if okWrite then
				FS.Delete(FS.BackupPath(tab.name))
				tab.path = path
				tab.name = FS.DisplayName(path)
				tab.modified = false
				tab.backupPath = nil
				updateTabChrome()
				setStatus("Saved " .. path)
				refreshFileList()
			else
				toastMsg("Save failed: " .. tostring(err), true)
			end
		end)
	end
	s.saveActive = saveActive

	local function autosaveAll()
		local count = 0
		for _, tab in ipairs(s.tabs) do
			if tab.modified then
				local backup = tab.backupPath or FS.BackupPath(tab.name or "untitled")
				local text = tab.buffer:GetText()
				if FS.Write(backup, text) then
					count = count + 1
					tab.backupPath = backup
				end
			end
		end
		if count > 0 then
			s.autosaveTotal = (s.autosaveTotal or 0) + count
			setStatus(string.format("Autosaved %d tab%s", count, count == 1 and "" or "s"))
		end
		return count
	end
	s.autosaveAll = autosaveAll

	local function restoreBackups()
		if not FS.CanUse() then return 0 end
		local restored = 0
		for _, backupPath in ipairs(FS.ListBackups()) do
			local name = backupPath:match("%.backup_([^/\\]+)$")
			if name then
				local data = FS.Read(backupPath)
				if data then
					local tab = newTabData()
					tab.name = name
					local candidate = FS.Folder .. "/" .. name
					if FS.IsFile(candidate) then
						tab.path = candidate
					end
					tab.backupPath = backupPath
					tab.buffer:SetText(data)
					tab.tokenizer:InvalidateAll()
					tab.modified = true
					rebuildVisualMap(tab)
					finalizeNewTab(tab)
					restored = restored + 1
				end
			end
		end
		return restored
	end

	-- sidebar collapse / expand -----------------------------------------------
	local function setSidebarCollapsed(collapsed, animate)
		s.sidebarCollapsed = collapsed
		local sbW = collapsed and 0 or 178
		if animate then
			tween(s.sidebar, TWEEN_MED, { Size = UDim2.new(0, math.max(sbW, 1), 1, 0) })
			tween(s.editorArea, TWEEN_MED, { Position = UDim2.fromOffset(sbW, 0), Size = UDim2.new(1, -sbW, 1, 0) })
			task.delay(0.3, function()
				layout()
			end)
		else
			layout()
		end
		s.sidebarExpandBtn.Visible = collapsed
		s.sidebar.ClipsDescendants = true
	end

	s.sideCollapseBtn.MouseButton1Click:Connect(function()
		setSidebarCollapsed(true, true)
	end)
	s.sidebarExpandBtn.MouseButton1Click:Connect(function()
		setSidebarCollapsed(false, true)
	end)
	s.sideRefreshBtn.MouseButton1Click:Connect(function()
		refreshFileList()
		setStatus("File list refreshed")
	end)
	s.sideNewBtn.MouseButton1Click:Connect(function()
		s.newTab()
	end)
	s.newTabBtn.MouseButton1Click:Connect(function()
		s.newTab()
	end)

	-- minimize / close / theme -------------------------------------------------
	local function toggleMinimize()
		if s.minimized then
			s.minimized = false
			s.tabBar.Visible = true
			s.body.Visible = true
			s.statusBar.Visible = true
			window.Size = UDim2.fromOffset(s.winW, TITLE_H)
			tween(window, TWEEN_MED, { Size = UDim2.fromOffset(s.winW, s.winH) })
			s.shadow.Size = UDim2.fromOffset(s.winW + 26, s.winH + 26)
			s.shadow.Position = UDim2.fromOffset(window.Position.X.Offset - 13, window.Position.Y.Offset - 13)
			s.focused = true
			layout()
			s.renderDirty = true
		else
			s.minimized = true
			s.focused = false
			clearHeld()
			tween(window, TWEEN_MED, { Size = UDim2.fromOffset(s.winW, TITLE_H) })
			s.shadow.Size = UDim2.fromOffset(s.winW + 26, TITLE_H + 26)
			s.shadow.Position = UDim2.fromOffset(window.Position.X.Offset - 13, window.Position.Y.Offset - 13)
			task.delay(0.28, function()
				if s.minimized then
					s.tabBar.Visible = false
					s.body.Visible = false
					s.statusBar.Visible = false
				end
			end)
		end
	end
	s.toggleMinimize = toggleMinimize
	s.minBtn.MouseButton1Click:Connect(toggleMinimize)

	local function closeWindow()
		if s.closing then return end
		s.closing = true
		clearHeld()
		autosaveAll()
		local w, h = window.AbsoluteSize.X, window.AbsoluteSize.Y
		tween(window, TWEEN_MED, { Size = UDim2.fromOffset(math.max(w * 0.9, 220), math.max(h * 0.85, 40)) })
		tween(s.windowStroke, TWEEN_MED, { Transparency = 1 })
		tween(s.shadow, TWEEN_MED, { BackgroundTransparency = 1 })
		task.delay(0.3, function()
			s.maid:DoCleaning()
		end)
	end
	s.closeWindow = closeWindow
	s.closeBtn.MouseButton1Click:Connect(closeWindow)

	local function toggleTheme()
		local nextTheme = (s.themeName == "Dark") and "Light" or "Dark"
		applyThemeAll(nextTheme, true)
		-- slide the crescent cutout to indicate the new theme
		local targetX = (nextTheme == "Dark") and -3 or 3
		tween(s.themeCutout, TWEEN_MED, { Position = UDim2.new(0.5, targetX, 0.5, -2) })
		setStatus("Theme: " .. nextTheme)
	end
	s.toggleTheme = toggleTheme
	s.themeBtn.MouseButton1Click:Connect(toggleTheme)

	-- ------------------------------------------------------- render heartbeat
	s.maid:Give(RunService.Heartbeat:Connect(function(dt)
		if s.closing then return end
		local now = os.clock()
		-- caret blink
		if now - s.caretBlink > 0.52 then
			s.caretBlink = now
			s.caretVisible = not s.caretVisible
			s.renderDirty = true
		end
		updateKeyRepeat()
		-- debounced finder refresh (buffer changed while find panel open)
		local tab = s.activeTab
		if tab and tab.finderDirty then
			tab.finderDirty = false
			refreshFindMatches()
		end
		-- debounced minimap rebuild
		s.minimapClock = (s.minimapClock or 0) + dt
		if s.minimapDirty and s.minimapClock > 0.25 then
			s.minimapClock = 0
			rebuildMinimap()
		end
		-- autosave sweep every 25 seconds
		s.autosaveClock = s.autosaveClock + dt
		if s.autosaveClock >= 25 then
			s.autosaveClock = 0
			autosaveAll()
		end
		if s.renderDirty then
			s.renderDirty = false
			if s.activeTab and s.activeTab.scrollToCaret then
				ensureCaretVisible(s.activeTab)
			end
			renderAll()
			updateMinimapViewport()
		end
	end))

	-- ------------------------------------------------------------ windows icon
	-- seed the initial document(s)
	FS.EnsureFolder()
	applyThemeAll("Dark", false)
	layout()

	local restored = 0
	local okRestore, restoreErr = pcall(function()
		restored = restoreBackups()
	end)
	if not okRestore then
		warn("MiniIDE: backup restore failed:", restoreErr)
	end

	if #s.tabs == 0 then
		local tab = newTab("welcome.lua")
		tab.buffer:SetText(WELCOME_TEXT)
		tab.tokenizer:InvalidateAll()
		rebuildVisualMap(tab)
	end

	refreshFileList()
	updateTabChrome()
	s.minimapDirty = true

	-- open animation: rise + fade
	window.Position = UDim2.fromOffset(window.Position.X.Offset, window.Position.Y.Offset + 26)
	s.shadow.BackgroundTransparency = 1
	s.windowStroke.Transparency = 1
	local riseTo = window.Position.Y.Offset - 26
	tween(window, TWEEN_MED, { Position = UDim2.fromOffset(window.Position.X.Offset, riseTo) })
	tween(s.shadow, TWEEN_MED, { BackgroundTransparency = 0.55 })
	tween(s.windowStroke, TWEEN_MED, { Transparency = 0.35 })

	if restored > 0 then
		toastMsg(string.format("Restored %d autosaved tab%s", restored, restored == 1 and "" or "s"))
	else
		toastMsg("Luau Mini IDE ready — click the editor and start typing")
	end

	renderAll()

	return s
end

-- ============================================================================
-- 13. Welcome document (plain text; never executed by the editor itself)
-- ============================================================================
WELCOME_TEXT = [=[
-- ============================================================
--  Luau Mini IDE — welcome.lua  (unsaved; press Ctrl+S)
-- ============================================================
-- A full editor lives inside your game now. The buffer, the
-- tabs, the minimap, the folds — all of it is plain Instances.
--
--  Ctrl+S  save        Ctrl+F  find        Ctrl+H  replace all
--  Ctrl+Z  undo        Ctrl+Y  redo        Ctrl+A  select all
--  Ctrl+N  new tab     Ctrl+W  close tab   Ctrl+L  select line
--  Ctrl+Space  autocomplete        Tab / Shift+Tab  indent
--  Double-click selects a word, triple-click selects the line.
--  Brackets and quotes auto-close; matching brackets highlight.
--
--  Click the ▾ arrows in the gutter to fold blocks.

local function sum(first, last)
	local total = 0
	for i = first, last do
		total = total + i
	end
	return total
end

local result = sum(1, 100)
print("sum of 1..100 is", result)

local function foldMe()
	if result > 0 then
		for i = 1, 3 do
			print("nested block", i)
		end
	end
end

foldMe()

local greeting = [[
long strings work too,
even across lines — with escapes \" like this
]]
print(greeting)
]=]

-- ============================================================================
-- 14. Headless test hook — when __MINIIDE_TEST_EXPORT is set in the global
--     environment, pure modules are returned and no Roblox code runs.
-- ============================================================================
if rawget(_G, "__MINIIDE_TEST_EXPORT") then
	return {
		Util = Util,
		UTF8 = UTF8,
		Maid = Maid,
		TextBuffer = TextBuffer,
		UndoStack = UndoStack,
		Tokenizer = Tokenizer,
		Finder = Finder,
		computeFolds = computeFolds,
		getKeymap = getKeymap,
	}
end

-- ============================================================================
-- 15. Bootstrap — shared guard cleans up a previous instance; everything runs
--     under xpcall so a failure reports instead of crashing the client.
-- ============================================================================
local function reportFatal(err)
	warn("[MiniIDE] " .. tostring(err))
	pcall(function()
		if typeof(rconsoleprint) == "function" then
			rconsoleprint("[MiniIDE] " .. tostring(err) .. "\n")
		end
	end)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Mini IDE",
			Text = "Failed to start — see the developer console",
			Duration = 6,
		})
	end)
end

do
	local envTable = nil
	pcall(function()
		envTable = (typeof(getgenv) == "function") and getgenv() or nil
	end)
	envTable = envTable or _G

	-- shared guard: re-executing the script destroys the old instance first
	local previous = rawget(envTable, "__LuauMiniIDE")
	if type(previous) == "table" and type(previous.Cleanup) == "function" then
		pcall(previous.Cleanup)
	end
	envTable.__LuauMiniIDE = nil

	local ok, err = xpcall(function()
		local ide = BuildIDE()
		envTable.__LuauMiniIDE = {
			Session = ide, -- exposed for diagnostics; Cleanup() is the public entry point
			Cleanup = function()
				if ide.closing then
					return
				end
				ide.closing = true
				pcall(ide.autosaveAll) -- never lose unsaved work
				pcall(function()
					ide.maid:DoCleaning() -- destroys the ScreenGui + connections
				end)
			end,
		}
	end, function(e)
		return tostring(e) .. "\n" .. debug.traceback("", 2)
	end)

	if not ok then
		reportFatal(err)
	else
		print("[MiniIDE] loaded. Re-executing the script replaces this instance.")
	end
end
