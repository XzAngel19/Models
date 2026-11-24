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
local lightingService = game:GetService("Lighting")
local starterGui = game:GetService("StarterGui")
local coreGuiService = game:GetService("CoreGui")

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

	-- Neutral monochrome palette derived from the supplied mobile reference.
	Accent = Color3.fromRGB(207, 211, 217),
	Panel = Color3.fromRGB(5, 5, 6),
	PanelRaised = Color3.fromRGB(12, 13, 15),
	White = Color3.fromRGB(242, 243, 245),
	Secondary = Color3.fromRGB(181, 185, 191),
	Muted = Color3.fromRGB(108, 112, 119),
	Line = Color3.fromRGB(198, 202, 208),

	StandardDurationSeconds = 12 * 60 * 60,
	ActiveUsers = 69,
	NewsDate = "16/03/2019",
	DefaultDescription = "Current experience detected automatically. Enter any key to continue and explore everything it has to offer.",

	-- World-space presentation: both menu bases are real camera-relative planes.
	BlurSize = 18,
	SurfaceDepth = 8,
	SurfaceWidthCompression = 0.86,
	SurfaceInwardYaw = 17,
	SurfaceDefaultPitch = -3,
	SurfaceMaxYaw = 26,
	SurfaceMaxPitch = 15,

	Assets = {
		-- Studio can use uploaded IDs; compatible executors decode the embedded PNGs.
		DivisionLogo = "",
		OrientationGizmo = "",
		HomeIcon = "",
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
		"RU5ErkJggg==",
	}),
	OrientationGizmo = table.concat({
		"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",
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
	DivisionLogo = resolveEmbeddedAsset("DivisionLogo", "zenith-logo-monochrome.png"),
	OrientationGizmo = resolveEmbeddedAsset("OrientationGizmo", "orientation-gizmo-reference.png"),
	HomeIcon = resolveEmbeddedAsset("HomeIcon", "icon-home.png"),
	DocumentIcon = resolveEmbeddedAsset("DocumentIcon", "icon-doc.png"),
}

local KEY_LINK_TEXT = "Zenith.com"
local clipboardWriter = getExecutorFunction("setclipboard") or getExecutorFunction("toclipboard")

local Menu = {
	open = false,
	destroyed = false,
	keyAccepted = false,
	selectedNavigation = "Home",
	connections = {},
	navigation = {},
	hotkeys = {},
	callbacks = {},
	references = {},
	positions = {},
	coreGuiStates = {},
	coreGuiCaptured = false,
	topbarWasEnabled = true,
	robloxGui = nil,
	robloxGuiWasEnabled = true,
	scale = 1,
	openAmount = 0,
	targetOpenAmount = 0,
	orientationYaw = 0,
	targetOrientationYaw = 0,
	orientationPitch = Config.SurfaceDefaultPitch,
	targetOrientationPitch = Config.SurfaceDefaultPitch,
	orientationDragging = false,
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
			BackgroundColor3 = Color3.fromRGB(24, 25, 28),
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
	fallback.AnchorPoint = Vector2.new(0.5, 0.5)
	fallback.Position = UDim2.fromScale(0.5, 0.5)
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
				BackgroundColor3 = Color3.fromRGB(34, 35, 38),
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

local function buildLeftPanel(surfaceGui, overlayGui)
	local root = create("Frame", {
		Name = "LeftMenu",
		Position = UDim2.fromOffset(50, 12),
		Size = UDim2.fromOffset(335, 452),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, surfaceGui)
	Menu.references.LeftRoot = root

	-- The navigation strip now spans exactly the same width as Key System.
	local navigationRow = create("Frame", {
		Name = "NavigationRow",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(335, 43),
		BackgroundColor3 = Config.Panel,
		BackgroundTransparency = 0.22,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, root)
	addStroke(navigationRow, Config.Line, 0.55, 1)

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

	makeNavigationIcon(navigationRow, "Home", 0, 168, resolvedAssets.HomeIcon, buildHomeFallback)
	makeNavigationIcon(navigationRow, "Document", 168, 167, resolvedAssets.DocumentIcon, buildDocumentFallback)
	addLine(navigationRow, UDim2.fromOffset(167, 6), UDim2.fromOffset(1, 31), 0.4, Config.Line, 8)

	local keyBar, keyButton, keyLabel = makePanelBar(root, "KeySystem", 48, 54, "Key System")
	local keyStroke = keyBar:FindFirstChildOfClass("UIStroke")
	-- The editable field lives in the flat overlay ScreenGui, then follows the
	-- projected 3D Key System bar every frame. This prevents Roblox's mobile
	-- keyboard from lifting the field away from the Success/Key System box.
	local keyInput = create("TextBox", {
		Name = "KeyInputOverlay",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(-5000, -5000),
		Size = UDim2.fromOffset(300, 48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = MEDIUM_FONT,
		MultiLine = false,
		PlaceholderColor3 = Config.Muted,
		PlaceholderText = "TYPE ANY KEY  •  PRESS ENTER",
		Text = "",
		TextColor3 = Config.White,
		TextSize = 16,
		TextStrokeTransparency = 0.82,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 200,
	}, overlayGui)

	-- News is now one joined card: no separate News bar above the experience image.
	local imageHolder = create("Frame", {
		Name = "CurrentGameNews",
		Position = UDim2.fromOffset(0, 108),
		Size = UDim2.fromOffset(335, 146),
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
	addStroke(imageHolder, Config.Line, 0.42, 1)

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

	local newsBadge = create("Frame", {
		Name = "IntegratedNewsBadge",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(62, 23),
		BackgroundColor3 = Config.Panel,
		BackgroundTransparency = 0.14,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, imageHolder)
	addStroke(newsBadge, Config.Line, 0.55, 1)
	makeText(newsBadge, {
		Size = UDim2.fromScale(1, 1),
		Font = BOLD_FONT,
		Text = "NEWS",
		TextColor3 = Config.Accent,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 8,
	})

	local newsBody = create("Frame", {
		Name = "NewsBody",
		Position = UDim2.fromOffset(0, 254),
		Size = UDim2.fromOffset(335, 96),
		BackgroundColor3 = Config.PanelRaised,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, root)
	addStroke(newsBody, Config.Line, 0.42, 1)

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

	local _, updatesButton = makePanelBar(root, "Updates", 358, 55, "Updates")

	local keybindRow = create("Frame", {
		Name = "KeybindRow",
		Position = UDim2.fromOffset(0, 417),
		Size = UDim2.fromOffset(335, 34),
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

	makeHotkey("F", "Updates", 0, 70, true)
	makeHotkey("X", "Key Link", 110, 74, true)
	makeHotkey("C", "Soon", 224, 65, false)
	local keyLinkButton = makeButton(keybindRow, {
		Name = "KeyLinkButton",
		Position = UDim2.fromOffset(110, 0),
		Size = UDim2.fromOffset(112, 30),
		ZIndex = 9,
	})
	connect(keyLinkButton.Activated, function()
		Menu:PulseHotkey("X")
		Menu:CopyKeyLink()
		local callback = Menu.callbacks.KeyLink or Menu.callbacks.X
		if type(callback) == "function" then
			task.spawn(callback, Menu)
		end
	end)

	Menu.references.KeySystemBar = keyBar
	Menu.references.KeySystemButton = keyButton
	Menu.references.KeySystemLabel = keyLabel
	Menu.references.KeySystemInput = keyInput
	Menu.references.KeySystemStroke = keyStroke
	Menu.references.KeyLinkButton = keyLinkButton
	Menu.references.UpdatesButton = updatesButton
	Menu.references.GameImage = gameImage
	Menu.references.GameImageLoading = loadingLabel
	Menu.references.GameTitle = titleLabel
	Menu.references.GameDescription = descriptionLabel

	bindNavigationHover("Home")
	bindNavigationHover("Document")
	Menu:SetNavigation("Home")

	local function restoreKeyPrompt()
		if Menu.destroyed or Menu.keyAccepted then
			return
		end
		keyInput.Visible = false
		keyInput.Text = ""
		keyLabel.Text = "Key System"
		keyLabel.TextColor3 = Config.White
		keyLabel.Visible = true
		keyButton.Visible = true
	end

	local function submitKey()
		if Menu.destroyed or Menu.keyAccepted then
			return
		end

		if not string.find(keyInput.Text, "%S") then
			keyInput.Text = ""
			keyInput.PlaceholderText = "ENTER ANY KEY FIRST"
			tween(keyInput, FAST_TWEEN, { TextColor3 = Config.Accent })
			task.delay(0.2, function()
				if not Menu.destroyed then
					tween(keyInput, FAST_TWEEN, { TextColor3 = Config.White })
				end
			end)
			return
		end

		local acceptedKey = keyInput.Text
		Menu.keyAccepted = true
		keyInput.Visible = false
		keyLabel.Visible = true
		keyLabel.Text = "Succes!"
		keyLabel.TextColor3 = Color3.fromRGB(128, 255, 164)
		keyButton.Visible = true
		tween(keyBar, FAST_TWEEN, {
			BackgroundColor3 = Color3.fromRGB(12, 36, 23),
			BackgroundTransparency = 0.02,
		})
		if keyStroke then
			tween(keyStroke, FAST_TWEEN, { Color = Color3.fromRGB(128, 255, 164), Transparency = 0.1 })
		end

		local callback = Menu.callbacks.KeyAccepted
		if type(callback) == "function" then
			task.spawn(callback, Menu, acceptedKey)
		end

		task.delay(0.7, function()
			if not Menu.destroyed then
				Menu:SetOpen(false)
			end
		end)
	end

	connect(keyButton.Activated, function()
		if Menu.keyAccepted then
			Menu:SetOpen(false)
			return
		end
		keyLabel.Visible = false
		keyButton.Visible = false
		keyInput.Visible = true
		keyInput.PlaceholderText = "TYPE ANY KEY  •  PRESS ENTER"
		task.defer(function()
			if not Menu.destroyed and keyInput.Visible then
				keyInput:CaptureFocus()
			end
		end)
	end)
	connect(keyInput.FocusLost, function(enterPressed)
		if enterPressed then
			submitKey()
		else
			restoreKeyPrompt()
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
	addStroke(outerRing, Color3.fromRGB(215, 219, 225), 0, 7)

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
		BackgroundColor3 = Color3.fromRGB(215, 219, 225),
		BorderSizePixel = 0,
		ZIndex = 7,
	}, holder)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)

	createLogoSegment(holder, UDim2.fromOffset(13, 38), UDim2.fromOffset(45, 7), -44, Color3.fromRGB(245, 246, 248), 6)
	createLogoSegment(holder, UDim2.fromOffset(34, 38), UDim2.fromOffset(45, 7), 44, Color3.fromRGB(245, 246, 248), 6)
	createLogoSegment(holder, UDim2.fromOffset(20, 55), UDim2.fromOffset(36, 7), -44, Color3.fromRGB(145, 151, 160), 6)
	createLogoSegment(holder, UDim2.fromOffset(36, 55), UDim2.fromOffset(36, 7), 44, Color3.fromRGB(145, 151, 160), 6)
	createLogoSegment(holder, UDim2.fromOffset(29, 70), UDim2.fromOffset(25, 7), -44, Color3.fromRGB(42, 46, 52), 6)
	createLogoSegment(holder, UDim2.fromOffset(38, 70), UDim2.fromOffset(25, 7), 44, Color3.fromRGB(42, 46, 52), 6)

	-- topMask is intentionally kept referenced so it is not mistaken for a tint element.
	topMask.Name = "TransparentGapApproximation"
	return holder
end

local function buildRightPanel(surfaceGui)
	local root = create("Frame", {
		Name = "RightMenu",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(323, 384),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, surfaceGui)
	Menu.references.RightRoot = root

	addLine(root, UDim2.fromOffset(0, 0), UDim2.fromOffset(323, 1), 0.25, Config.Line, 4)

	-- Clearance and Division were intentionally removed. The supplied Zenith mark
	-- is now the only centered identity in the upper section.
	local logoHolder = create("Frame", {
		Name = "ZenithLogoHolder",
		Position = UDim2.fromOffset(96, 5),
		Size = UDim2.fromOffset(131, 131),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, root)
	local logoImage = create("ImageLabel", {
		Name = "ZenithLogoPNG",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(118, 118),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = resolvedAssets.DivisionLogo,
		ScaleType = Enum.ScaleType.Fit,
		Visible = resolvedAssets.DivisionLogo ~= "",
		ZIndex = 6,
	}, logoHolder)
	local logoFallback = buildDivisionLogoFallback(logoHolder)
	create("UIScale", { Scale = 1.24 }, logoFallback)
	logoFallback.Visible = not logoImage.Visible

	local infoFrame = create("Frame", {
		Name = "AccountInformation",
		Position = UDim2.fromOffset(0, 145),
		Size = UDim2.fromOffset(323, 94),
		BackgroundColor3 = Config.Panel,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, root)
	addLine(infoFrame, UDim2.fromOffset(0, 0), UDim2.fromOffset(323, 1), 0.42, Config.Line, 4)
	addLine(infoFrame, UDim2.fromOffset(0, 93), UDim2.fromOffset(323, 1), 0.42, Config.Line, 4)

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
		Position = UDim2.fromOffset(0, 248),
		Size = UDim2.fromOffset(323, 62),
		BackgroundColor3 = Config.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, root)
	addStroke(activeFrame, Config.Line, 0.42, 1)
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
		Position = UDim2.fromOffset(0, 319),
		Size = UDim2.fromOffset(323, 47),
		BackgroundColor3 = Config.Panel,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, root)
	addStroke(playerFrame, Config.Line, 0.5, 1)
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

	addLine(root, UDim2.fromOffset(0, 375), UDim2.fromOffset(323, 1), 0.45, Config.Line, 4)

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

-- Remove orphaned presentation objects left by an interrupted prior execution.
for _, staleName in ipairs({ "ZNTHLeftSurface", "ZNTHRightSurface" }) do
	local staleSurface = playerGui:FindFirstChild(staleName)
	if staleSurface then
		staleSurface:Destroy()
	end
end
local staleFolder = workspaceService:FindFirstChild("ZNTHMenu3D")
if staleFolder then
	staleFolder:Destroy()
end
local staleBlur = lightingService:FindFirstChild("ZNTHMenuBlur")
if staleBlur then
	staleBlur:Destroy()
end

local blurEffect = create("BlurEffect", {
	Name = "ZNTHMenuBlur",
	Enabled = false,
	Size = 0,
}, lightingService)
Menu.references.BlurEffect = blurEffect

local surfaceFolder = create("Folder", {
	Name = "ZNTHMenu3D",
	Archivable = false,
}, workspaceService)
Menu.references.SurfaceFolder = surfaceFolder

local LEFT_CANVAS_SIZE = Vector2.new(410, 480)
local RIGHT_CANVAS_SIZE = Vector2.new(350, 400)

local function createWorldSurface(name, canvasSize)
	local part = create("Part", {
		Name = name .. "Plane",
		Anchored = true,
		Archivable = false,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Color = Color3.new(0, 0, 0),
		CFrame = CFrame.new(0, 100000, 0),
		LocalTransparencyModifier = 1,
		Massless = true,
		Size = Vector3.new(1, 1, 0.04),
		Transparency = 1,
	}, surfaceFolder)

	local surfaceGui = create("SurfaceGui", {
		Name = name,
		Active = true,
		Adornee = part,
		AlwaysOnTop = true,
		Brightness = 1,
		CanvasSize = canvasSize,
		Enabled = false,
		Face = Enum.NormalId.Back,
		LightInfluence = 0,
		MaxDistance = 1000,
		ResetOnSpawn = false,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		ZOffset = 0.01,
	}, playerGui)

	return part, surfaceGui
end

local leftPart, leftSurface = createWorldSurface("ZNTHLeftSurface", LEFT_CANVAS_SIZE)
local rightPart, rightSurface = createWorldSurface("ZNTHRightSurface", RIGHT_CANVAS_SIZE)
Menu.references.LeftPart = leftPart
Menu.references.RightPart = rightPart
Menu.references.LeftSurface = leftSurface
Menu.references.RightSurface = rightSurface

buildLeftPanel(leftSurface, screenGui)
buildRightPanel(rightSurface)

-- Recreate the Studio-style orientation block visible in the supplied reference.
local function buildOrientationGizmo(parent)
	local root = create("Frame", {
		Name = "OrientationGizmo",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 20),
		Size = UDim2.fromOffset(102, 92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 50,
	}, parent)

	-- This transparent PNG is extracted from the exact Studio view selector in
	-- the supplied reference (Back/Right faces with X/Y/Z axes), avoiding the
	-- flat rectangles that made the previous approximation look 2D.
	local exactImage = create("ImageLabel", {
		Name = "StudioOrientationReference",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = resolvedAssets.OrientationGizmo,
		ImageTransparency = 0,
		ScaleType = Enum.ScaleType.Fit,
		Visible = resolvedAssets.OrientationGizmo ~= "",
		ZIndex = 52,
	}, root)

	-- A compact code-drawn fallback remains available in Studio before the PNG
	-- receives an uploaded asset ID. It intentionally has no opaque square.
	local fallback = create("Frame", {
		Name = "StudioOrientationFallback",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = not exactImage.Visible,
		ZIndex = 51,
	}, root)
	local orbit = create("Frame", {
		Position = UDim2.fromOffset(17, 7),
		Size = UDim2.fromOffset(68, 68),
		BackgroundColor3 = Color3.fromRGB(94, 96, 101),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 51,
	}, fallback)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, orbit)
	local orbitStroke = addStroke(orbit, Color3.fromRGB(185, 188, 194), 0.5, 1)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(159, 162, 168), Color3.fromRGB(66, 68, 73)),
		Rotation = 90,
	}, orbit)

	local topFace = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(51, 26),
		Size = UDim2.fromOffset(29, 29),
		Rotation = 45,
		BackgroundColor3 = Color3.fromRGB(158, 161, 167),
		BorderSizePixel = 0,
		ZIndex = 53,
	}, fallback)
	addStroke(topFace, Color3.fromRGB(210, 212, 216), 0.55, 1)
	local backFace = create("Frame", {
		Position = UDim2.fromOffset(25, 31),
		Size = UDim2.fromOffset(26, 31),
		BackgroundColor3 = Color3.fromRGB(126, 129, 135),
		BorderSizePixel = 0,
		ZIndex = 54,
	}, fallback)
	local rightFace = create("Frame", {
		Position = UDim2.fromOffset(51, 31),
		Size = UDim2.fromOffset(26, 31),
		BackgroundColor3 = Color3.fromRGB(151, 154, 160),
		BorderSizePixel = 0,
		ZIndex = 54,
	}, fallback)
	addStroke(backFace, Color3.fromRGB(205, 207, 212), 0.58, 1)
	addStroke(rightFace, Color3.fromRGB(205, 207, 212), 0.58, 1)
	makeText(backFace, {
		Size = UDim2.fromScale(1, 1),
		Text = "Back",
		TextColor3 = Color3.fromRGB(40, 42, 46),
		TextSize = 8,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 55,
	})
	makeText(rightFace, {
		Size = UDim2.fromScale(1, 1),
		Text = "Right",
		TextColor3 = Color3.fromRGB(40, 42, 46),
		TextSize = 8,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 55,
	})
	addLine(fallback, UDim2.fromOffset(50, 0), UDim2.fromOffset(2, 18), 0.04, Color3.fromRGB(81, 192, 111), 56)
	addLine(fallback, UDim2.fromOffset(5, 64), UDim2.fromOffset(22, 2), 0.04, Color3.fromRGB(54, 115, 226), 56)
	addLine(fallback, UDim2.fromOffset(76, 64), UDim2.fromOffset(21, 2), 0.04, Color3.fromRGB(226, 69, 72), 56)
	makeText(fallback, {
		Position = UDim2.fromOffset(45, -3), Size = UDim2.fromOffset(13, 13),
		Font = BOLD_FONT, Text = "Y", TextColor3 = Color3.fromRGB(81, 192, 111), TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 57,
	})
	makeText(fallback, {
		Position = UDim2.fromOffset(0, 58), Size = UDim2.fromOffset(12, 13),
		Font = BOLD_FONT, Text = "Z", TextColor3 = Color3.fromRGB(54, 115, 226), TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 57,
	})
	makeText(fallback, {
		Position = UDim2.fromOffset(93, 58), Size = UDim2.fromOffset(9, 13),
		Font = BOLD_FONT, Text = "X", TextColor3 = Color3.fromRGB(226, 69, 72), TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 57,
	})

	local dragButton = makeButton(root, {
		Name = "RotateBases",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
	})

	connect(dragButton.MouseEnter, function()
		if exactImage.Visible then
			tween(exactImage, FAST_TWEEN, { ImageTransparency = 0.08 })
		else
			tween(orbitStroke, FAST_TWEEN, { Transparency = 0.15, Color = Config.White })
		end
	end)
	connect(dragButton.MouseLeave, function()
		if exactImage.Visible then
			tween(exactImage, FAST_TWEEN, { ImageTransparency = 0 })
		elseif not Menu.orientationDragging then
			tween(orbitStroke, FAST_TWEEN, { Transparency = 0.5, Color = Color3.fromRGB(185, 188, 194) })
		end
	end)
	connect(dragButton.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		Menu.orientationDragging = true
		Menu.orientationDragInput = input
		Menu.orientationDragLast = Vector2.new(input.Position.X, input.Position.Y)
		Menu.orientationDragDistance = 0
	end)
	connect(userInputService.InputChanged, function(input)
		if not Menu.orientationDragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if Menu.orientationDragInput and Menu.orientationDragInput.UserInputType == Enum.UserInputType.Touch and input ~= Menu.orientationDragInput then
			return
		end

		local position = Vector2.new(input.Position.X, input.Position.Y)
		local delta = position - Menu.orientationDragLast
		Menu.orientationDragLast = position
		Menu.orientationDragDistance = Menu.orientationDragDistance + delta.Magnitude
		Menu:SetOrientation(
			Menu.targetOrientationYaw + delta.X * 0.22,
			Menu.targetOrientationPitch - delta.Y * 0.18
		)
	end)
	connect(userInputService.InputEnded, function(input)
		if not Menu.orientationDragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		Menu.orientationDragging = false
		Menu.orientationDragInput = nil
		if Menu.orientationDragDistance < 4 then
			Menu:SetOrientation(0, Config.SurfaceDefaultPitch)
		end
		if exactImage.Visible then
			tween(exactImage, FAST_TWEEN, { ImageTransparency = 0 })
		else
			tween(orbitStroke, FAST_TWEEN, { Transparency = 0.5, Color = Color3.fromRGB(185, 188, 194) })
		end
	end)

	Menu.references.OrientationGizmo = root
	Menu.references.OrientationImage = exactImage
	return root
end
buildOrientationGizmo(screenGui)

function Menu:SetOrientation(yaw, pitch)
	self.targetOrientationYaw = math.clamp(tonumber(yaw) or 0, -Config.SurfaceMaxYaw, Config.SurfaceMaxYaw)
	self.targetOrientationPitch = math.clamp(
		tonumber(pitch) or Config.SurfaceDefaultPitch,
		-Config.SurfaceMaxPitch,
		Config.SurfaceMaxPitch
	)
end

local function captureCoreGuiState()
	if Menu.coreGuiCaptured then
		return
	end
	Menu.coreGuiCaptured = true

	local ok, coreTypes = pcall(function()
		return Enum.CoreGuiType:GetEnumItems()
	end)
	if ok then
		for _, coreType in ipairs(coreTypes) do
			if coreType ~= Enum.CoreGuiType.All then
				local stateOk, enabled = pcall(function()
					return starterGui:GetCoreGuiEnabled(coreType)
				end)
				if stateOk then
					Menu.coreGuiStates[coreType] = enabled
				end
			end
		end
	end

	local topbarOk, topbarEnabled = pcall(function()
		return starterGui:GetCore("TopbarEnabled")
	end)
	if topbarOk and type(topbarEnabled) == "boolean" then
		Menu.topbarWasEnabled = topbarEnabled
	end

	-- Executors can usually reach the modern RobloxGui container even when the
	-- legacy TopbarEnabled bridge is unavailable. Normal Studio clients simply
	-- fail this protected lookup and continue with the supported StarterGui APIs.
	pcall(function()
		local robloxGui = coreGuiService:FindFirstChild("RobloxGui")
		if robloxGui and robloxGui:IsA("ScreenGui") then
			Menu.robloxGui = robloxGui
			Menu.robloxGuiWasEnabled = robloxGui.Enabled
		end
	end)
end

local function setRobloxChromeHidden(hidden)
	captureCoreGuiState()
	if hidden then
		-- The modern mobile Chrome bar responds more reliably when All is disabled
		-- before individual CoreGui types and TopbarEnabled are applied.
		pcall(function()
			starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
	end
	for coreType, wasEnabled in pairs(Menu.coreGuiStates) do
		pcall(function()
			starterGui:SetCoreGuiEnabled(coreType, hidden and false or wasEnabled)
		end)
	end
	pcall(function()
		starterGui:SetCore("TopbarEnabled", hidden and false or Menu.topbarWasEnabled)
	end)
	if Menu.robloxGui then
		pcall(function()
			Menu.robloxGui.Enabled = hidden and false or Menu.robloxGuiWasEnabled
		end)
	end
end

local function setMenuEnvironment(active, instant)
	setRobloxChromeHidden(active)
	blurEffect.Enabled = true
	if instant then
		blurEffect.Size = active and Config.BlurSize or 0
	else
		tween(blurEffect, OPEN_TWEEN, { Size = active and Config.BlurSize or 0 })
	end

	if not active then
		task.delay(OPEN_TWEEN.Time + 0.03, function()
			if not Menu.destroyed and not Menu.open and blurEffect.Size <= 0.1 then
				blurEffect.Enabled = false
			end
		end)
	else
		-- Mobile Chrome can register after LocalScripts. Reapply during the short
		-- opening window, but only while this menu is still active.
		for _, retryDelay in ipairs({ 0.1, 0.35, 0.8, 1.4 }) do
			task.delay(retryDelay, function()
				if not Menu.destroyed and Menu.open then
					setRobloxChromeHidden(true)
				end
			end)
		end
	end
end

local function expApproach(current, target, speed, deltaTime)
	return current + (target - current) * (1 - math.exp(-speed * math.min(deltaTime, 0.1)))
end

-- Responsive sizing now controls world-space plane dimensions rather than flat GUI scale.
function Menu:UpdateScale()
	if self.destroyed then
		return
	end
	local camera = workspaceService.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(Config.ReferenceWidth, Config.ReferenceHeight)
	self.scale = math.clamp(math.min(viewport.X / Config.ReferenceWidth, viewport.Y / Config.ReferenceHeight), 0.62, 1.35)
end

local function placeSurface(part, canvasSize, centerX, centerY, yaw, pitch, camera, viewport)
	local depth = Config.SurfaceDepth
	local verticalWorldSize = 2 * depth * math.tan(math.rad(camera.FieldOfView * 0.5))
	local worldPerPixel = verticalWorldSize / math.max(viewport.Y, 1)
	-- Perspective expands the near edge; compressing physical width preserves
	-- the reference's readable on-screen footprint while retaining a true trapezoid.
	local width = canvasSize.X * Menu.scale * worldPerPixel * Config.SurfaceWidthCompression
	local height = canvasSize.Y * Menu.scale * worldPerPixel
	local localX = (centerX - viewport.X * 0.5) * worldPerPixel
	local localY = -(centerY - viewport.Y * 0.5) * worldPerPixel

	part.Size = Vector3.new(width, height, 0.04)
	part.CFrame = camera.CFrame
		* CFrame.new(localX, localY, -depth)
		* CFrame.Angles(math.rad(pitch), math.rad(yaw), 0)
end

local KEY_INPUT_CANVAS_BOUNDS = {
	left = 50,
	top = 60,
	width = 335,
	height = 54,
}

local function surfaceCanvasPointToViewport(part, canvasSize, x, y, camera)
	local localPoint = Vector3.new(
		(x / canvasSize.X - 0.5) * part.Size.X,
		(0.5 - y / canvasSize.Y) * part.Size.Y,
		part.Size.Z * 0.5
	)
	local worldPoint = part.CFrame:PointToWorldSpace(localPoint)
	local viewportPoint, onScreen = camera:WorldToViewportPoint(worldPoint)
	return Vector2.new(viewportPoint.X, viewportPoint.Y), onScreen and viewportPoint.Z > 0
end

local function updateKeyInputOverlay(camera)
	local keyInput = Menu.references.KeySystemInput
	if not keyInput or not keyInput.Visible then
		return
	end

	local bounds = KEY_INPUT_CANVAS_BOUNDS
	local topLeft, topLeftVisible = surfaceCanvasPointToViewport(leftPart, LEFT_CANVAS_SIZE, bounds.left, bounds.top, camera)
	local topRight, topRightVisible = surfaceCanvasPointToViewport(leftPart, LEFT_CANVAS_SIZE, bounds.left + bounds.width, bounds.top, camera)
	local bottomLeft, bottomLeftVisible = surfaceCanvasPointToViewport(leftPart, LEFT_CANVAS_SIZE, bounds.left, bounds.top + bounds.height, camera)
	local bottomRight, bottomRightVisible = surfaceCanvasPointToViewport(
		leftPart,
		LEFT_CANVAS_SIZE,
		bounds.left + bounds.width,
		bounds.top + bounds.height,
		camera
	)
	if not (topLeftVisible or topRightVisible or bottomLeftVisible or bottomRightVisible) then
		return
	end

	local centerX = (topLeft.X + topRight.X + bottomLeft.X + bottomRight.X) * 0.25
	local centerY = (topLeft.Y + topRight.Y + bottomLeft.Y + bottomRight.Y) * 0.25
	local projectedWidth = ((topRight - topLeft).Magnitude + (bottomRight - bottomLeft).Magnitude) * 0.5
	local projectedHeight = ((bottomLeft - topLeft).Magnitude + (bottomRight - topRight).Magnitude) * 0.5
	local edgeCenterLeft = (topLeft + bottomLeft) * 0.5
	local edgeCenterRight = (topRight + bottomRight) * 0.5
	local edge = edgeCenterRight - edgeCenterLeft
	local rotation = math.deg(math.atan2(edge.Y, edge.X))
	-- Back-face canvas X can project in reverse; normalize so mobile text never
	-- flips upside down while still following the bar's visible slope.
	if rotation > 90 then
		rotation = rotation - 180
	elseif rotation < -90 then
		rotation = rotation + 180
	end

	keyInput.Position = UDim2.fromOffset(centerX, centerY)
	keyInput.Size = UDim2.fromOffset(math.max(120, projectedWidth - 26), math.max(34, projectedHeight - 4))
	keyInput.Rotation = rotation
end

local function updateWorldPresentation(deltaTime)
	if Menu.destroyed then
		return
	end
	local camera = workspaceService.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return
	end
	Menu.scale = math.clamp(math.min(viewport.X / Config.ReferenceWidth, viewport.Y / Config.ReferenceHeight), 0.62, 1.35)

	Menu.openAmount = expApproach(Menu.openAmount, Menu.targetOpenAmount, 10.5, deltaTime)
	Menu.orientationYaw = expApproach(Menu.orientationYaw, Menu.targetOrientationYaw, 9, deltaTime)
	Menu.orientationPitch = expApproach(Menu.orientationPitch, Menu.targetOrientationPitch, 9, deltaTime)

	if math.abs(Menu.openAmount - Menu.targetOpenAmount) < 0.001 then
		Menu.openAmount = Menu.targetOpenAmount
	end
	local reveal = 1 - ((1 - Menu.openAmount) ^ 3)
	local leftClosedX = -LEFT_CANVAS_SIZE.X * Menu.scale * 0.58
	local leftOpenX = 210 * Menu.scale
	local rightClosedX = viewport.X + RIGHT_CANVAS_SIZE.X * Menu.scale * 0.58
	local rightOpenX = viewport.X - 193 * Menu.scale
	local leftCenterX = leftClosedX + (leftOpenX - leftClosedX) * reveal
	local rightCenterX = rightClosedX + (rightOpenX - rightClosedX) * reveal

	placeSurface(
		leftPart,
		LEFT_CANVAS_SIZE,
		leftCenterX,
		viewport.Y * 0.525,
		Config.SurfaceInwardYaw + Menu.orientationYaw,
		Menu.orientationPitch,
		camera,
		viewport
	)
	placeSurface(
		rightPart,
		RIGHT_CANVAS_SIZE,
		rightCenterX,
		viewport.Y * 0.551,
		-Config.SurfaceInwardYaw + Menu.orientationYaw,
		Menu.orientationPitch,
		camera,
		viewport
	)
	updateKeyInputOverlay(camera)

	local shouldRender = Menu.openAmount > 0.005 or Menu.targetOpenAmount > 0
	leftSurface.Enabled = shouldRender
	rightSurface.Enabled = shouldRender
	if not shouldRender then
		Menu.references.OrientationGizmo.Visible = false
	end
end

connect(runService.RenderStepped, updateWorldPresentation)

function Menu:SetOpen(shouldOpen, instant)
	if self.destroyed then
		return
	end

	shouldOpen = shouldOpen == true
	self.open = shouldOpen
	self.targetOpenAmount = shouldOpen and 1 or 0

	if shouldOpen then
		leftSurface.Enabled = true
		rightSurface.Enabled = true
		self.references.OrientationGizmo.Visible = true
	else
		self.orientationDragging = false
		self.orientationDragInput = nil
	end
	if not shouldOpen and self.references.KeySystemInput and self.references.KeySystemInput.Visible then
		self.references.KeySystemInput:ReleaseFocus()
		self.references.KeySystemInput.Visible = false
		self.references.KeySystemButton.Visible = true
		self.references.KeySystemLabel.Visible = true
	end

	if instant then
		self.openAmount = self.targetOpenAmount
		updateWorldPresentation(0)
	end
	setMenuEnvironment(shouldOpen, instant == true)
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

function Menu:CopyKeyLink()
	local copied = false
	if clipboardWriter then
		copied = pcall(clipboardWriter, KEY_LINK_TEXT)
	end

	local hotkey = self.hotkeys.X
	if hotkey then
		hotkey.value.Text = copied and "Copied!" or "Zenith.com"
		hotkey.value.TextColor3 = copied and Config.White or Config.Secondary
		task.delay(0.9, function()
			if not Menu.destroyed and hotkey.value.Parent then
				hotkey.value.Text = "Key Link"
				hotkey.value.TextColor3 = Config.White
			end
		end)
	end
	return copied
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

-- RightShift always toggles the complete presentation, even while the key box is focused.
connect(userInputService.InputBegan, function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.RightShift then
		Menu:Toggle()
		return
	end
	if gameProcessed or userInputService:GetFocusedTextBox() then
		return
	end

	if input.KeyCode == Enum.KeyCode.Z then
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
		Menu:CopyKeyLink()
		local callback = Menu.callbacks.KeyLink or Menu.callbacks.X
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

	if self.references.KeySystemInput and self.references.KeySystemInput:IsFocused() then
		self.references.KeySystemInput:ReleaseFocus()
	end
	if self.coreGuiCaptured then
		setRobloxChromeHidden(false)
	end
	self.destroyed = true

	for _, connection in ipairs(self.connections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(self.connections)

	for _, referenceName in ipairs({ "ScreenGui", "LeftSurface", "RightSurface", "SurfaceFolder", "BlurEffect" }) do
		local object = self.references[referenceName]
		if object and object.Parent then
			object:Destroy()
		end
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
