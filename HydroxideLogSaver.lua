-- Hydroxide Log Saver (Patched Edition): run instead of Hydroxide's normal loader.
-- Use only in experiences you own or are authorized to inspect.

-- Configuration.
local OWNER = "Upbolt"
local BRANCH = "revision"
local OUTPUT_FOLDER = "HydroxideLogs"
local ENABLE_ALL_REMOTE_TYPES = true
local ENABLE_INCOMING_EVENTS = true
-- This optional hook changes the InvokeServer call stack; enable only after testing.
local ENABLE_INVOKE_RESPONSE_HOOK = false
local ENABLE_UNRELIABLE_NAMECALL_HOOK = true
local ENABLE_UNRELIABLE_METHOD_HOOK = true
-- Skip calls originating from executor threads (prevents self-capture / BindableEvent noise).
local IGNORE_EXECUTOR_CALLS = true
-- Apply runtime bugfixes to Hydroxide modules & UI (buffer support, scanner fixes, Remote:Unblock, etc.).
local PATCH_HYDROXIDE_BUGS = true
local MAX_TABLES_PER_RECORD = 1000
local MAX_ENTRIES_PER_RECORD = 12000
local MAX_BUFFER_BYTES = 65536
local MAX_BUFFER_PREVIEW_BYTES = 24
local MAX_INSPECT_FUNCTIONS = 200
local MAX_INSPECT_DEPTH = 3

-- Services.
local httpService = game:GetService("HttpService")
local environment = getgenv()

assert(type(request) == "function", "HydroxideLogSaver requires request")
assert(type(writefile) == "function" and type(appendfile) == "function", "HydroxideLogSaver requires writefile and appendfile")
assert(type(makefolder) == "function" and type(isfolder) == "function", "HydroxideLogSaver requires makefolder and isfolder")

if environment.HydroxideLogSaver then
	pcall(environment.HydroxideLogSaver.stop)
end

-- Fetch dependencies using the executor's request function.
local function fetchSource(url)
	local response = request({ Url = url, Method = "GET" })
	assert(response and response.Success and type(response.Body) == "string", "HTTP request failed: " .. url)
	return response.Body
end

local function executeSource(source, name)
	local chunk, errorMessage = loadstring(source, name)
	assert(chunk, errorMessage)
	return chunk()
end

local function webImport(path)
	local url = ("https://raw.githubusercontent.com/%s/Hydroxide/%s/%s.lua"):format(OWNER, BRANCH, path)
	return executeSource(fetchSource(url), path .. ".lua")
end

-- Data2Code improves the readable representation of Roblox values.
local serializer
local serializerOk, serializerResult = pcall(function()
	local url = "https://raw.githubusercontent.com/Awakenchan/GcViewerV3/aed7373a85aef765e1a255dce1de6c0b0d40860f/Utility/Data2Code.luau"
	return executeSource(fetchSource(url), "Data2Code.lua")
end)
if serializerOk and type(serializerResult) == "table" and type(serializerResult.Convert) == "function" then
	serializer = serializerResult
else
	warn("[HydroxideLogSaver] Data2Code unavailable; non-table values will use best-effort descriptions.")
end

-- Initialise Hydroxide before attaching the saver and loading the UI.
webImport("init")
local hydroxide = assert(environment.oh, "Hydroxide init did not expose oh")
local importModule = assert(environment.import, "Hydroxide init did not expose import")

-- Hydroxide's older aliases do not include modern UNC/sUNC names.
if not environment.isXClosure and type(isexecutorclosure) == "function" then
	environment.isXClosure = isexecutorclosure
end
if type(getthreadidentity) == "function" and type(setthreadidentity) == "function" then
	environment.getContext = environment.getContext or getthreadidentity
	environment.setContext = environment.setContext or setthreadidentity
end
local checkCallerFn = environment.checkCaller or checkcaller

if not isfolder(OUTPUT_FOLDER) then
	makefolder(OUTPUT_FOLDER)
end
local sessionId = httpService:GenerateGUID(false)
local filePath = OUTPUT_FOLDER .. "/" .. tostring(game.PlaceId) .. "_" .. sessionId .. ".jsonl"
writefile(filePath, "")

local Saver = {
	path = filePath,
	active = true,
	sequence = 0,
	failures = 0,
	truncated = 0,
	serializerAvailable = serializer ~= nil,
	savedByKind = {},
	patchStatus = { executorFilter = "not_installed" },
}
environment.HydroxideLogSaver = Saver

-- JSON strings can contain arbitrary bytes in Luau, so encode non-ASCII bytes as hex.
local function encodeString(value)
	if not value:find("[^\032-\126\n\r\t]") then
		return { kind = "string", encoding = "text", value = value }
	end
	return {
		kind = "string",
		encoding = "hex",
		value = (value:gsub(".", function(character)
			return string.format("%02x", string.byte(character))
		end))
	}
end

local function safeText(value)
	local ok, result = pcall(tostring, value)
	return ok and result or "<tostring failed>"
end

local function readBufferBytes(value, maxBytes)
	if type(buffer) ~= "table" then
		return nil, nil, "buffer library unavailable"
	end
	local okLen, length = pcall(buffer.len, value)
	if not okLen or type(length) ~= "number" then
		return nil, nil, safeText(length)
	end
	local readCount = (maxBytes and maxBytes > 0 and length > maxBytes) and maxBytes or length
	local truncated = readCount < length
	if type(buffer.tostring) == "function" then
		local okRaw, raw = pcall(buffer.tostring, value)
		if okRaw and type(raw) == "string" then
			local slice = truncated and raw:sub(1, readCount) or raw
			local hex = slice:gsub(".", function(character)
				return string.format("%02x", string.byte(character))
			end)
			return length, { encoding = "hex", value = hex, truncated = truncated }, nil
		end
	end
	if type(buffer.readu8) == "function" then
		local chunks = table.create(readCount)
		local okRead, readErr = pcall(function()
			for offset = 0, readCount - 1 do
				chunks[offset + 1] = string.format("%02x", buffer.readu8(value, offset))
			end
		end)
		if okRead then
			return length, { encoding = "hex", value = table.concat(chunks), truncated = truncated }, nil
		end
		return length, nil, safeText(readErr)
	end
	return length, nil, "buffer.tostring and buffer.readu8 unavailable"
end

local function formatBufferPreview(value)
	local length, bytesInfo = readBufferBytes(value, MAX_BUFFER_PREVIEW_BYTES)
	if not length then
		return safeText(value)
	end
	if bytesInfo and bytesInfo.value then
		local spaced = bytesInfo.value:gsub("..", "%0 "):gsub("%s+$", "")
		local suffix = bytesInfo.truncated and " ..." or ""
		return ("<buffer %dB: %s%s>"):format(length, spaced, suffix)
	end
	return ("<buffer %dB>"):format(length)
end

-- Runtime patches for bugs in Upbolt/Hydroxide (branch: revision).
local function patchHydroxideCore()
	if not PATCH_HYDROXIDE_BUGS then return end

	-- 1. Fix missing "buffer" entries in oh.Constants (prevents RemoteSpy/Scanner UI crashes).
	if hydroxide.Constants then
		if hydroxide.Constants.Types and not hydroxide.Constants.Types["buffer"] then
			hydroxide.Constants.Types["buffer"] = hydroxide.Constants.Types["userdata"]
		end
		if hydroxide.Constants.Syntax and not hydroxide.Constants.Syntax["buffer"] then
			hydroxide.Constants.Syntax["buffer"] = Color3.fromRGB(225, 195, 120)
		end
	end

	-- 2. Teach toString/dataToString about Luau buffers.
	local origToString = environment.toString
	if type(origToString) == "function" then
		local patchedToString = function(value)
			if typeof(value) == "buffer" then
				return formatBufferPreview(value)
			end
			return origToString(value)
		end
		environment.toString = patchedToString
		if type(hydroxide.Cache["methods/string"]) == "table" and hydroxide.Cache["methods/string"][1] then
			hydroxide.Cache["methods/string"][1].toString = patchedToString
		end
	end

	local origDataToString = environment.dataToString
	if type(origDataToString) == "function" then
		local patchedDataToString = function(value)
			if typeof(value) == "buffer" then
				return formatBufferPreview(value)
			end
			return origDataToString(value)
		end
		environment.dataToString = patchedDataToString
		if type(hydroxide.Cache["methods/string"]) == "table" and hydroxide.Cache["methods/string"][1] then
			hydroxide.Cache["methods/string"][1].dataToString = patchedDataToString
		end
	end

	-- 3. Fix tableToString nested cycle overflow (A -> B -> A) and quote escaping order.
	local function safeTableToString(data, visited, indents)
		local dataType = type(data)
		if dataType == "userdata" then
			return (typeof(data) == "Instance" and environment.getInstancePath(data)) or environment.userdataValue(data)
		elseif dataType == "buffer" then
			return formatBufferPreview(data)
		elseif dataType == "string" then
			if #(data:gsub("%w", ""):gsub("%s", ""):gsub("%p", "")) > 0 then
				local success, result = pcall(environment.toUnicode, data)
				return (success and result) or environment.toString(data)
			end
			return ('"%s"'):format(data:gsub("\\", "\\\\"):gsub('"', '\\"'))
		elseif dataType == "table" then
			indents = indents or 1
			visited = visited or {}
			if visited[data] then
				return "OH_CYCLIC_PROTECTION"
			end
			visited[data] = true
			local parts = {}
			local indent = ("\t"):rep(indents)
			for k, v in pairs(data) do
				local ks = visited[k] and "OH_CYCLIC_PROTECTION" or safeTableToString(k, visited, indents + 1)
				local vs = visited[v] and "OH_CYCLIC_PROTECTION" or safeTableToString(v, visited, indents + 1)
				parts[#parts + 1] = ("%s[%s] = %s"):format(indent, ks, vs)
			end
			visited[data] = nil
			if #parts > 0 then
				return "{\n" .. table.concat(parts, ",\n") .. "\n" .. ("\t"):rep(indents - 1) .. "}"
			end
			return "{}"
		end
		return tostring(data)
	end
	environment.tableToString = safeTableToString
	if type(hydroxide.Cache["methods/table"]) == "table" and hydroxide.Cache["methods/table"][1] then
		hydroxide.Cache["methods/table"][1].tableToString = safeTableToString
	end

	-- 4. Add missing Remote.unblock (fixes multi-select Unblock Calls crash in UI).
	local okRemote, remoteObj = pcall(importModule, "objects/Remote")
	if okRemote and type(remoteObj) == "table" then
		remoteObj.unblock = function(remote)
			remote.Blocked = false
		end
		local origRemoteNew = remoteObj.new
		if type(origRemoteNew) == "function" then
			remoteObj.new = function(instance)
				local remote = origRemoteNew(instance)
				remote.Unblock = remoteObj.unblock
				return remote
			end
		end
	end
end

local function patchHydroxideScanners()
	if not PATCH_HYDROXIDE_BUGS then return end

	local function escapeLuaPattern(text)
		return (text:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))
	end

	-- Fix case-sensitivity & Lua pattern bugs in ScriptScanner and ModuleScanner.
	for _, name in ipairs({ "ScriptScanner", "ModuleScanner" }) do
		local ok, mod = pcall(importModule, "modules/" .. name)
		if ok and type(mod) == "table" and type(mod.Scan) == "function" then
			local origScan = mod.Scan
			mod.Scan = function(query)
				local normalized = escapeLuaPattern((query or ""):lower())
				return origScan(normalized)
			end
		end
	end

	-- Fix UpvalueScanner bugs (typeof(upvalueType)=="Instance", missing userDataCheck, pattern matching).
	local okUpv, upvMod = pcall(importModule, "modules/UpvalueScanner")
	local okCls, Closure = pcall(importModule, "objects/Closure")
	local okUObj, Upvalue = pcall(importModule, "objects/Upvalue")
	if okUpv and okCls and okUObj and type(upvMod) == "table" then
		local function compareUpvalueFixed(query, upvalue, ignore)
			local upvalueType = type(upvalue)
			local queryLower = query:lower()

			if upvalueType == "string" then
				return query == upvalue or upvalue:lower():find(queryLower, 1, true) ~= nil
			elseif not ignore and upvalueType == "number" then
				return tonumber(query) == upvalue or ("%.2f"):format(upvalue) == query
			elseif upvalueType == "userdata" then
				if typeof(upvalue) == "Instance" then
					local instanceName = upvalue.Name
					return instanceName == query or instanceName:lower():find(queryLower, 1, true) ~= nil
				end
				return environment.toString(upvalue) == query
			elseif upvalueType == "buffer" then
				local preview = formatBufferPreview(upvalue):lower()
				return preview:find(queryLower, 1, true) ~= nil
			elseif upvalueType == "function" then
				local closureName = environment.getInfo(upvalue).name or ""
				return query == closureName or closureName:lower():find(queryLower, 1, true) ~= nil
			end
			return false
		end

		upvMod.Scan = function(query, deepSearch)
			query = query or ""
			local upvalues = {}
			for _i, closure in pairs(environment.getGc()) do
				if type(closure) == "function" and not environment.isXClosure(closure) and not upvalues[closure] then
					for index, value in pairs(environment.getUpvalues(closure)) do
						local valueType = type(value)
						if valueType ~= "table" and compareUpvalueFixed(query, value) then
							local storage = upvalues[closure]
							if not storage then
								local newClosure = Closure.new(closure)
								newClosure.Upvalues[index] = Upvalue.new(newClosure, index, value)
								upvalues[closure] = newClosure
							else
								storage.Upvalues[index] = Upvalue.new(storage, index, value)
							end
						elseif deepSearch and valueType == "table" then
							local storage = upvalues[closure]
							local tbl
							for i, v in pairs(value) do
								if (i ~= value and v ~= value) and (compareUpvalueFixed(query, i, true) or compareUpvalueFixed(query, v)) then
									if not storage then
										local newClosure = Closure.new(closure)
										storage = newClosure
										upvalues[closure] = newClosure
									end
									if not tbl then
										tbl = Upvalue.new(storage, index, value)
										tbl.Scanned = {}
										storage.Upvalues[index] = tbl
									end
									tbl.Scanned[i] = v
								end
							end
						end
					end
				end
			end
			return upvalues
		end
	end

	-- Fix ConstantScanner literal matching (avoid Lua pattern surprises on ".", "-", "(" etc.).
	local okConst, constMod = pcall(importModule, "modules/ConstantScanner")
	local okCObj, Constant = pcall(importModule, "objects/Constant")
	if okConst and okCls and okCObj and type(constMod) == "table" then
		local function compareConstantFixed(query, constant)
			local constantType = type(constant)
			local queryLower = query:lower()

			if constantType == "string" then
				return query == constant or constant:lower():find(queryLower, 1, true) ~= nil
			elseif constantType == "number" then
				return tonumber(query) == constant or ("%.2f"):format(constant) == query
			elseif constantType == "userdata" then
				if typeof(constant) == "Instance" then
					local instanceName = constant.Name
					return instanceName == query or instanceName:lower():find(queryLower, 1, true) ~= nil
				end
				return environment.toString(constant) == query
			elseif constantType == "buffer" then
				return formatBufferPreview(constant):lower():find(queryLower, 1, true) ~= nil
			elseif constantType == "function" then
				local closureName = environment.getInfo(constant).name or ""
				return query == closureName or closureName:lower():find(queryLower, 1, true) ~= nil
			end
			return false
		end

		constMod.Scan = function(query)
			query = query or ""
			local constants = {}
			for _i, closure in pairs(environment.getGc()) do
				if type(closure) == "function" and not environment.isXClosure(closure) and environment.isLClosure(closure) and not constants[closure] then
					for index, constant in pairs(environment.getConstants(closure)) do
						if compareConstantFixed(query, constant) then
							local storage = constants[closure]
							if not storage then
								local newClosure = Closure.new(closure)
								newClosure.Constants[index] = Constant.new(newClosure, index, constant)
								constants[closure] = newClosure
							else
								storage.Constants[index] = Constant.new(storage, index, constant)
							end
						end
					end
				end
			end
			return constants
		end
	end
end

patchHydroxideCore()
patchHydroxideScanners()

local function describeValue(value)
	local kind = typeof(value)
	local luaType = type(value)
	if luaType == "string" then
		return encodeString(value)
	elseif luaType == "number" then
		if value ~= value then return { kind = "number", special = "nan" } end
		if value == math.huge then return { kind = "number", special = "inf" } end
		if value == -math.huge then return { kind = "number", special = "-inf" } end
		return { kind = "number", value = value }
	elseif luaType == "boolean" then
		return { kind = "boolean", value = value }
	elseif luaType == "nil" then
		return { kind = "nil" }
	end

	local result = { kind = kind, description = encodeString(safeText(value)) }
	if kind == "buffer" then
		local length, bytesInfo, bytesErr = readBufferBytes(value, MAX_BUFFER_BYTES)
		if length ~= nil then result.length = length end
		if bytesInfo then result.bytes = bytesInfo end
		if bytesErr then result.bytesError = bytesErr end
	elseif kind == "Instance" then
		local ok, path = pcall(function() return value:GetFullName() end)
		if ok then result.path = encodeString(path) end
		local classOk, className = pcall(function() return value.ClassName end)
		if classOk then result.class = encodeString(className) end
	elseif luaType == "function" then
		local getInfo = (debug and debug.getinfo) or getinfo
		if type(getInfo) == "function" then
			local ok, info = pcall(getInfo, value)
			if ok and type(info) == "table" then
				if type(info.name) == "string" then result.name = encodeString(info.name) end
				if type(info.source) == "string" then result.source = encodeString(info.source) end
				if type(info.linedefined) == "number" then result.line = info.linedefined end
			end
		end
	elseif kind == "ProtoProxy" then
		result.representation = "opaque prototype reference; not recovered source"
	elseif serializer then
		local ok, converted = pcall(serializer.Convert, value, true)
		if ok and type(converted) == "string" then
			if converted:find("Data2Code.Convert error:", 1, true) then
				result.conversionError = encodeString(converted)
			else
				result.luau = encodeString(converted)
			end
		end
	end
	return result
end

-- Represent tables as a graph so nested tables, non-string keys and cycles survive.
local function encodeGraph(root)
	local ids, pending, nodes = {}, {}, {}
	local entryCount, truncated = 0, false
	local function encodeValue(value)
		if type(value) ~= "table" then
			local encoded = describeValue(value)
			if encoded.kind == "buffer" and (encoded.bytesError or not encoded.bytes or encoded.bytes.truncated) then
				truncated = true
			end
			return encoded
		end
		if ids[value] then return { kind = "table_ref", id = ids[value] } end
		if #pending >= MAX_TABLES_PER_RECORD then
			truncated = true
			return { kind = "truncated", reason = "table_limit" }
		end
		local id = #pending + 1
		ids[value] = id
		pending[id] = value
		return { kind = "table_ref", id = id }
	end

	local encodedRoot = encodeValue(root)
	local index = 1
	while index <= #pending do
		local entries = {}
		local node = { id = index, entries = entries }
		nodes[index] = node
		local ok, errorMessage = pcall(function()
			for key, value in next, pending[index] do
				if entryCount >= MAX_ENTRIES_PER_RECORD then
					truncated = true
					node.truncated = "entry_limit"
					break
				end
				entryCount += 1
				entries[#entries + 1] = { key = encodeValue(key), value = encodeValue(value) }
			end
		end)
		if not ok then
			truncated = true
			node.error = encodeString(safeText(errorMessage))
		end
		index += 1
	end
	return { root = encodedRoot, tables = nodes, truncated = truncated, entryCount = entryCount }
end

-- Snapshot at capture time, then append one independent JSON line.
local function record(kind, payload)
	if not Saver.active then return false, false end
	Saver.sequence += 1
	local sequence = Saver.sequence
	local graph
	local ok, errorMessage = pcall(function()
		graph = encodeGraph(payload)
		local line = httpService:JSONEncode({
			version = 1,
			sequence = sequence,
			time = os.time(),
			monotonicTime = os.clock(),
			kind = kind,
			data = graph
		})
		appendfile(filePath, line .. "\n")
	end)
	if not ok then
		Saver.failures += 1
		warn("[HydroxideLogSaver] Could not save record " .. sequence .. ": " .. safeText(errorMessage))
		return false, false
	end
	Saver.savedByKind[kind] = (Saver.savedByKind[kind] or 0) + 1
	if graph.truncated then
		Saver.truncated += 1
	end
	return true, graph.truncated
end

record("session_start", {
	placeId = game.PlaceId,
	jobId = game.JobId,
	sessionId = sessionId,
	serializerAvailable = Saver.serializerAvailable,
	ignoreExecutorCalls = IGNORE_EXECUTOR_CALLS,
	patchedHydroxide = PATCH_HYDROXIDE_BUGS,
})

-- Patch modules/RemoteSpy source before caching so checkCaller() runs with zero extra stack frames.
local remoteSpy
do
	local patchedRemoteSpy
	if IGNORE_EXECUTOR_CALLS and type(checkCallerFn) == "function" then
		local okFetch, source = pcall(fetchSource, ("https://raw.githubusercontent.com/%s/Hydroxide/%s/modules/RemoteSpy.lua"):format(OWNER, BRANCH))
		if okFetch and type(source) == "string" then
			local updated, nmcMatches = source:gsub(
				'if typeof%(instance%) ~= "Instance" then(%s+)return nmcTrampoline%(%.%.%.%)',
				'if (checkCaller and checkCaller()) or typeof(instance) ~= "Instance" then%1return nmcTrampoline(...)'
			)
			local methodMatches = 0
			if nmcMatches == 1 then
				updated, methodMatches = updated:gsub(
					'if typeof%(instance%) ~= "Instance" then(%s+)return originalMethod%(%.%.%.%)',
					'if (checkCaller and checkCaller()) or typeof(instance) ~= "Instance" then%1return originalMethod(...)'
				)
			end
			if nmcMatches == 1 and methodMatches == 1 then
				local okExec, result = pcall(executeSource, updated, "modules/RemoteSpy.lua")
				if okExec and type(result) == "table" then
					hydroxide.Cache["modules/RemoteSpy"] = { result }
					patchedRemoteSpy = result
					Saver.patchStatus.executorFilter = "installed"
				end
			end
		end
	end
	if IGNORE_EXECUTOR_CALLS and not patchedRemoteSpy then
		Saver.patchStatus.executorFilter = "failed"
		warn("[HydroxideLogSaver] Executor filter NOT installed; do not assume self-capture is filtered")
	end
	remoteSpy = patchedRemoteSpy or importModule("modules/RemoteSpy")
end

if ENABLE_ALL_REMOTE_TYPES then
	for className in pairs(remoteSpy.RemotesViewing) do
		remoteSpy.RemotesViewing[className] = true
	end
end
local remoteMethods = { RemoteEvent = "FireServer", RemoteFunction = "InvokeServer", BindableEvent = "Fire", BindableFunction = "Invoke" }
remoteSpy.ConnectEvent(function(instance, call)
	local ok, className = pcall(function() return instance.ClassName end)
	record("remote_call", {
		remote = instance,
		inferredMethod = ok and remoteMethods[className] or nil,
		callingScript = call.script,
		callingFunction = call.func,
		arguments = call.args,
	})
end)

-- Observe delivered client events without replacing the game's existing listeners.
local incomingConnections, incomingSeen = {}, setmetatable({}, { __mode = "k" })
local incomingStats = { connected = 0, errors = 0 }
Saver.capabilities = {
	incomingEvents = false,
	namecallHook = false,
	invokeResponses = false,
	unreliableNamecalls = false,
	unreliableDotCalls = false,
}
local function watchIncoming(instance)
	if not Saver.active or incomingSeen[instance] then return end
	local okClass, className = pcall(function() return instance.ClassName end)
	if not okClass or (className ~= "RemoteEvent" and className ~= "UnreliableRemoteEvent") then return end
	local ok, connection = pcall(function()
		return instance.OnClientEvent:Connect(function(...)
			record("incoming_event", { remote = instance, className = className, arguments = table.pack(...) })
		end)
	end)
	if ok then
		incomingSeen[instance] = true
		incomingStats.connected += 1
		incomingConnections[#incomingConnections + 1] = connection
	else
		incomingStats.errors += 1
		warn("[HydroxideLogSaver] Could not observe an incoming event: " .. safeText(connection))
	end
end

if ENABLE_INCOMING_EVENTS then
	local ok, connection = pcall(function() return game.DescendantAdded:Connect(watchIncoming) end)
	if ok then
		incomingConnections[#incomingConnections + 1] = connection
		Saver.capabilities.incomingEvents = true
		local listed, descendants = pcall(function() return game:GetDescendants() end)
		if listed then
			for _, instance in ipairs(descendants) do watchIncoming(instance) end
		else
			incomingStats.errors += 1
			warn("[HydroxideLogSaver] Could not enumerate existing remotes: " .. safeText(descendants))
		end
	else
		incomingStats.errors += 1
		warn("[HydroxideLogSaver] Incoming observer unavailable: " .. safeText(connection))
	end
end
Saver.incomingStats = incomingStats

-- Observe unreliable namecalls and, optionally, InvokeServer results.
if ENABLE_UNRELIABLE_NAMECALL_HOOK or ENABLE_INVOKE_RESPONSE_HOOK then
	local setNamecall = setnamecallmethod or set_namecall_method
	if type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" and type(setNamecall) == "function" then
		local originalNamecall
		local function onNamecall(instance, ...)
			if not Saver.active then return originalNamecall(instance, ...) end
			if IGNORE_EXECUTOR_CALLS and type(checkCallerFn) == "function" and checkCallerFn() then
				return originalNamecall(instance, ...)
			end
			if typeof(instance) ~= "Instance" then
				return originalNamecall(instance, ...)
			end
			local method = getnamecallmethod()
			local ok, className = pcall(function() return instance.ClassName end)
			if not ok then return originalNamecall(instance, ...) end
			if ENABLE_UNRELIABLE_NAMECALL_HOOK and className == "UnreliableRemoteEvent" and (method == "FireServer" or method == "fireServer") then
				record("unreliable_namecall", {
					remote = instance,
					method = method,
					callingScript = type(environment.getCallingScript) == "function" and environment.getCallingScript() or nil,
					arguments = table.pack(...),
				})
				setNamecall(method)
				return originalNamecall(instance, ...)
			end
			if ENABLE_INVOKE_RESPONSE_HOOK and className == "RemoteFunction" and (method == "InvokeServer" or method == "invokeServer") then
				local arguments = table.pack(...)
				local callingScript = type(environment.getCallingScript) == "function" and environment.getCallingScript() or nil
				setNamecall(method)
				local result = table.pack(pcall(originalNamecall, instance, ...))
				local values = { n = result.n - 1 }
				for index = 2, result.n do values[index - 1] = result[index] end
				record("invoke_result", {
					remote = instance,
					method = method,
					callingScript = callingScript,
					arguments = arguments,
					success = result[1],
					values = values,
				})
				if not result[1] then error(result[2], 0) end
				return table.unpack(result, 2, result.n)
			end
			return originalNamecall(instance, ...)
		end
		local wrapOk, hook = pcall(function()
			return type(newcclosure) == "function" and newcclosure(onNamecall) or onNamecall
		end)
		local ok, original = false, hook
		if wrapOk then ok, original = pcall(hookmetamethod, game, "__namecall", hook) end
		if ok and type(original) == "function" then
			originalNamecall = original
			Saver.capabilities.namecallHook = true
			Saver.capabilities.invokeResponses = ENABLE_INVOKE_RESPONSE_HOOK
			Saver.capabilities.unreliableNamecalls = ENABLE_UNRELIABLE_NAMECALL_HOOK
		else
			warn("[HydroxideLogSaver] Extra namecall observer unavailable: " .. safeText(original))
		end
	else
		warn("[HydroxideLogSaver] Extra namecall observer requires hookmetamethod, getnamecallmethod, and setnamecallmethod")
	end
end

-- Observe UnreliableRemoteEvent dot-calls (e.g. remote.FireServer(remote, ...)).
if ENABLE_UNRELIABLE_METHOD_HOOK and type(hookfunction) == "function" then
	local okCreate, tempUnreliable = pcall(Instance.new, "UnreliableRemoteEvent")
	if okCreate and tempUnreliable then
		local okMethod, fireServerMethod = pcall(function() return tempUnreliable.FireServer end)
		pcall(function() tempUnreliable:Destroy() end)
		if okMethod and type(fireServerMethod) == "function" then
			local originalFireServer
			local function onUnreliableFireServer(instance, ...)
				if not Saver.active then return originalFireServer(instance, ...) end
				if IGNORE_EXECUTOR_CALLS and type(checkCallerFn) == "function" and checkCallerFn() then
					return originalFireServer(instance, ...)
				end
				if typeof(instance) == "Instance" then
					local okClass, className = pcall(function() return instance.ClassName end)
					if okClass and className == "UnreliableRemoteEvent" then
						record("unreliable_dotcall", {
							remote = instance,
							method = "FireServer",
							callingScript = type(environment.getCallingScript) == "function" and environment.getCallingScript() or nil,
							arguments = table.pack(...),
						})
					end
				end
				return originalFireServer(instance, ...)
			end
			local wrapOk, wrapped = pcall(function()
				return type(newcclosure) == "function" and newcclosure(onUnreliableFireServer) or onUnreliableFireServer
			end)
			if wrapOk then
				local hookOk, original = pcall(hookfunction, fireServerMethod, wrapped)
				if hookOk and type(original) == "function" then
					originalFireServer = original
					Saver.capabilities.unreliableDotCalls = true
				else
					warn("[HydroxideLogSaver] UnreliableRemoteEvent dot-call hook failed: " .. safeText(original))
				end
			end
		end
	end
end

record("capabilities", { capabilities = Saver.capabilities, incomingStats = incomingStats, patchStatus = Saver.patchStatus })

-- ClosureSpy accepts one callback, so install a multiplexer before the UI loads.
local closureSpy = importModule("modules/ClosureSpy")
local originalSetEvent = closureSpy.SetEvent
local wrappedSetEvent = function(callback)
	return originalSetEvent(function(hook, call)
		record("closure_call", {
			closure = hook.Closure and hook.Closure.Data,
			name = hook.Closure and hook.Closure.Name,
			callingScript = call.script,
			arguments = call.args,
		})
		return callback(hook, call)
	end)
end
closureSpy.SetEvent = wrappedSetEvent

-- Scanner modules return snapshots rather than emitting log events.
local scannerNames = { "ScriptScanner", "ModuleScanner", "UpvalueScanner", "ConstantScanner" }
local scannerWrappers = {}
local scanCounter = 0
for _, name in ipairs(scannerNames) do
	local module = importModule("modules/" .. name)
	local originalScan = module.Scan
	if type(originalScan) == "function" then
		local wrappedScan = function(...)
			local arguments = table.pack(...)
			local result = originalScan(...)
			if not Saver.active then return result end

			-- Give each result its own graph budget instead of truncating the entire scan.
			scanCounter += 1
			local scanId = scanCounter
			local total, failed, truncated = 0, 0, 0
			record("scan_start", { scanId = scanId, scanner = name, arguments = arguments, resultType = type(result) })
			local ok, errorMessage = pcall(function()
				if type(result) ~= "table" then
					local saved, cut = record("scan_item", { scanId = scanId, index = 1, value = result })
					total = 1
					if not saved then failed += 1 end
					if cut then truncated += 1 end
					return
				end
				for key, value in next, result do
					total += 1
					local saved, cut = record("scan_item", { scanId = scanId, index = total, key = key, value = value })
					if not saved then failed += 1 end
					if cut then truncated += 1 end
				end
			end)
			record("scan_end", {
				scanId = scanId,
				itemCount = total,
				failedItems = failed,
				truncatedItems = truncated,
				traversalError = not ok and safeText(errorMessage) or nil,
			})
			if not ok or failed > 0 or truncated > 0 then
				warn(("[HydroxideLogSaver] %s scan %d: %d items, %d failed, %d truncated%s"):format(
					name, scanId, total, failed, truncated,
					not ok and ("; traversal error: " .. safeText(errorMessage)) or ""
				))
			end
			return result
		end
		module.Scan = wrappedScan
		scannerWrappers[#scannerWrappers + 1] = { module = module, original = originalScan, wrapper = wrappedScan }
	end
end

-- Inspect a closure without invoking it, requiring a ModuleScript, or changing upvalues.
function Saver.inspect(target, options)
	assert(Saver.active, "HydroxideLogSaver is stopped")
	options = options or {}
	local limit = math.clamp(math.floor(tonumber(options.maxFunctions) or MAX_INSPECT_FUNCTIONS), 1, 1000)
	local maxDepth = math.clamp(math.floor(tonumber(options.maxDepth) or MAX_INSPECT_DEPTH), 0, 10)
	local scriptInstance, rootClosure
	if type(target) == "function" then
		rootClosure = target
	elseif typeof(target) == "Instance" then
		scriptInstance = target
		local getter = getscriptclosure or get_script_function
		if type(getter) ~= "function" then return false, "getscriptclosure is unavailable" end
		local ok, result = pcall(getter, target)
		if not ok or type(result) ~= "function" then return false, "could not obtain a script closure: " .. safeText(result) end
		rootClosure = result
	else
		return false, "pass a function or a script Instance"
	end

	local inspectId = httpService:GenerateGUID(false)
	record("inspection_start", {
		inspectId = inspectId,
		target = target,
		maxFunctions = limit,
		maxDepth = maxDepth,
		decompileRequested = options.decompile == true,
	})
	if scriptInstance and options.decompile == true then
		if type(decompile) == "function" then
			local ok, result = pcall(decompile, scriptInstance)
			local success = ok and type(result) == "string"
			record("inspection_decompile", {
				inspectId = inspectId,
				script = scriptInstance,
				success = success,
				output = success and result or nil,
				error = not success and safeText(result) or nil,
			})
		else
			record("inspection_decompile", {
				inspectId = inspectId,
				script = scriptInstance,
				success = false,
				error = "decompile is unavailable",
			})
		end
	end

	local getConstants = (debug and debug.getconstants) or getconstants
	local getUpvalues = (debug and debug.getupvalues) or getupvalues
	local getProtos = (debug and debug.getprotos) or getprotos
	local getProto = (debug and debug.getproto) or getproto
	local getHash = type(getfunctionhash) == "function" and getfunctionhash or nil
	local seen = { [rootClosure] = true }
	local queue = { { closure = rootClosure, depth = 0, path = "root" } }
	local position, omitted, unresolved = 1, 0, 0
	local function enqueue(fn, depth, path)
		if type(fn) ~= "function" or seen[fn] then return end
		seen[fn] = true
		if depth > maxDepth or #queue >= limit then
			omitted += 1
			return
		end
		queue[#queue + 1] = { closure = fn, depth = depth, path = path }
	end
	local function readField(fn, api, name, errors)
		if type(api) ~= "function" then errors[name] = "unavailable"; return nil end
		local ok, value = pcall(api, fn)
		if not ok then errors[name] = safeText(value); return nil end
		return value
	end
	while position <= #queue and Saver.active do
		local entry = queue[position]
		local errors = {}
		local constants = readField(entry.closure, getConstants, "constants", errors)
		local upvalues = readField(entry.closure, getUpvalues, "upvalues", errors)
		local protos = readField(entry.closure, getProtos, "protos", errors)
		local hash = getHash and readField(entry.closure, getHash, "hash", errors) or nil
		local activeProtos = {}
		if type(protos) == "table" then
			for index, proto in next, protos do
				local path = entry.path .. ".proto[" .. safeText(index) .. "]"
				if type(proto) == "function" then
					enqueue(proto, entry.depth + 1, path)
				elseif type(index) == "number" and type(getProto) == "function" then
					local ok, active = pcall(getProto, entry.closure, index, true)
					if ok and type(active) == "table" then
						activeProtos[index] = active
						local found = false
						for activeIndex, fn in next, active do
							if type(fn) == "function" then
								found = true
								enqueue(fn, entry.depth + 1, path .. ".active[" .. safeText(activeIndex) .. "]")
							end
						end
						if not found then unresolved += 1 end
					elseif ok and type(active) == "function" then
						activeProtos[index] = { active }
						enqueue(active, entry.depth + 1, path .. ".active[1]")
					else
						unresolved += 1
					end
				else
					unresolved += 1
				end
			end
		end
		record("inspection_function", {
			inspectId = inspectId,
			path = entry.path,
			depth = entry.depth,
			closure = entry.closure,
			hash = hash,
			constants = constants,
			upvalues = upvalues,
			protos = protos,
			activeProtos = activeProtos,
			errors = errors,
		})
		position += 1
	end
	record("inspection_end", {
		inspectId = inspectId,
		functionsVisited = position - 1,
		functionsOmitted = omitted,
		unresolvedProtos = unresolved,
	})
	return true, inspectId
end

-- Installation is not proof of coverage: callers must validate with known traffic.
function Saver.health()
	local counts = {}
	for kind, count in pairs(Saver.savedByKind) do counts[kind] = count end
	local warnings = {}
	if (counts.remote_call or 0) == 0 then
		warnings[#warnings + 1] = "No standard outgoing calls observed; outgoing capture remains unverified"
	end
	if Saver.failures > 0 then warnings[#warnings + 1] = "Record writes or serialization failed" end
	if Saver.truncated > 0 then warnings[#warnings + 1] = "Some records contain incomplete data" end
	if Saver.patchStatus.executorFilter == "failed" then warnings[#warnings + 1] = "Executor filter unavailable" end
	return {
		active = Saver.active, savedByKind = counts, failures = Saver.failures,
		truncatedRecords = Saver.truncated, warnings = warnings,
		coverageVerified = false, -- only a controlled end-to-end fixture can establish this
	}
end

function Saver.checkpoint()
	local health = Saver.health()
	record("health", health)
	return health
end

function Saver.stop()
	if not Saver.active then return end
	record("session_stop", {
		health = Saver.health(),
		failures = Saver.failures,
		truncatedRecords = Saver.truncated,
		incomingStats = incomingStats,
	})
	Saver.active = false
	for _, connection in ipairs(incomingConnections) do
		pcall(function() connection:Disconnect() end)
	end
	if closureSpy.SetEvent == wrappedSetEvent then closureSpy.SetEvent = originalSetEvent end
	for _, item in ipairs(scannerWrappers) do
		if item.module.Scan == item.wrapper then item.module.Scan = item.original end
	end
	print("[HydroxideLogSaver] Stopped. Saved to " .. filePath)
end

print("[HydroxideLogSaver] Saving to " .. filePath)
local uiOk, uiError = pcall(webImport, "ui/main")
if not uiOk then
	record("ui_error", { message = safeText(uiError) })
	warn("[HydroxideLogSaver] Hydroxide UI failed: " .. safeText(uiError))
end
