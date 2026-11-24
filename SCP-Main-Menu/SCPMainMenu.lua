-- ZNTH Main Menu | Pixel-faithful, client-sided Roblox menu.
-- Paste this entire file into a LocalScript, or execute it as one loadstring chunk.
-- The attached PNG artwork is embedded for executor runtimes; Studio receives matching
-- code-drawn fallbacks until an uploaded rbxassetid is entered in Config.Assets.

-- Services.
local playersService = game:GetService("Players")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local marketplaceService = game:GetService("MarketplaceService")
local contentProvider = game:GetService("ContentProvider")
local runService = game:GetService("RunService")
local workspaceService = game:GetService("Workspace")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local localPlayer = playersService.LocalPlayer
while not localPlayer do
	playersService:GetPropertyChangedSignal("LocalPlayer"):Wait()
	localPlayer = playersService.LocalPlayer
end

local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Configuration. Asset values accept a numeric ID or a complete rbxassetid URI.
local Config = {
	GuiName = "ZNTHMainMenu",
	ReferenceWidth = 1223,
	ReferenceHeight = 813,
	DisplayOrder = 100,

	Accent = Color3.fromRGB(239, 137, 0),
	Panel = Color3.fromRGB(5, 5, 6),
	PanelRaised = Color3.fromRGB(11, 11, 13),
	White = Color3.fromRGB(239, 239, 242),
	Secondary = Color3.fromRGB(190, 190, 195),
	Muted = Color3.fromRGB(124, 124, 130),
	Line = Color3.fromRGB(205, 205, 210),

	StandardDurationSeconds = 12 * 60 * 60,
	ActiveUsers = 69,
	NewsDate = "16/03/2019",
	DefaultDescription = "Current experience detected automatically. Continue to enter the game and explore everything it has to offer.",

	Assets = {
		-- Upload SCP-Main-Menu/assets/zenith-logo-transparent.png and paste its ID here
		-- for Studio. Executors which support getcustomasset use the embedded PNG below.
		DivisionLogo = "",
		HomeIcon = "",
		PeopleIcon = "",
		DocumentIcon = "",
	},
}

local REGULAR_FONT = Enum.Font.Gotham
local MEDIUM_FONT = Enum.Font.GothamMedium
local BOLD_FONT = Enum.Font.GothamBold
local FAST_TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OPEN_TWEEN = TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local PRESS_TWEEN = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- PNG files supplied with this project, encoded into the single executable file.
-- They are decoded only when an executor exposes writefile + getcustomasset.
local EMBEDDED_ASSETS = {
	DivisionLogo = table.concat({
		"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",
		"AAAASUVORK5CYII=",
	}),
	HomeIcon = table.concat({
		"iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAACT0lEQVR4nO3aUU7EMAwA0RRx/ysvX3yAYLXbxLHjmXcBUns2UlHHkCRJkiRJkiRJkqSWHo/H",
		"I/sMmT6yD5Dpe/nkCLAB/F46NQJkAP8tmxjBlX2And5Z8HVdiNlgboB3f92U2wARwN1lEiJoH8DsErtH0DqAVcvrHEHbAFYvrWsELQOIWlbHCNoFEL2kbhG0",
		"edfNWEyH/xW0uAGyfpUdboPjA8heQvbfn3V0AFWGX+UcdxwbQLWhVzvPq44MoOqwq57rmeMCqD7k6uf77ZjXmNMGO8YZr4lH3AAnLn+MM85dPoAThvhM9fOX",
		"DqD68F5V+TnKBlB5aHdUfZ6SAVQd1qyKz1UugIpDWqna85V5Tak2mB0qvCaWuAGIyx+jxnOnB1BhCJmynz81gOyHryJzDmkBuPyfsuaREoDL/1vGXLYH4PKf",
		"2z2frQG4/NfsnNOW91AXf1/0/wrCbwCXPyd6fqEBuPw1IucYFoDLXytqniEBuPwYEXNdHoDLj7V6vksDcPl7rJzzklcMF59n9jVx+gZw+blm5z8VgMuvYWYP",
		"twNw+bXc3ce2T5IM5n07PhlL/yJIuQwAzgDgDADOAOAMAM4A4AwAzgDgDADOAOAMAM4A4AwAzgDgDADOAOAMAM4A4AwA7jP7AFEiPqjs+GGrNwCcAcAZAJwB",
		"wBkAnAHAGQCcAcAZAJwBwBkAnAHAGQCcAcAZAJwBwBkAnAHAGQCcAcAZAJwBwBkAnAHAGQCcAcAZAJwBwBkAnAHAGQCcAcAZAJwBSJIkSZIkSZIkSV19ATgW",
		"U5/bSEKPAAAAAElFTkSuQmCC",
	}),
	PeopleIcon = table.concat({
		"iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAACR0lEQVR4nO3bS27jMBAFQHkw97+yZyUgE8S2YpPdT2LVKkAAs0U+fuJQ2wYAAAAAAAAAAAAA",
		"AAAAnMmtu4Arud/v90e/u91ukX0dWdSZPBv0R5LCEFPI2bwz8N8lBOFPdwFnNGLwR37OJ9oTeCYzB6xrNbACHDR7tnatBn87Gn3HkQ5K2FPPJrrDPpkVI8NQ",
		"OTurQxwZgJEd/mmHdizNlSGI2gJmdPb+mbaHn8UcAhMPWV0Hs8p2IwJQ9cAJf3enaQ9A9aAIwf9aA5C8xHYHpar9tgCs0sHpWgKQ0vkpdXRqPwPQqzwAabMu",
		"rZ5qVoDFlQYgdbal1lXBCvBA91fHVe0LwOLKApC+zKbXN4sV4ImubaCyXQFYnAC8UH5Dp7g9ATigalA6thwBWJwAHDR7dnYdOKPuBKbbBynp0uqnrABvGDVo",
		"3YO/bYUBSHjYZ35b36fPk9IftoA3jNgCUq6rC8AvXPG9hfJGE79zf9X5V341zCHwhatfWy8PQPee992zepKvrY9iBXige6u69HsBKavAozq6B39XUUfbCtAd",
		"gu72U7RuAYkXLlJm/252Pc4AX6QN/m5mXW1fBHV2dveXL0m8G/jDz4lm1efVsLB6qpUugat39gijt62SM4CBzzV9CzD42fwZuLipATD7xxvdp9MCYPDPYUoA",
		"DP55OAMsbngAzP5zcSn0gCv/z2DoCnDV2X/V59o2Z4DlCcDiBGBxwwJw5X1y2677fFaAxQnA4gRgcQIAAAAAAAAAAAAAAAAAAAAAAAAQ6B+khzAUj6xQgAAA",
		"AABJRU5ErkJggg==",
	}),
	DocumentIcon = table.concat({
		"iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAABbElEQVR4nO3cwQnDMBAAQSuk/5aVDkIIGEnemQZszHKP4/B1AQAAAADPN1Y9eM45Vz37TmOM",
		"Zd/0H6/VL8BaAogTQJwA4gQQJ4A4AcQJIE4AcQKIE0CcAOIEECeAOAHECSBOAHECiBNAnADiHIUe4M5DUxMgTgBxAogTQJwA4gQQJ4A4AcQJIE4AcQKIE0Cc",
		"AOIEECeAOAHEvVe/wK9O+/vWNzsdw5gAcQKIE0CcAOIEECeAOAHECSDumEXQTsuTJzEB4gQQJ4A4AcQJIE4AcQKIE0DcMYsgF0H3MAHiBBAngDgBxAkgTgBx",
		"AogTQNwxi6CdlidPYgLECSBOAHECiBNAnADiBBAngLhjFkEugu5hAsQJIE4AcQKIE0CcAOIEECeAuGMWQTstT57EBIgTQJwA4gQQJ4A4AcQJIE4AcQKIE0Cc",
		"AOIEECeAOAHECSBOAHECiBNAnADiBBAngDgBxAkgTgBxAgAAAACAgg9plCDZ163H6AAAAABJRU5ErkJggg==",
	}),
}

-- Resolve the environment without making Studio depend on executor-only globals.
local function getSharedEnvironment()
	local environment = _G
	local ok, executorEnvironment = pcall(function()
		if type(getgenv) == "function" then
			return getgenv()
		end
		return nil
	end)

	if ok and type(executorEnvironment) == "table" then
		environment = executorEnvironment
	end

	return environment
end

local sharedEnvironment = getSharedEnvironment()
local previousMenu = sharedEnvironment.ZNTHMainMenu
if type(previousMenu) == "table" and type(previousMenu.Destroy) == "function" then
	pcall(function()
		previousMenu:Destroy()
	end)
end

local previousGui = playerGui:FindFirstChild(Config.GuiName)
if previousGui then
	previousGui:Destroy()
end

-- Pure Luau base64 decoder, used for the bundled transparent PNGs.
local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_LOOKUP = {}
for index = 1, #BASE64_ALPHABET do
	BASE64_LOOKUP[string.sub(BASE64_ALPHABET, index, index)] = index - 1
end

local function decodeBase64(data)
	local output = table.create(math.floor(#data * 0.75))
	local outputLength = 0
	local accumulator = 0
	local groupLength = 0

	local function appendByte(value)
		outputLength = outputLength + 1
		output[outputLength] = string.char(value)
	end

	-- Decode one four-character group at a time. Keeping the accumulator small
	-- avoids floating-point overflow on the embedded 15 KB division logo.
	for index = 1, #data do
		local character = string.sub(data, index, index)
		local value = BASE64_LOOKUP[character]
		if value then
			accumulator = accumulator * 64 + value
			groupLength = groupLength + 1
			if groupLength == 4 then
				appendByte(math.floor(accumulator / 65536) % 256)
				appendByte(math.floor(accumulator / 256) % 256)
				appendByte(accumulator % 256)
				accumulator = 0
				groupLength = 0
			end
		end
	end

	-- Padding characters are skipped above, leaving two or three useful values.
	if groupLength == 2 then
		appendByte(math.floor(accumulator / 16) % 256)
	elseif groupLength == 3 then
		appendByte(math.floor(accumulator / 1024) % 256)
		appendByte(math.floor(accumulator / 4) % 256)
	end

	return table.concat(output, "", 1, outputLength)
end

local function normalizeAsset(value)
	if value == nil then
		return ""
	end

	local text = tostring(value)
	if text == "" or text == "0" then
		return ""
	end
	if string.find(text, "://", 1, true) then
		return text
	end
	if string.match(text, "^%d+$") then
		return "rbxassetid://" .. text
	end
	return text
end

local function getExecutorFunction(name)
	local value = sharedEnvironment[name]
	if type(value) == "function" then
		return value
	end
	return nil
end

local writeFile = getExecutorFunction("writefile")
local makeFolder = getExecutorFunction("makefolder")
local getCustomAsset = getExecutorFunction("getcustomasset") or getExecutorFunction("getsynasset")

local function resolveEmbeddedAsset(key, fileName)
	local configured = normalizeAsset(Config.Assets[key])
	if configured ~= "" then
		return configured
	end

	if not writeFile or not getCustomAsset then
		return ""
	end

	local folder = "ZNTHMainMenuAssets"
	local path = folder .. "/" .. fileName
	local ok = pcall(function()
		-- Some executors omit isfolder and throw when makefolder sees an existing
		-- directory, so folder creation is intentionally its own ignored pcall.
		if makeFolder then
			pcall(makeFolder, folder)
		end
		-- Rewriting guarantees a stale file from an older script can never win.
		writeFile(path, decodeBase64(EMBEDDED_ASSETS[key]))
	end)

	if not ok then
		return ""
	end

	local assetOk, asset = pcall(getCustomAsset, path)
	if assetOk and type(asset) == "string" then
		return asset
	end
	return ""
end

local resolvedAssets = {
	DivisionLogo = resolveEmbeddedAsset("DivisionLogo", "zenith-logo-transparent.png"),
	HomeIcon = resolveEmbeddedAsset("HomeIcon", "icon-home.png"),
	PeopleIcon = resolveEmbeddedAsset("PeopleIcon", "icon-people.png"),
	DocumentIcon = resolveEmbeddedAsset("DocumentIcon", "icon-doc.png"),
}

local Menu = {
	open = false,
	destroyed = false,
	selectedNavigation = "Home",
	connections = {},
	navigation = {},
	hotkeys = {},
	callbacks = {},
	references = {},
	positions = {},
	scale = 1,
}

-- UI utility functions.
local function create(className, properties, parent)
	local object = Instance.new(className)
	for property, value in pairs(properties or {}) do
		object[property] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(Menu.connections, connection)
	return connection
end

local function tween(object, info, goals)
	if Menu.destroyed or not object or not object.Parent then
		return nil
	end
	local animation = tweenService:Create(object, info, goals)
	animation:Play()
	return animation
end

local function addStroke(parent, color, transparency, thickness)
	return create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or Config.Line,
		Transparency = transparency == nil and 0.48 or transparency,
		Thickness = thickness or 1,
		LineJoinMode = Enum.LineJoinMode.Miter,
	}, parent)
end

local function addLine(parent, position, size, transparency, color, zIndex)
	return create("Frame", {
		Name = "Divider",
		Position = position,
		Size = size,
		BackgroundColor3 = color or Config.Line,
		BackgroundTransparency = transparency == nil and 0.52 or transparency,
		BorderSizePixel = 0,
		ZIndex = zIndex or 4,
	}, parent)
end

local function makeText(parent, properties)
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = REGULAR_FONT,
		Text = "",
		TextColor3 = Config.White,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 5,
	}

	for property, value in pairs(properties or {}) do
		defaults[property] = value
	end
	return create("TextLabel", defaults, parent)
end

local function makeButton(parent, properties)
	local defaults = {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		ZIndex = 8,
	}
	for property, value in pairs(properties or {}) do
		defaults[property] = value
	end
	return create("TextButton", defaults, parent)
end

local function bindPressScale(button, target)
	local scaleObject = create("UIScale", { Scale = 1 }, target or button)
	connect(button.MouseButton1Down, function()
		tween(scaleObject, PRESS_TWEEN, { Scale = 0.975 })
	end)
	connect(button.MouseButton1Up, function()
		tween(scaleObject, PRESS_TWEEN, { Scale = 1 })
	end)
	connect(button.MouseLeave, function()
		tween(scaleObject, PRESS_TWEEN, { Scale = 1 })
	end)
	return scaleObject
end

local function makePanelBar(parent, name, y, height, text)
	local bar = create("Frame", {
		Name = name,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(335, height),
		BackgroundColor3 = Config.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, parent)
	local stroke = addStroke(bar, Config.Line, 0.48, 1)

	local label = makeText(bar, {
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		Font = REGULAR_FONT,
		Text = text,
		TextColor3 = Config.White,
		TextSize = 27,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
	})

	local button = makeButton(bar, {
		Name = name .. "Button",
		Size = UDim2.fromScale(1, 1),
	})
	bindPressScale(button, label)

	connect(button.MouseEnter, function()
		tween(bar, FAST_TWEEN, {
			BackgroundColor3 = Color3.fromRGB(24, 20, 15),
			BackgroundTransparency = 0.03,
		})
		tween(stroke, FAST_TWEEN, { Transparency = 0.18, Color = Config.Accent })
	end)
	connect(button.MouseLeave, function()
		tween(bar, FAST_TWEEN, {
			BackgroundColor3 = Config.Panel,
			BackgroundTransparency = 0.12,
		})
		tween(stroke, FAST_TWEEN, { Transparency = 0.48, Color = Config.Line })
	end)

	return bar, button, label
end

local function registerTint(list, object, property)
	table.insert(list, { object = object, property = property })
	return object
end

-- Small code-drawn icon fallbacks preserve the layout in Studio before PNG upload.
local function buildHomeFallback(parent, tintList)
	local holder = create("Frame", {
		Name = "HomeVectorFallback",
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(27, 26),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, parent)

	registerTint(tintList, create("Frame", {
		Position = UDim2.fromOffset(3, 8),
		Size = UDim2.fromOffset(17, 5),
		Rotation = -39,
		BackgroundColor3 = Config.Panel,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, holder), "BackgroundColor3")
	registerTint(tintList, create("Frame", {
		Position = UDim2.fromOffset(11, 8),
		Size = UDim2.fromOffset(17, 5),
		Rotation = 39,
		BackgroundColor3 = Config.Panel,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, holder), "BackgroundColor3")
	registerTint(tintList, create("Frame", {
		Position = UDim2.fromOffset(5, 12),
		Size = UDim2.fromOffset(18, 12),
		BackgroundColor3 = Config.Panel,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, holder), "BackgroundColor3")
	return holder
end

local function buildPeopleFallback(parent, tintList)
	local holder = create("Frame", {
		Name = "PeopleVectorFallback",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(28, 26),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, parent)

	local function circle(position, size, zIndex)
		local circleFrame = registerTint(tintList, create("Frame", {
			Position = position,
			Size = size,
			BackgroundColor3 = Config.White,
			BorderSizePixel = 0,
			ZIndex = zIndex,
		}, holder), "BackgroundColor3")
		create("UICorner", { CornerRadius = UDim.new(1, 0) }, circleFrame)
		return circleFrame
	end

	circle(UDim2.fromOffset(15, 3), UDim2.fromOffset(9, 9), 6)
	circle(UDim2.fromOffset(5, 5), UDim2.fromOffset(11, 11), 7)
	local backBody = circle(UDim2.fromOffset(13, 12), UDim2.fromOffset(14, 11), 6)
	backBody.ClipsDescendants = true
	local frontBody = circle(UDim2.fromOffset(1, 14), UDim2.fromOffset(19, 12), 7)
	frontBody.ClipsDescendants = true
	return holder
end

local function buildDocumentFallback(parent, tintList)
	local holder = create("Frame", {
		Name = "DocumentVectorFallback",
		Position = UDim2.fromOffset(11, 7),
		Size = UDim2.fromOffset(22, 28),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, parent)

	local page = create("Frame", {
		Position = UDim2.fromOffset(2, 1),
		Size = UDim2.fromOffset(18, 25),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, holder)
	local pageStroke = addStroke(page, Config.White, 0, 2)
	registerTint(tintList, pageStroke, "Color")

	registerTint(tintList, create("Frame", {
		Position = UDim2.fromOffset(12, 1),
		Size = UDim2.fromOffset(2, 8),
		Rotation = -45,
		BackgroundColor3 = Config.White,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, page), "BackgroundColor3")

	for _, y in ipairs({ 11, 15, 19 }) do
		registerTint(tintList, create("Frame", {
			Position = UDim2.fromOffset(4, y),
			Size = UDim2.fromOffset(10, 2),
			BackgroundColor3 = Config.White,
			BorderSizePixel = 0,
			ZIndex = 7,
		}, page), "BackgroundColor3")
	end
	return holder
end

local function makeNavigationIcon(parent, name, x, width, asset, fallbackBuilder)
	local button = makeButton(parent, {
		Name = name .. "Navigation",
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(width, 43),
		BackgroundColor3 = Config.Panel,
		BackgroundTransparency = 0.32,
		ZIndex = 5,
	})

	local image = create("ImageLabel", {
		Name = name .. "PNG",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(name == "Home" and 25 or 24, name == "Document" and 27 or 24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = asset,
		ImageColor3 = Config.White,
		ScaleType = Enum.ScaleType.Fit,
		Visible = asset ~= "",
		ZIndex = 7,
	}, button)

	local tintList = {}
	local fallback = fallbackBuilder(button, tintList)
	fallback.Visible = asset == ""
	bindPressScale(button, image.Visible and image or fallback)

	Menu.navigation[name] = {
		button = button,
		image = image,
		fallback = fallback,
		tint = tintList,
	}
	return button
end

local function setTint(navigation, color)
	navigation.image.ImageColor3 = color
	for _, record in ipairs(navigation.tint) do
		if record.object and record.object.Parent then
			record.object[record.property] = color
		end
	end
end

function Menu:SetNavigation(name)
	if not self.navigation[name] then
		return
	end
	self.selectedNavigation = name
	for navigationName, navigation in pairs(self.navigation) do
		local selected = navigationName == name
		tween(navigation.button, FAST_TWEEN, {
			BackgroundColor3 = selected and Config.Accent or Config.Panel,
			BackgroundTransparency = selected and 0 or 0.32,
		})
		setTint(navigation, selected and Color3.fromRGB(4, 4, 5) or Config.White)
	end
end

local function bindNavigationHover(name)
	local navigation = Menu.navigation[name]
	connect(navigation.button.MouseEnter, function()
		if Menu.selectedNavigation ~= name then
			tween(navigation.button, FAST_TWEEN, {
				BackgroundColor3 = Color3.fromRGB(37, 30, 20),
				BackgroundTransparency = 0.1,
			})
		end
	end)
	connect(navigation.button.MouseLeave, function()
		if Menu.selectedNavigation ~= name then
			tween(navigation.button, FAST_TWEEN, {
				BackgroundColor3 = Config.Panel,
				BackgroundTransparency = 0.32,
			})
		end
	end)
	connect(navigation.button.Activated, function()
		Menu:SetNavigation(name)
		local callback = Menu.callbacks[name]
		if type(callback) == "function" then
			task.spawn(callback, Menu)
		end
	end)
end

local function buildLeftPanel(screenGui)
	local root = create("Frame", {
		Name = "LeftMenu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -390, 0.544, 0),
		Size = UDim2.fromOffset(335, 488),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, screenGui)
	local rootScale = create("UIScale", { Scale = 1 }, root)
	Menu.references.LeftRoot = root
	Menu.references.LeftScale = rootScale

	local navigationRow = create("Frame", {
		Name = "NavigationRow",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(269, 43),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, root)

	local zLabel = makeText(navigationRow, {
		Name = "ZKey",
		Position = UDim2.fromOffset(-38, 0),
		Size = UDim2.fromOffset(28, 43),
		Font = REGULAR_FONT,
		Text = "Z",
		TextColor3 = Config.Accent,
		TextSize = 27,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
	})
	Menu.references.ZLabel = zLabel

	makeNavigationIcon(navigationRow, "Home", 0, 47, resolvedAssets.HomeIcon, buildHomeFallback)
	makeNavigationIcon(navigationRow, "People", 47, 42, resolvedAssets.PeopleIcon, buildPeopleFallback)
	makeNavigationIcon(navigationRow, "Document", 89, 42, resolvedAssets.DocumentIcon, buildDocumentFallback)

	addLine(navigationRow, UDim2.fromOffset(137, 6), UDim2.fromOffset(1, 31), 0.25, Config.Line, 7)
	makeText(navigationRow, {
		Name = "EKey",
		Position = UDim2.fromOffset(148, 0),
		Size = UDim2.fromOffset(25, 43),
		Text = "E",
		TextColor3 = Config.Accent,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 7,
	})
	addLine(navigationRow, UDim2.fromOffset(179, 6), UDim2.fromOffset(1, 31), 0.25, Config.Line, 7)
	makeText(navigationRow, {
		Name = "Location",
		Position = UDim2.fromOffset(190, 0),
		Size = UDim2.fromOffset(67, 43),
		Text = "Home",
		TextColor3 = Config.White,
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 7,
	})
	addLine(navigationRow, UDim2.fromOffset(268, 6), UDim2.fromOffset(1, 31), 0.25, Config.Line, 7)

	local _, continueButton = makePanelBar(root, "Continue", 45, 54, "Continue")
	local _, newsButton = makePanelBar(root, "News", 107, 54, "News")

	local imageHolder = create("Frame", {
		Name = "CurrentGameImage",
		Position = UDim2.fromOffset(0, 161),
		Size = UDim2.fromOffset(335, 126),
		BackgroundColor3 = Color3.fromRGB(43, 43, 49),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
	}, root)
	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(21, 22, 27)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(68, 68, 76)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 25, 29)),
		}),
		Rotation = 12,
	}, imageHolder)

	local loadingLabel = makeText(imageHolder, {
		Name = "Loading",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -20, 0, 20),
		Text = "DETECTING CURRENT EXPERIENCE",
		TextColor3 = Config.Secondary,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})

	local placeId = game.PlaceId
	local thumbnail = ""
	if placeId and placeId > 0 then
		thumbnail = string.format("rbxthumb://type=GameThumbnail&id=%d&w=768&h=432", placeId)
	end

	local gameImage = create("ImageLabel", {
		Name = "Thumbnail",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = thumbnail,
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 4,
	}, imageHolder)
	addStroke(imageHolder, Config.Line, 0.55, 1)

	local shade = create("Frame", {
		Name = "ImageShade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, imageHolder)
	create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.82),
			NumberSequenceKeypoint.new(0.62, 0.94),
			NumberSequenceKeypoint.new(1, 0.25),
		}),
		Rotation = 90,
	}, shade)

	local newsBody = create("Frame", {
		Name = "NewsBody",
		Position = UDim2.fromOffset(0, 287),
		Size = UDim2.fromOffset(335, 96),
		BackgroundColor3 = Config.PanelRaised,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, root)
	addStroke(newsBody, Config.Line, 0.48, 1)

	local titleLabel = makeText(newsBody, {
		Name = "CurrentGameTitle",
		Position = UDim2.fromOffset(5, 6),
		Size = UDim2.fromOffset(325, 17),
		Font = BOLD_FONT,
		Text = string.upper((game.Name and game.Name ~= "") and game.Name or "CURRENT GAME"),
		TextColor3 = Config.Accent,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
	})

	local descriptionLabel = makeText(newsBody, {
		Name = "CurrentGameDescription",
		Position = UDim2.fromOffset(5, 23),
		Size = UDim2.fromOffset(325, 51),
		Text = Config.DefaultDescription,
		TextColor3 = Config.Secondary,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 5,
	})

	makeText(newsBody, {
		Name = "Date",
		Position = UDim2.fromOffset(5, 74),
		Size = UDim2.fromOffset(150, 17),
		Font = MEDIUM_FONT,
		Text = Config.NewsDate,
		TextColor3 = Config.Accent,
		TextSize = 12,
		ZIndex = 5,
	})

	local _, updatesButton = makePanelBar(root, "Updates", 391, 55, "Updates")

	local keybindRow = create("Frame", {
		Name = "KeybindRow",
		Position = UDim2.fromOffset(-38, 449),
		Size = UDim2.fromOffset(307, 34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, root)

	local function makeHotkey(key, labelText, x, labelWidth, dividerAfter)
		local keyLabel = makeText(keybindRow, {
			Name = key .. "Key",
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(25, 30),
			Font = MEDIUM_FONT,
			Text = key,
			TextColor3 = Config.Accent,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 6,
		})
		addLine(keybindRow, UDim2.fromOffset(x + 30, 5), UDim2.fromOffset(1, 23), 0.28, Config.Line, 6)
		local valueLabel = makeText(keybindRow, {
			Name = key .. "Action",
			Position = UDim2.fromOffset(x + 38, 0),
			Size = UDim2.fromOffset(labelWidth, 30),
			Text = labelText,
			TextColor3 = Config.White,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
		})
		if dividerAfter then
			addLine(keybindRow, UDim2.fromOffset(x + 38 + labelWidth, 5), UDim2.fromOffset(1, 23), 0.28, Config.Line, 6)
		end
		Menu.hotkeys[key] = { key = keyLabel, value = valueLabel }
	end

	makeHotkey("F", "Updates", 0, 67, true)
	makeHotkey("X", "Soon", 109, 54, true)
	makeHotkey("C", "Soon", 202, 55, false)

	Menu.references.ContinueButton = continueButton
	Menu.references.NewsButton = newsButton
	Menu.references.UpdatesButton = updatesButton
	Menu.references.GameImage = gameImage
	Menu.references.GameImageLoading = loadingLabel
	Menu.references.GameTitle = titleLabel
	Menu.references.GameDescription = descriptionLabel

	bindNavigationHover("Home")
	bindNavigationHover("People")
	bindNavigationHover("Document")
	Menu:SetNavigation("Home")

	connect(continueButton.Activated, function()
		local callback = Menu.callbacks.Continue
		if type(callback) == "function" then
			task.spawn(callback, Menu)
		else
			Menu:SetOpen(false)
		end
	end)
	connect(newsButton.Activated, function()
		Menu:SetNavigation("Document")
		local callback = Menu.callbacks.News
		if type(callback) == "function" then
			task.spawn(callback, Menu)
		end
	end)
	connect(updatesButton.Activated, function()
		Menu:PulseHotkey("F")
		local callback = Menu.callbacks.Updates
		if type(callback) == "function" then
			task.spawn(callback, Menu)
		end
	end)

	return root
end

local function createLogoSegment(parent, position, size, rotation, color, zIndex)
	local segment = create("Frame", {
		Position = position,
		Size = size,
		Rotation = rotation,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = zIndex or 5,
	}, parent)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, segment)
	return segment
end

local function buildDivisionLogoFallback(parent)
	local holder = create("Frame", {
		Name = "DivisionLogoVectorFallback",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(92, 92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, parent)

	local outerRing = create("Frame", {
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.fromOffset(82, 82),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, holder)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, outerRing)
	addStroke(outerRing, Color3.fromRGB(216, 193, 216), 0, 7)

	local topMask = create("Frame", {
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.fromOffset(37, 17),
		BackgroundColor3 = Config.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, holder)
	local dot = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.fromOffset(15, 15),
		BackgroundColor3 = Color3.fromRGB(216, 193, 216),
		BorderSizePixel = 0,
		ZIndex = 7,
	}, holder)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)

	createLogoSegment(holder, UDim2.fromOffset(13, 38), UDim2.fromOffset(45, 7), -44, Color3.fromRGB(200, 155, 200), 6)
	createLogoSegment(holder, UDim2.fromOffset(34, 38), UDim2.fromOffset(45, 7), 44, Color3.fromRGB(200, 155, 200), 6)
	createLogoSegment(holder, UDim2.fromOffset(20, 55), UDim2.fromOffset(36, 7), -44, Color3.fromRGB(182, 118, 182), 6)
	createLogoSegment(holder, UDim2.fromOffset(36, 55), UDim2.fromOffset(36, 7), 44, Color3.fromRGB(182, 118, 182), 6)
	createLogoSegment(holder, UDim2.fromOffset(29, 70), UDim2.fromOffset(25, 7), -44, Color3.fromRGB(162, 75, 162), 6)
	createLogoSegment(holder, UDim2.fromOffset(38, 70), UDim2.fromOffset(25, 7), 44, Color3.fromRGB(162, 75, 162), 6)

	-- topMask is intentionally kept referenced so it is not mistaken for a tint element.
	topMask.Name = "TransparentGapApproximation"
	return holder
end

local function buildRightPanel(screenGui)
	local root = create("Frame", {
		Name = "RightMenu",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 370, 0.563, 0),
		Size = UDim2.fromOffset(323, 404),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, screenGui)
	local rootScale = create("UIScale", { Scale = 1 }, root)
	Menu.references.RightRoot = root
	Menu.references.RightScale = rootScale

	addLine(root, UDim2.fromOffset(0, 0), UDim2.fromOffset(323, 1), 0.25, Config.Line, 4)

	makeText(root, {
		Name = "ClearanceHeader",
		Position = UDim2.fromOffset(24, 10),
		Size = UDim2.fromOffset(110, 25),
		Text = "Clearance",
		TextColor3 = Config.White,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	makeText(root, {
		Name = "DivisionHeader",
		Position = UDim2.fromOffset(188, 10),
		Size = UDim2.fromOffset(82, 25),
		Text = "Division",
		TextColor3 = Config.White,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	addLine(root, UDim2.fromOffset(43, 36), UDim2.fromOffset(76, 1), 0.28, Config.Line, 5)
	addLine(root, UDim2.fromOffset(188, 36), UDim2.fromOffset(82, 1), 0.28, Config.Line, 5)

	makeText(root, {
		Name = "ClearanceValue",
		Position = UDim2.fromOffset(15, 54),
		Size = UDim2.fromOffset(135, 67),
		Font = BOLD_FONT,
		Text = "ZNTH",
		TextColor3 = Config.White,
		TextSize = 37,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 5,
	})

	local logoHolder = create("Frame", {
		Name = "DivisionLogoHolder",
		Position = UDim2.fromOffset(174, 43),
		Size = UDim2.fromOffset(112, 112),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, root)
	local logoImage = create("ImageLabel", {
		Name = "DivisionLogoPNG",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(96, 96),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = resolvedAssets.DivisionLogo,
		ScaleType = Enum.ScaleType.Fit,
		Visible = resolvedAssets.DivisionLogo ~= "",
		ZIndex = 6,
	}, logoHolder)
	local logoFallback = buildDivisionLogoFallback(logoHolder)
	logoFallback.Visible = not logoImage.Visible

	local infoFrame = create("Frame", {
		Name = "AccountInformation",
		Position = UDim2.fromOffset(0, 167),
		Size = UDim2.fromOffset(323, 94),
		BackgroundColor3 = Config.Panel,
		BackgroundTransparency = 0.22,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, root)
	addLine(infoFrame, UDim2.fromOffset(0, 0), UDim2.fromOffset(323, 1), 0.52, Config.Line, 4)
	addLine(infoFrame, UDim2.fromOffset(0, 93), UDim2.fromOffset(323, 1), 0.52, Config.Line, 4)

	makeText(infoFrame, {
		Name = "StandardLabel",
		Position = UDim2.fromOffset(12, 2),
		Size = UDim2.fromOffset(299, 20),
		Text = "Standard",
		TextColor3 = Config.White,
		TextSize = 13,
		ZIndex = 5,
	})
	local countdownValue = makeText(infoFrame, {
		Name = "StandardRemaining",
		Position = UDim2.fromOffset(12, 18),
		Size = UDim2.fromOffset(299, 25),
		Text = "12 Hours - Remaining",
		TextColor3 = Config.Secondary,
		TextSize = 19,
		ZIndex = 5,
	})

	makeText(infoFrame, {
		Name = "TimePlayedLabel",
		Position = UDim2.fromOffset(12, 48),
		Size = UDim2.fromOffset(299, 18),
		Text = "Time Played",
		TextColor3 = Config.White,
		TextSize = 13,
		ZIndex = 5,
	})
	local timePlayedValue = makeText(infoFrame, {
		Name = "TimePlayedValue",
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.fromOffset(299, 24),
		Text = "0d 0h 0m",
		TextColor3 = Config.Secondary,
		TextSize = 19,
		ZIndex = 5,
	})

	local activeFrame = create("Frame", {
		Name = "ActiveUsers",
		Position = UDim2.fromOffset(0, 270),
		Size = UDim2.fromOffset(323, 62),
		BackgroundColor3 = Config.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, root)
	addStroke(activeFrame, Config.Line, 0.48, 1)
	makeText(activeFrame, {
		Name = "ActiveCount",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.fromOffset(51, 62),
		Font = REGULAR_FONT,
		Text = tostring(Config.ActiveUsers),
		TextColor3 = Config.White,
		TextSize = 35,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	})
	makeText(activeFrame, {
		Name = "ActiveWord",
		Position = UDim2.fromOffset(62, 9),
		Size = UDim2.fromOffset(95, 19),
		Font = MEDIUM_FONT,
		Text = "Active",
		TextColor3 = Config.White,
		TextSize = 13,
		ZIndex = 5,
	})
	makeText(activeFrame, {
		Name = "UsersWord",
		Position = UDim2.fromOffset(62, 25),
		Size = UDim2.fromOffset(95, 27),
		Text = "users",
		TextColor3 = Config.White,
		TextSize = 20,
		ZIndex = 5,
	})

	local playerFrame = create("Frame", {
		Name = "LocalPlayer",
		Position = UDim2.fromOffset(0, 341),
		Size = UDim2.fromOffset(323, 47),
		BackgroundColor3 = Config.Panel,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, root)
	addStroke(playerFrame, Config.Line, 0.55, 1)
	local avatarBacking = create("Frame", {
		Name = "AvatarBacking",
		Position = UDim2.fromOffset(9, 6),
		Size = UDim2.fromOffset(35, 35),
		BackgroundColor3 = Color3.fromRGB(45, 45, 49),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, playerFrame)
	addStroke(avatarBacking, Config.Line, 0.5, 1)
	local avatar = create("ImageLabel", {
		Name = "Avatar",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 5,
	}, avatarBacking)
	local playerName = makeText(playerFrame, {
		Name = "Username",
		Position = UDim2.fromOffset(59, 0),
		Size = UDim2.fromOffset(251, 47),
		Text = localPlayer.Name,
		TextColor3 = Config.White,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
	})

	addLine(root, UDim2.fromOffset(0, 397), UDim2.fromOffset(323, 1), 0.52, Config.Line, 4)

	Menu.references.CountdownValue = countdownValue
	Menu.references.TimePlayedValue = timePlayedValue
	Menu.references.Avatar = avatar
	Menu.references.PlayerName = playerName
	Menu.references.DivisionLogo = logoImage

	return root
end

local screenGui = create("ScreenGui", {
	Name = Config.GuiName,
	DisplayOrder = Config.DisplayOrder,
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
Menu.references.ScreenGui = screenGui

buildLeftPanel(screenGui)
buildRightPanel(screenGui)

-- Responsive placement preserves the screenshot's 1223 x 813 proportions.
function Menu:UpdateScale()
	if self.destroyed then
		return
	end

	local camera = workspaceService.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(Config.ReferenceWidth, Config.ReferenceHeight)
	local scale = math.min(viewport.X / Config.ReferenceWidth, viewport.Y / Config.ReferenceHeight)
	scale = math.clamp(scale, 0.62, 1.35)
	self.scale = scale

	self.references.LeftScale.Scale = scale
	self.references.RightScale.Scale = scale

	self.positions.LeftOpen = UDim2.new(0, math.floor(55 * scale + 0.5), 0.544, 0)
	self.positions.LeftClosed = UDim2.new(0, -math.floor(365 * scale + 0.5), 0.544, 0)
	self.positions.RightOpen = UDim2.new(1, -math.floor(31 * scale + 0.5), 0.563, 0)
	self.positions.RightClosed = UDim2.new(1, math.floor(354 * scale + 0.5), 0.563, 0)

	if self.open then
		self.references.LeftRoot.Position = self.positions.LeftOpen
		self.references.RightRoot.Position = self.positions.RightOpen
	else
		self.references.LeftRoot.Position = self.positions.LeftClosed
		self.references.RightRoot.Position = self.positions.RightClosed
	end
end

function Menu:SetOpen(shouldOpen, instant)
	if self.destroyed then
		return
	end

	shouldOpen = shouldOpen == true
	self.open = shouldOpen
	self.references.LeftRoot.Visible = true
	self.references.RightRoot.Visible = true

	local leftGoal = shouldOpen and self.positions.LeftOpen or self.positions.LeftClosed
	local rightGoal = shouldOpen and self.positions.RightOpen or self.positions.RightClosed

	if instant then
		self.references.LeftRoot.Position = leftGoal
		self.references.RightRoot.Position = rightGoal
	else
		tween(self.references.LeftRoot, OPEN_TWEEN, { Position = leftGoal })
		tween(self.references.RightRoot, OPEN_TWEEN, { Position = rightGoal })
	end
end

function Menu:Toggle()
	self:SetOpen(not self.open)
end

function Menu:PulseHotkey(key)
	local hotkey = self.hotkeys[key]
	if not hotkey then
		return
	end

	hotkey.key.TextColor3 = Config.White
	hotkey.value.TextColor3 = Config.Accent
	hotkey.key.TextSize = 17
	tween(hotkey.key, FAST_TWEEN, { TextColor3 = Config.Accent, TextSize = 15 })
	tween(hotkey.value, FAST_TWEEN, { TextColor3 = Config.White })
end

local function sanitizeDescription(value)
	if type(value) ~= "string" or value == "" then
		return Config.DefaultDescription
	end
	local sanitized = string.gsub(value, "[%c]+", " ")
	sanitized = string.gsub(sanitized, "%s+", " ")

	-- Truncate by UTF-8 character boundary so an emoji or accented title can
	-- never leave invalid text in the Roblox label.
	local characterCount = utf8.len(sanitized)
	if characterCount and characterCount > 175 then
		local byteAfterLimit = utf8.offset(sanitized, 173)
		if byteAfterLimit then
			sanitized = string.sub(sanitized, 1, byteAfterLimit - 1) .. "..."
		end
	end
	return sanitized
end

-- Current experience data: title, real game thumbnail, and description.
local function bindCurrentGame()
	local image = Menu.references.GameImage
	if image.Image ~= "" then
		task.spawn(function()
			pcall(function()
				contentProvider:PreloadAsync({ image })
			end)
			if Menu.destroyed then
				return
			end
			if image.IsLoaded then
				Menu.references.GameImageLoading.Visible = false
			end
		end)
	end

	task.spawn(function()
		local ok, information = pcall(function()
			return marketplaceService:GetProductInfo(game.PlaceId, Enum.InfoType.Asset)
		end)

		if Menu.destroyed or not ok or type(information) ~= "table" then
			return
		end

		if type(information.Name) == "string" and information.Name ~= "" then
			Menu.references.GameTitle.Text = string.upper(information.Name)
		end
		Menu.references.GameDescription.Text = sanitizeDescription(information.Description)
	end)
end

-- Local Roblox username + headshot, loaded entirely on the client.
local function bindLocalPlayer()
	Menu.references.PlayerName.Text = localPlayer.Name
	task.spawn(function()
		local ok, thumbnail = pcall(function()
			return playersService:GetUserThumbnailAsync(
				localPlayer.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size180x180
			)
		end)
		if not Menu.destroyed and ok and type(thumbnail) == "string" then
			Menu.references.Avatar.Image = thumbnail
		end
	end)
end

local function getServerTime()
	local ok, value = pcall(function()
		return workspaceService:GetServerTimeNow()
	end)
	if ok and type(value) == "number" then
		return value
	end
	return os.time()
end

local STANDARD_EXPIRY_ATTRIBUTE = "ZNTHStandardExpiresAt"
local startedAt = getServerTime()
local expiresAt = localPlayer:GetAttribute(STANDARD_EXPIRY_ATTRIBUTE)
if type(expiresAt) ~= "number" or expiresAt <= startedAt then
	expiresAt = startedAt + Config.StandardDurationSeconds
	pcall(function()
		localPlayer:SetAttribute(STANDARD_EXPIRY_ATTRIBUTE, expiresAt)
	end)
end

local function formatRemaining(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	if seconds <= 0 then
		return "Expired"
	end
	if seconds >= Config.StandardDurationSeconds then
		return "12 Hours - Remaining"
	end
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remainingSeconds = seconds % 60
	return string.format("%02d:%02d:%02d - Remaining", hours, minutes, remainingSeconds)
end

local function formatPlayed(seconds)
	seconds = math.max(0, math.floor(seconds))
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	return string.format("%dd %dh %dm", days, hours, minutes)
end

local function updateTimers()
	local now = getServerTime()
	Menu.references.CountdownValue.Text = formatRemaining(expiresAt - now)
	Menu.references.TimePlayedValue.Text = formatPlayed(now - startedAt)
end

local timerAccumulator = 1
connect(runService.Heartbeat, function(deltaTime)
	timerAccumulator = timerAccumulator + deltaTime
	if timerAccumulator >= 1 then
		timerAccumulator = timerAccumulator % 1
		updateTimers()
	end
end)
updateTimers()

-- Keyboard controls shown in the reference: E toggles; Z opens Home; F/X/C pulse hints.
connect(userInputService.InputBegan, function(input, gameProcessed)
	if gameProcessed or userInputService:GetFocusedTextBox() then
		return
	end

	if input.KeyCode == Enum.KeyCode.E then
		Menu:Toggle()
	elseif input.KeyCode == Enum.KeyCode.Z then
		if not Menu.open then
			Menu:SetOpen(true)
		end
		Menu:SetNavigation("Home")
		tween(Menu.references.ZLabel, FAST_TWEEN, { TextColor3 = Config.White })
		task.delay(0.14, function()
			if not Menu.destroyed then
				tween(Menu.references.ZLabel, FAST_TWEEN, { TextColor3 = Config.Accent })
			end
		end)
	elseif input.KeyCode == Enum.KeyCode.F then
		Menu:PulseHotkey("F")
		local callback = Menu.callbacks.Updates
		if type(callback) == "function" then
			task.spawn(callback, Menu)
		end
	elseif input.KeyCode == Enum.KeyCode.X then
		Menu:PulseHotkey("X")
		local callback = Menu.callbacks.X
		if type(callback) == "function" then
			task.spawn(callback, Menu)
		end
	elseif input.KeyCode == Enum.KeyCode.C then
		Menu:PulseHotkey("C")
		local callback = Menu.callbacks.C
		if type(callback) == "function" then
			task.spawn(callback, Menu)
		end
	end
end)

local function bindViewport()
	local camera = workspaceService.CurrentCamera
	if camera then
		connect(camera:GetPropertyChangedSignal("ViewportSize"), function()
			Menu:UpdateScale()
		end)
	end
end

connect(workspaceService:GetPropertyChangedSignal("CurrentCamera"), function()
	Menu:UpdateScale()
end)

function Menu:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true

	for _, connection in ipairs(self.connections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(self.connections)

	if self.references.ScreenGui and self.references.ScreenGui.Parent then
		self.references.ScreenGui:Destroy()
	end

	if sharedEnvironment.ZNTHMainMenu == self then
		sharedEnvironment.ZNTHMainMenu = nil
	end
end

bindViewport()
Menu:UpdateScale()
bindCurrentGame()
bindLocalPlayer()
sharedEnvironment.ZNTHMainMenu = Menu

-- Start just off-screen, then reproduce the two-sided entrance from the reference.
Menu:SetOpen(false, true)
task.defer(function()
	if not Menu.destroyed then
		Menu:SetOpen(true)
	end
end)

return Menu
