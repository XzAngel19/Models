--[[
	Zenith · Loader
	Trae menu/ZenithMenu.lua desde GitHub y lo ejecuta.

	Uso (una línea, pegala en el executor):
		loadstring(game:HttpGet("https://raw.githubusercontent.com/XzAngel19/Models/arena/e960acb9-models/menu/ZenithLoader.lua"))()

	O pegá este archivo entero. Requiere executor con loadstring + HttpGet.
	Si tu executor no tiene loadstring / HttpGet, usá el método directo:
	pegá menu/ZenithMenu.lua completo.
]]

local SOURCES = {
	"https://raw.githubusercontent.com/XzAngel19/Models/arena/e960acb9-models/menu/ZenithMenu.lua",
	"https://raw.githubusercontent.com/XzAngel19/Models/main/menu/ZenithMenu.lua",
	"https://github.com/XzAngel19/Models/raw/refs/heads/arena/e960acb9-models/menu/ZenithMenu.lua",
}

local MIN_BYTES = 5000
local MARKER = "Zenith" -- tiene que aparecer en el script (evita quedarse con una página de error HTML)

---------------------------------------------------------------------------
-- Descarga
---------------------------------------------------------------------------
local function httpGet(url)
	local attempts = {
		function()
			return game:HttpGet(url, true)
		end,
		function()
			return game:HttpGet(url)
		end,
	}
	if type(request) == "function" then
		attempts[#attempts + 1] = function()
			local response = request({ Url = url, Method = "GET" })
			return response and response.Body
		end
	end
	if type(syn) == "table" and type(syn.request) == "function" then
		attempts[#attempts + 1] = function()
			local response = syn.request({ Url = url, Method = "GET" })
			return response and response.Body
		end
	end

	for _, attempt in ipairs(attempts) do
		local ok, body = pcall(attempt)
		if ok and type(body) == "string" then
			return body
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Validación + ejecución
---------------------------------------------------------------------------
local source, usedUrl = nil, nil
for _, url in ipairs(SOURCES) do
	local body = httpGet(url)
	if type(body) == "string" and #body >= MIN_BYTES and string.find(body, MARKER, 1, true) then
		source, usedUrl = body, url
		break
	end
	warn("[Zenith] no sirvió: " .. tostring(url))
end

if not source then
	error(
		"[Zenith] no se pudo descargar el menú.\n"
			.. "· Revisá que el executor tenga HttpGet habilitado.\n"
			.. "· Si la URL cambió, editá SOURCES.\n"
			.. "· Plan B: pegá menu/ZenithMenu.lua completo en el executor.",
		0
	)
end

local loader = loadstring or load
if type(loader) ~= "function" then
	error("[Zenith] este executor no tiene loadstring. Pegá menu/ZenithMenu.lua completo.", 0)
end

local chunk, compileError = loader(source, "=ZenithMenu")
if not chunk then
	error("[Zenith] error al compilar el menú: " .. tostring(compileError), 0)
end

local ok, runError = pcall(chunk)
if not ok then
	error("[Zenith] error al ejecutar el menú: " .. tostring(runError), 0)
end

print(string.format("[Zenith] menú cargado (%d bytes desde %s)", #source, tostring(usedUrl)))
