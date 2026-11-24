--[[
	Zenith · Home Menu
	Réplica del menú de referencia sobre un lienzo de diseño de 1224x780 px.
	Todo se escala con UIScale, así que se ve idéntico en 1080p, 1440p y móvil.

	Uso: ejecutar con el executor en cualquier juego, o pegar en un LocalScript.
	Sin dependencias externas (nada de loadstring ni HttpGet obligatorio).

	Para usar los PNG de menu/assets/: súbelos a Roblox y pega la id en CONFIG.ICONS.
	Si los dejas vacíos, el menú dibuja los glyphs en vectorial (siempre se ven).
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

---------------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------------
local CONFIG = {
	WIDTH = 1224,
	HEIGHT = 780,

	ACCENT = Color3.fromRGB(246, 165, 32),
	PANEL = Color3.fromRGB(7, 8, 11),
	PANEL_TRANSPARENCY = 0.10,
	BORDER = Color3.fromRGB(148, 151, 160),
	BORDER_TRANSPARENCY = 0.45,
	TEXT = Color3.fromRGB(240, 240, 244),
	DIM = Color3.fromRGB(152, 154, 164),

	CLEARANCE = "ZNTH",
	ACTIVE_USERS = 69,
	NEWS_DATE = "16/03/2019",
	NEWS_DESC = "Lorem ipsum dolor sit amet, consectetur elit, sed do eiusmod tempor incididunt ut labore magna aliqua.",
	STANDARD_SECONDS = 12 * 60 * 60,

	ICONS = {
		House = "",
		People = "",
		Paper = "",
		Division = "",
	},

	ALLOW_CLOSE = true,
}

local F_TITLE = Enum.Font.Oswald
local F_BODY = Enum.Font.SourceSans
local F_MONO = Enum.Font.RobotoMono

-- Paleta medida sobre el logo adjunto (menu/assets/division-logo.png).
local DIV_LIGHT = Color3.fromRGB(216, 193, 216)
local DIV_MID = Color3.fromRGB(182, 118, 182)
local DIV_DEEP = Color3.fromRGB(162, 75, 162)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function new(className, props, parent)
	local object = Instance.new(className)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			object[key] = value
		end
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function round(object, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 2) }, object)
end

local function stroke(object, transparency)
	return new("UIStroke", {
		Color = CONFIG.BORDER,
		Thickness = 1,
		Transparency = transparency or CONFIG.BORDER_TRANSPARENCY,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object)
end

local function text(parent, value, props)
	local base = {
		BackgroundTransparency = 1,
		Text = value,
		Font = F_TITLE,
		TextSize = 16,
		TextColor3 = CONFIG.TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}
	for key, item in pairs(props or {}) do
		base[key] = item
	end
	return new("TextLabel", base, parent)
end

local function panel(parent, x, y, w, h, transparency)
	local frame = new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = CONFIG.PANEL,
		BackgroundTransparency = CONFIG.PANEL_TRANSPARENCY,
		BorderSizePixel = 0,
	}, parent)
	stroke(frame, transparency)
	return frame
end

local function rule(parent, x, y, w, thickness, alpha)
	return new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, thickness or 1),
		BackgroundColor3 = CONFIG.BORDER,
		BackgroundTransparency = alpha or 0.35,
		BorderSizePixel = 0,
	}, parent)
end

local function verticalRule(parent, x, y, h, alpha)
	return new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(1, h),
		BackgroundColor3 = CONFIG.BORDER,
		BackgroundTransparency = alpha or 0.35,
		BorderSizePixel = 0,
	}, parent)
end

local function bar(parent, centerX, centerY, length, thickness, rotation, color)
	local piece = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(centerX, centerY),
		Size = UDim2.fromOffset(length, thickness),
		BackgroundColor3 = color or Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Rotation = rotation,
	}, parent)
	round(piece, 999)
	return piece
end

---------------------------------------------------------------------------
-- Glyphs vectoriales (o PNG si rellenas CONFIG.ICONS)
---------------------------------------------------------------------------
local function iconOverride(parent, key, x, y, size)
	local id = CONFIG.ICONS[key]
	if type(id) == "string" and id ~= "" then
		return new("ImageLabel", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Image = id,
		}, parent)
	end
	return nil
end

local function iconHouse(parent, x, y, size)
	local override = iconOverride(parent, "House", x, y, size)
	if override then
		return override
	end
	local box = new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = CONFIG.ACCENT,
		BorderSizePixel = 0,
	}, parent)
	round(box, 3)

	local inner = size * 0.62
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.76, 0),
		Size = UDim2.fromOffset(inner * 0.74, inner * 0.46),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, box)
	for _, sign in ipairs({ -1, 1 }) do
		bar(box, 0.5 + sign * 0.185, 0.42, inner * 0.62, math.max(2, size * 0.07), sign * 42, Color3.new(1, 1, 1))
	end
	return box
end

local function iconPeople(parent, x, y, size)
	local override = iconOverride(parent, "People", x, y, size)
	if override then
		return override
	end
	local holder = new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	}, parent)

	local function person(offsetX, scaleFactor, alpha)
		local head = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(offsetX, 0.34),
			Size = UDim2.fromOffset(size * 0.3 * scaleFactor, size * 0.3 * scaleFactor),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = alpha,
			BorderSizePixel = 0,
		}, holder)
		round(head, 999)
		local body = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(offsetX, 0.92),
			Size = UDim2.fromOffset(size * 0.44 * scaleFactor, size * 0.34 * scaleFactor),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = alpha,
			BorderSizePixel = 0,
		}, holder)
		round(body, 999)
	end

	person(0.76, 0.82, 0.35)
	person(0.42, 1, 0)
	return holder
end

local function iconPaper(parent, x, y, size)
	local override = iconOverride(parent, "Paper", x, y, size)
	if override then
		return override
	end
	local holder = new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	}, parent)
	local page = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.66, size * 0.84),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, holder)
	round(page, 1)
	new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(size * 0.26, size * 0.26),
		BackgroundColor3 = CONFIG.PANEL,
		BackgroundTransparency = CONFIG.PANEL_TRANSPARENCY,
		BorderSizePixel = 0,
		Rotation = 45,
	}, page)
	for index = 1, 3 do
		new("Frame", {
			Position = UDim2.new(0, size * 0.1, 0, size * (0.3 + index * 0.14)),
			Size = UDim2.fromOffset(size * 0.36, math.max(1, size * 0.05)),
			BackgroundColor3 = CONFIG.PANEL,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
		}, page)
	end
	return holder
end

--- Logo de división en vectorial: anillo + punto + tres chevrons.
--- Cada chevron son dos barras a ±45° cuyo extremo interior se junta en el ápice.
local function divisionLogo(parent, x, y, size)
	local override = iconOverride(parent, "Division", x, y, size)
	if override then
		return override
	end
	local holder = new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	}, parent)

	local ring = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.9, 0.9),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, holder)
	round(ring, 999)
	new("UIStroke", {
		Thickness = math.max(2, size * 0.055),
		Color = DIV_LIGHT,
		Transparency = 0,
	}, ring)

	local dot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.055),
		Size = UDim2.fromOffset(size * 0.15, size * 0.15),
		BackgroundColor3 = DIV_LIGHT,
		BorderSizePixel = 0,
	}, holder)
	round(dot, 999)

	local specs = {
		{ apexY = 0.42, length = 0.62, thickness = 0.062, color = DIV_LIGHT },
		{ apexY = 0.60, length = 0.46, thickness = 0.062, color = DIV_MID },
		{ apexY = 0.78, length = 0.30, thickness = 0.062, color = DIV_DEEP },
	}
	for _, spec in ipairs(specs) do
		local length = size * spec.length
		local offset = length * 0.3536
		local thickness = math.max(2, size * spec.thickness)
		bar(holder, 0.5 - offset / size, spec.apexY + offset / size, length, thickness, -45, spec.color)
		bar(holder, 0.5 + offset / size, spec.apexY + offset / size, length, thickness, 45, spec.color)
	end
	return holder
end

local function keycap(parent, x, y, letter, caption)
	local cap = new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(21, 21),
		BackgroundColor3 = CONFIG.PANEL,
		BackgroundTransparency = CONFIG.PANEL_TRANSPARENCY,
		BorderSizePixel = 0,
	}, parent)
	round(cap, 3)
	stroke(cap, 0.3)
	text(cap, letter, {
		Size = UDim2.fromScale(1, 1),
		Font = F_TITLE,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(214, 214, 220),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	text(parent, caption, {
		Position = UDim2.fromOffset(x + 28, y),
		Size = UDim2.fromOffset(80, 21),
		Font = F_BODY,
		TextSize = 13,
	})
	return cap
end

---------------------------------------------------------------------------
-- Datos reales: juego, miniatura, usuario, avatar
---------------------------------------------------------------------------
local function placeName()
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	if ok and type(info) == "table" and type(info.Name) == "string" and info.Name ~= "" then
		return info.Name
	end
	if type(game.Name) == "string" and game.Name ~= "" then
		return game.Name
	end
	return "Place " .. tostring(game.PlaceId)
end

--- Miniatura del juego: rbxthumb nativo (siempre disponible) y, si el executor deja
--- escribir archivos, primero intenta la versión 512x512 descargada.
local function placeThumbnail()
	local canFiles = type(writefile) == "function" and type(getcustomasset) == "function"
	if canFiles and type(game.HttpGet) == "function" then
		local okJson, body = pcall(function()
			return game:HttpGet(
				"https://thumbnails.roblox.com/v1/places/gameicons?placeIds="
					.. tostring(game.PlaceId)
					.. "&size=512x512&format=Png"
			)
		end)
		if okJson and type(body) == "string" then
			local url = string.match(body, '"imageUrl":"(.-)"')
			if url then
				local okBytes, bytes = pcall(function()
					return game:HttpGet(url)
				end)
				if okBytes and type(bytes) == "string" and #bytes > 1000 then
					pcall(writefile, "zenith_place.png", bytes)
					local okPath, path = pcall(getcustomasset, "zenith_place.png")
					if okPath and type(path) == "string" then
						return path
					end
				end
			end
		end
	end
	return "rbxthumb://type=GameIcon&id=" .. tostring(game.PlaceId) .. "&w=512&h=512"
end

---------------------------------------------------------------------------
-- Contador "Standard" (persistente entre re-ejecuciones)
---------------------------------------------------------------------------
local STANDARD_FILE = "ZenithStandard.txt"

local function standardDeadline()
	if type(shared) == "table" and type(shared.__zenithStandardDeadline) == "number" then
		return shared.__zenithStandardDeadline
	end
	local deadline = nil
	if type(readfile) == "function" and type(isfile) == "function" then
		local okExists, exists = pcall(isfile, STANDARD_FILE)
		if okExists and exists then
			local okRead, content = pcall(readfile, STANDARD_FILE)
			if okRead then
				local value = tonumber(content)
				if value and value > os.time() then
					deadline = value
				end
			end
		end
	end
	if not deadline then
		deadline = os.time() + CONFIG.STANDARD_SECONDS
		if type(writefile) == "function" then
			pcall(writefile, STANDARD_FILE, tostring(deadline))
		end
	end
	if type(shared) == "table" then
		shared.__zenithStandardDeadline = deadline
	end
	return deadline
end

local function clockText(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
end

local function playedText(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format(
		"%dd %dh %dm",
		math.floor(seconds / 86400),
		math.floor(seconds % 86400 / 3600),
		math.floor(seconds % 3600 / 60)
	)
end

---------------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------------
if type(shared) == "table" and shared.__zenithMenu then
	pcall(function()
		shared.__zenithMenu:Destroy()
	end)
	shared.__zenithMenu = nil
end

local guiParent = playerGui
if typeof(gethui) == "function" then
	local okHidden, hidden = pcall(gethui)
	if okHidden and hidden then
		guiParent = hidden
	end
end

local screenGui = new("ScreenGui", {
	Name = "ZenithHome",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 9999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, guiParent)
if type(shared) == "table" then
	shared.__zenithMenu = screenGui
end

local root = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(CONFIG.WIDTH, CONFIG.HEIGHT),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, screenGui)

local uiScale = new("UIScale", { Scale = 1 }, root)

local function resyncScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(CONFIG.WIDTH, CONFIG.HEIGHT)
	uiScale.Scale = math.clamp(math.min(viewport.X / CONFIG.WIDTH, viewport.Y / CONFIG.HEIGHT), 0.35, 2)
end
resyncScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resyncScale)
end

---------------------------------------------------------------------------
-- Barra superior: Z naranja · casa · personas · papel · E · Home
---------------------------------------------------------------------------
local LEFT_X = 54
local LEFT_W = 336

text(root, "Z", {
	Position = UDim2.fromOffset(LEFT_X, 190),
	Size = UDim2.fromOffset(28, 30),
	Font = F_TITLE,
	TextSize = 26,
	TextColor3 = CONFIG.ACCENT,
	TextXAlignment = Enum.TextXAlignment.Center,
})
iconHouse(root, LEFT_X + 36, 191, 26)
iconPeople(root, LEFT_X + 74, 191, 26)
iconPaper(root, LEFT_X + 112, 190, 27)
text(root, "E", {
	Position = UDim2.fromOffset(LEFT_X + 146, 190),
	Size = UDim2.fromOffset(20, 28),
	Font = F_TITLE,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Center,
})
verticalRule(root, LEFT_X + 172, 188, 30, 0.35)
text(root, "Home", {
	Position = UDim2.fromOffset(LEFT_X + 182, 188),
	Size = UDim2.fromOffset(90, 30),
	Font = F_TITLE,
	TextSize = 24,
})
verticalRule(root, LEFT_X + 276, 188, 30, 0.35)
rule(root, LEFT_X, 230, LEFT_W, 1, 0.3)

---------------------------------------------------------------------------
-- Columna izquierda: Continue / News / Updates
---------------------------------------------------------------------------
local continuePanel = panel(root, LEFT_X, 248, LEFT_W, 56, 0.35)
text(continuePanel, "Continue", {
	Size = UDim2.fromScale(1, 1),
	Font = F_TITLE,
	TextSize = 25,
	TextXAlignment = Enum.TextXAlignment.Center,
})

local newsPanel = panel(root, LEFT_X, 312, LEFT_W, 296, 0.35)
text(newsPanel, "News", {
	Size = UDim2.new(1, 0, 0, 36),
	Font = F_TITLE,
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Center,
})
rule(newsPanel, 8, 36, LEFT_W - 16, 1, 0.4)

local GAME_NAME = placeName()

local thumbFrame = new("Frame", {
	Position = UDim2.fromOffset(8, 44),
	Size = UDim2.fromOffset(LEFT_W - 16, 124),
	BackgroundColor3 = Color3.fromRGB(22, 24, 32),
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, newsPanel)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(30, 30, 42), Color3.fromRGB(64, 44, 82)),
}, thumbFrame)
text(thumbFrame, string.upper(string.sub(GAME_NAME, 1, 1)), {
	Size = UDim2.fromScale(1, 1),
	Font = F_TITLE,
	TextSize = 46,
	TextTransparency = 0.72,
	TextXAlignment = Enum.TextXAlignment.Center,
})
new("ImageLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = placeThumbnail(),
	ScaleType = Enum.ScaleType.Crop,
}, thumbFrame)

text(newsPanel, "TITLE", {
	Position = UDim2.fromOffset(8, 174),
	Size = UDim2.fromOffset(LEFT_W - 16, 16),
	Font = F_TITLE,
	TextSize = 13,
	TextColor3 = CONFIG.ACCENT,
})
text(newsPanel, GAME_NAME, {
	Position = UDim2.fromOffset(8, 190),
	Size = UDim2.fromOffset(LEFT_W - 16, 18),
	Font = F_TITLE,
	TextSize = 15,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
text(newsPanel, CONFIG.NEWS_DESC, {
	Position = UDim2.fromOffset(8, 210),
	Size = UDim2.fromOffset(LEFT_W - 16, 56),
	Font = F_BODY,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(226, 226, 232),
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
})
text(newsPanel, CONFIG.NEWS_DATE, {
	Position = UDim2.fromOffset(8, 270),
	Size = UDim2.fromOffset(LEFT_W - 16, 16),
	Font = F_TITLE,
	TextSize = 13,
	TextColor3 = CONFIG.ACCENT,
})

local updatesPanel = panel(root, LEFT_X, 616, LEFT_W, 46, 0.35)
text(updatesPanel, "Updates", {
	Size = UDim2.fromScale(1, 1),
	Font = F_TITLE,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Center,
})

keycap(root, LEFT_X, 676, "F", "Updates")
keycap(root, LEFT_X + 112, 676, "X", "Soon")
keycap(root, LEFT_X + 208, 676, "C", "Soon")

---------------------------------------------------------------------------
-- Columna derecha: Clearance / Division / Standard / Time Played / usuarios
---------------------------------------------------------------------------
local RIGHT_X = 868
local RIGHT_W = 328

text(root, "Clearance", {
	Position = UDim2.fromOffset(RIGHT_X, 246),
	Size = UDim2.fromOffset(120, 18),
	Font = F_TITLE,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Center,
})
text(root, "Division", {
	Position = UDim2.fromOffset(RIGHT_X + 140, 246),
	Size = UDim2.fromOffset(96, 18),
	Font = F_TITLE,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Center,
})
rule(root, RIGHT_X, 268, 118, 1, 0.35)
rule(root, RIGHT_X + 140, 268, 94, 1, 0.35)

text(root, CONFIG.CLEARANCE, {
	Position = UDim2.fromOffset(RIGHT_X, 274),
	Size = UDim2.fromOffset(140, 52),
	Font = F_TITLE,
	TextSize = 44,
})
divisionLogo(root, RIGHT_X + 176, 274, 84)

local standardValue = text(root, "12 Hours - Remaining", {
	Position = UDim2.fromOffset(RIGHT_X, 388),
	Size = UDim2.fromOffset(290, 24),
	Font = F_TITLE,
	TextSize = 20,
})
local standardClock = text(root, "12:00:00", {
	Position = UDim2.fromOffset(RIGHT_X, 414),
	Size = UDim2.fromOffset(200, 16),
	Font = F_MONO,
	TextSize = 13,
	TextColor3 = CONFIG.ACCENT,
})

text(root, "Time Played", {
	Position = UDim2.fromOffset(RIGHT_X, 452),
	Size = UDim2.fromOffset(200, 16),
	Font = F_TITLE,
	TextSize = 13,
	TextColor3 = CONFIG.DIM,
})
local playedValue = text(root, "0d 0h 0m", {
	Position = UDim2.fromOffset(RIGHT_X, 468),
	Size = UDim2.fromOffset(240, 24),
	Font = F_TITLE,
	TextSize = 20,
})

local friendsBox = panel(root, RIGHT_X, 512, RIGHT_W, 140, 0.35)
text(friendsBox, tostring(CONFIG.ACTIVE_USERS), {
	Position = UDim2.fromOffset(16, 12),
	Size = UDim2.fromOffset(90, 54),
	Font = F_TITLE,
	TextSize = 42,
})
text(friendsBox, "Active", {
	Position = UDim2.fromOffset(104, 20),
	Size = UDim2.fromOffset(120, 18),
	Font = F_TITLE,
	TextSize = 16,
})
text(friendsBox, "users", {
	Position = UDim2.fromOffset(104, 40),
	Size = UDim2.fromOffset(120, 18),
	Font = F_TITLE,
	TextSize = 16,
})
rule(friendsBox, 12, 84, RIGHT_W - 24, 1, 0.4)

local avatarFrame = new("Frame", {
	Position = UDim2.fromOffset(14, 92),
	Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = Color3.fromRGB(30, 32, 40),
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, friendsBox)
round(avatarFrame, 4)
new("ImageLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = "rbxthumb://type=AvatarBust&id=" .. tostring(localPlayer.UserId) .. "&w=420&h=420",
	ScaleType = Enum.ScaleType.Crop,
}, avatarFrame)

text(friendsBox, localPlayer.DisplayName, {
	Position = UDim2.fromOffset(66, 92),
	Size = UDim2.fromOffset(RIGHT_W - 80, 20),
	Font = F_TITLE,
	TextSize = 16,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
text(friendsBox, "@" .. localPlayer.Name, {
	Position = UDim2.fromOffset(66, 111),
	Size = UDim2.fromOffset(RIGHT_W - 80, 16),
	Font = F_BODY,
	TextSize = 12,
	TextColor3 = CONFIG.DIM,
	TextTruncate = Enum.TextTruncate.AtEnd,
})

verticalRule(root, RIGHT_X + RIGHT_W + 6, 240, 424, 0.75)

---------------------------------------------------------------------------
-- Comportamiento: cerrar con Continue y reabrir con la Z
---------------------------------------------------------------------------
local deadline = standardDeadline()
local sessionStart = os.clock()

if CONFIG.ALLOW_CLOSE then
	local clicker = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, continuePanel)

	local closeChip = new("TextButton", {
		Position = UDim2.fromOffset(LEFT_X, 190),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = CONFIG.PANEL,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Text = "Z",
		Font = F_TITLE,
		TextSize = 18,
		TextColor3 = CONFIG.ACCENT,
		AutoButtonColor = false,
		Visible = false,
	}, root)
	round(closeChip, 4)
	stroke(closeChip, 0.3)

	clicker.MouseButton1Click:Connect(function()
		root.Visible = false
		closeChip.Visible = true
	end)
	closeChip.MouseButton1Click:Connect(function()
		root.Visible = true
		closeChip.Visible = false
	end)
end

task.spawn(function()
	while screenGui.Parent do
		local remaining = deadline - os.time()
		if remaining > 0 then
			local hours = math.max(1, math.ceil(remaining / 3600))
			standardValue.Text = string.format("%d Hours - Remaining", hours)
			standardClock.Text = clockText(remaining)
		else
			standardValue.Text = "Expired"
			standardClock.Text = "00:00:00"
		end
		playedValue.Text = playedText(os.clock() - sessionStart)
		task.wait(0.5)
	end
end)
