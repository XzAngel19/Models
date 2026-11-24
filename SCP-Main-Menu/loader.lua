-- ZNTH Main Menu | Remote executor loader
-- Source branch: arena/cbc36148-models

local SOURCE_URL = "https://raw.githubusercontent.com/XzAngel19/Models/refs/heads/arena/cbc36148-models/SCP-Main-Menu/SCPMainMenu.lua"

local downloaded, sourceOrError = pcall(function()
	return game:HttpGet(SOURCE_URL, true)
end)

if not downloaded then
	error("[ZNTH Main Menu] No se pudo descargar el script: " .. tostring(sourceOrError), 0)
end

local compiled, compileError = loadstring(sourceOrError)
if not compiled then
	error("[ZNTH Main Menu] No se pudo compilar el script: " .. tostring(compileError), 0)
end

return compiled()
