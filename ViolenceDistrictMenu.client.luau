-- Zenith | Violence District — standalone client-side menu preview.
-- The catalog below is display data. No game module is loaded or invoked.
local function toggle(name, on) return {kind="toggle", name=name, value=on == true} end
local function slider(name, low, high, value, digits)
	return {kind="slider", name=name, low=low, high=high, value=value, digits=digits or 0}
end
local function choice(name, options) return {kind="choice", name=name, options=options, value=options[1]} end
local function color(name, hex) return {kind="color", name=name, value=hex} end
local function bind(name) return {kind="bind", name=name, value="None"} end
local function action(name, command) return {kind="action", name=name, command=command} end
local function section(column, name, family, rows)
	return {column=column, name=name, family=family, rows=rows}
end

local PAGES = {
	{name="Main", sections={
		section(1, "Offense", "Killer", {
			toggle("Burst Attack"), toggle("Instant Kill (carry+hook)"), toggle("Auto Kill"),
			slider("Auto Kill Delay", 0.05, 1, 0.15, 2), slider("Kill Range", 1, 80, 12),
		}),
		section(1, "Protection", "Killer", {
			toggle("Anti Blind"), toggle("No Pallet Stun"), toggle("No Slowdown"),
		}),
		section(2, "Actions", "Survivor", {
			toggle("Auto Perfect (skill check)"), choice("Auto Perfect Mode", {"Legit", "Perfect"}),
			toggle("Fast Vault"), toggle("No Slowdown"), toggle("Auto Escape"), toggle("Auto Parry"), toggle("No Fall Damage"),
		}),
		section(2, "Evasion", "Survivor", {
			toggle("Auto Dodge"), toggle("Pathfinding (avoid walls)", true), toggle("Show Dodge Path"), toggle("Always Probe Paths"),
			slider("Dodge Distance", 2, 24, 14), slider("Panic Distance", 6, 40, 26),
		}),
	}},
	{name="Extra", sections={
		section(1, "Quick Teleport", "Travel", {
			action("Nearest Generator"), action("Nearest Exit Gate"), action("Nearest Hook"),
		}),
		section(1, "Aimbot", "Aim", {
			toggle("Aimbot"), toggle("Always Active"), toggle("Movement Prediction"), toggle("Visible FOV"),
		}),
		section(1, "Tuning", "Aim", {
			slider("Aim FOV", 10, 360, 90), slider("Aim Smoothness", 0, 1, 0.25, 2), choice("Target Part", {"Head", "Torso", "Root"}),
		}),
		section(2, "Speed", "Movement", {
			toggle("Walk Speed"), slider("Speed Value", 16, 256, 32), choice("Speed Method", {"WalkSpeed", "Velocity"}),
			bind("Walk Speed Bind"), toggle("Noclip"), bind("Noclip Bind"),
		}),
		section(2, "Air", "Movement", {toggle("Fly"), slider("Fly Speed", 10, 260, 60), bind("Fly Bind")}),
		section(2, "Jump", "Movement", {toggle("Jump Power (+ unlock)"), slider("Jump Value", 50, 250, 60), toggle("Infinite Jump")}),
	}},
	{name="Visual", sections={
		section(1, "Player ESP", "Visual", {
			toggle("Survivor ESP"), toggle("Killer ESP"), toggle("Box ESP (windows)"), toggle("SCP ESP"),
			toggle("Name Tags"), toggle("Distance Labels"),
			color("Survivor Color", "00C8FF"), color("Killer Color", "FF2828"), color("SCP Color", "C800FF"),
		}),
		section(2, "Object ESP", "Visual", {
			toggle("Generator ESP"), toggle("Hook ESP"), toggle("Nearest Hook Only"), toggle("Pallet ESP"),
			toggle("Window ESP"), toggle("Exit Gate ESP"), color("Window Color", "FF00FF"), slider("ESP Max Distance", 0, 5000, 1000),
		}),
	}},
	{name="Config", sections={
		section(1, "Settings", "Session", {
			action("Save Settings", "save"), action("Load Settings", "load"), action("Reset Settings", "reset"),
			action("Copy Settings", "copy"), toggle("Auto Save"),
		}),
		section(2, "Interface", "Menu", {
			choice("Menu Keybind", {"RightShift", "Insert", "RightControl", "Delete", "End"}),
			action("Reset Window", "center"), action("Unload GUI", "close"),
		}),
	}},
}

local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Tweens = game:GetService("TweenService")
local JSON = game:GetService("HttpService") -- local JSON encoding for the selectable settings text
local TITLE_TEXT = "Zenith | Violence District"
local GUI_NAME = "ViolenceDistrictMenuPreview"
local TITLE_HEIGHT, TAB_HEIGHT, FOOT_HEIGHT = 40, 34, 29
local WIDTH, HEIGHT = 656, 574
local COMPACT = 500
local AUTO_ID = "Config/Settings/Auto Save"
local KEY_ID = "Config/Interface/Menu Keybind"
local PALETTE = {"00C8FF", "FF2828", "C800FF", "FF00FF", "56D6A0", "FFBA60", "788CFF", "F0F0F2"}

-- The supplied template's silver accents, gradient window, cards and tab underline.
local rgb = Color3.fromRGB
local WHITE, ACCENT_A, ACCENT_B = rgb(255,255,255), rgb(225,225,225), rgb(110,110,116)
local TOP, BOTTOM, PANEL, ROW, ELEMENT = rgb(25,25,27), rgb(9,9,10), rgb(22,22,24), rgb(34,34,36), rgb(17,17,19)
local TEXT, OFF_TEXT, DIM = rgb(238,238,238), rgb(192,192,196), rgb(147,147,154)
local NORMAL, BOLD = Enum.Font.SourceSans, Enum.Font.SourceSansBold
local FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLIDE = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local off, dim, scale = UDim2.fromOffset, UDim2.new, UDim2.fromScale

local function create(kind, properties, parent)
	local object = Instance.new(kind)
	if object:IsA("GuiObject") then object.BorderSizePixel = 0 end
	for key, value in properties do object[key] = value end
	object.Parent = parent
	return object
end
local function tween(object, info, goal)
	local t = Tweens:Create(object, info, goal); t:Play(); return t
end
local function corner(object, radius)
	return create("UICorner", {CornerRadius=UDim.new(0,radius)}, object)
end
local function stroke(object, tint, transparency, thickness)
	return create("UIStroke", {Color=tint, Transparency=transparency, Thickness=thickness or 1,
		ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, object)
end
local function gradient(object, a, b, rotation)
	return create("UIGradient", {Color=ColorSequence.new(a,b), Rotation=rotation}, object)
end
local function frame(parent, name, size, pos, tint)
	return create("Frame", {Name=name, Size=size, Position=pos or off(0,0),
		BackgroundTransparency=tint and 0 or 1, BackgroundColor3=tint or WHITE}, parent)
end
local function button(parent, name, size, pos)
	return create("TextButton", {Name=name, Size=size, Position=pos or off(0,0), Text="",
		AutoButtonColor=false, BackgroundTransparency=1}, parent)
end
local function label(parent, text, size, pos, fontSize, tint, bold, align)
	return create("TextLabel", {Name="Label", Size=size, Position=pos or off(0,0), BackgroundTransparency=1,
		Text=text, TextColor3=tint or TEXT, TextSize=fontSize or 14, Font=bold and BOLD or NORMAL,
		TextXAlignment=align or Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd}, parent)
end
local CENTER, RIGHT = Enum.TextXAlignment.Center, Enum.TextXAlignment.Right
local function hover(object, normalAlpha, hoverAlpha)
	object.BackgroundTransparency = normalAlpha
	object.MouseEnter:Connect(function() tween(object,FAST,{BackgroundTransparency=hoverAlpha}) end)
	object.MouseLeave:Connect(function() tween(object,FAST,{BackgroundTransparency=normalAlpha}) end)
end
local function list(parent, spacing)
	return create("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,spacing)}, parent)
end
local function padding(parent, left, right, top, bottom)
	create("UIPadding", {PaddingLeft=UDim.new(0,left), PaddingRight=UDim.new(0,right),
		PaddingTop=UDim.new(0,top), PaddingBottom=UDim.new(0,bottom)}, parent)
end
local function isPress(input)
	return input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch
end

local gui
local function initialize()
	local parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = parent:FindFirstChild(GUI_NAME)
	if old and old:IsA("ScreenGui") and old:GetAttribute("VDMenuPreview") then old:Destroy() end
	gui = create("ScreenGui", {Name=GUI_NAME, ResetOnSpawn=false, AutoLocalize=false, IgnoreGuiInset=true,
		DisplayOrder=20, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, parent)
	gui:SetAttribute("VDMenuPreview",true)
	local external, pages, values, defaults, painters = {}, {}, {}, {}, {}
	local selected, saved, capture, gesture, modal
	local closed, minimized, closing = false, false, false
	local function listen(signal, callback) table.insert(external,signal:Connect(callback)) end
	gui.Destroying:Connect(function()
		closed=true; gesture=nil; capture=nil
		for _,connection in external do connection:Disconnect() end
		table.clear(external)
	end)

	local stage = frame(gui,"Stage",scale(1,1))
	local window = frame(stage,"Window",off(WIDTH,HEIGHT),dim(0.5,-WIDTH/2,0.5,-HEIGHT/2),WHITE)
	window.ClipsDescendants=true; window.Active=true; corner(window,9)
	gradient(window,TOP,BOTTOM,90); gradient(stroke(window,WHITE,0.38,1.2),ACCENT_A,ACCENT_B,45)
	local windowScale = create("UIScale",{Scale=0.96},window); tween(windowScale,POP,{Scale=1})
	local sheen = frame(window,"Sheen",dim(1,0,0,130),nil,WHITE); gradient(sheen,WHITE,WHITE,90).Transparency=NumberSequence.new(0.968,1)
	local title = frame(window,"TitleBar",dim(1,0,0,TITLE_HEIGHT),nil,WHITE)
	gradient(title,ACCENT_A,ACCENT_B,0).Transparency=NumberSequence.new(0.87,0.97)
	local rule=frame(title,"Rule",dim(1,0,0,1),dim(0,0,1,-1),WHITE); rule.BackgroundTransparency=0.91
	local drag = button(title,"DragWindow",dim(1,-220,1,0)); drag.Selectable=false
	local emblem=frame(drag,"Monogram",off(25,25),dim(0,11,0.5,-12),WHITE); corner(emblem,6); gradient(emblem,ACCENT_A,ACCENT_B,55)
	label(emblem,"VD",scale(1,1),nil,13,ELEMENT,true,CENTER)
	local heading=label(drag,TITLE_TEXT,dim(1,-47,1,0),off(45,0),16,TEXT,true)
	heading.TextTruncate=Enum.TextTruncate.None; heading.TextScaled=true
	create("UITextSizeConstraint",{MinTextSize=10,MaxTextSize=16},heading)
	local search = create("TextBox",{Name="Search", Size=off(135,24), Position=dim(1,-209,0.5,-12),
		Text="", PlaceholderText="Search this tab", TextSize=13, Font=NORMAL, TextColor3=TEXT,
		PlaceholderColor3=DIM, ClearTextOnFocus=false, BackgroundColor3=ELEMENT, TextXAlignment=Enum.TextXAlignment.Left},title)
	corner(search,5); padding(search,8,5,0,0)
	local searchStroke=stroke(search,ACCENT_A,0.87)
	search.Focused:Connect(function() tween(searchStroke,FAST,{Transparency=0.3}) end)
	search.FocusLost:Connect(function() tween(searchStroke,FAST,{Transparency=0.87}) end)
	local function titleButton(text, x, name, hot)
		local b=button(title,name,off(25,24),dim(1,x,0.5,-12)); b.BackgroundColor3=ELEMENT
		corner(b,5); hover(b,0.4,0.1); label(b,text,scale(1,1),nil,16,TEXT,true,CENTER)
		if hot then
			b.MouseEnter:Connect(function() tween(b,FAST,{BackgroundColor3=hot}) end)
			b.MouseLeave:Connect(function() tween(b,FAST,{BackgroundColor3=ELEMENT}) end)
		end
		return b
	end
	local minimize=titleButton("−",-62,"Minimize"); local close=titleButton("×",-32,"Close",rgb(152,57,64))
	local tabs=frame(window,"Tabs",dim(1,-12,0,TAB_HEIGHT),off(6,TITLE_HEIGHT))
	local indicator=frame(tabs,"Indicator",dim(1/#PAGES,-8,1,-6),off(4,3),WHITE)
	indicator.BackgroundTransparency=0.92; corner(indicator,5); stroke(indicator,WHITE,0.86)
	local underline=frame(indicator,"Underline",dim(0.48,0,0,2),dim(0.26,0,1,-2),WHITE)
	corner(underline,2); gradient(underline,ACCENT_A,ACCENT_B,0)
	local top=TITLE_HEIGHT+TAB_HEIGHT+6
	local content=frame(window,"Pages",dim(1,-18,1,-(top+FOOT_HEIGHT+3)),off(9,top))
	local footer=frame(window,"Footer",dim(1,0,0,FOOT_HEIGHT),dim(0,0,1,-FOOT_HEIGHT))
	frame(footer,"Rule",dim(1,-20,0,1),off(10,0),WHITE).BackgroundTransparency=0.92
	local badge=frame(footer,"PreviewBadge",off(59,16),off(12,7),ROW); corner(badge,4); stroke(badge,ACCENT_B,0.68)
	label(badge,"PREVIEW",scale(1,1),nil,10,OFF_TEXT,true,CENTER)
	local status=label(footer,"",dim(1,-235,1,0),off(79,1),12,DIM)
	local shortcut=label(footer,"",off(124,FOOT_HEIGHT),dim(1,-151,0,1),12,DIM,false,RIGHT)
	local function updateShortcut()
		shortcut.Text=Input.TouchEnabled and not Input.KeyboardEnabled and "Tap − to minimize" or ((values[KEY_ID] or "RightShift").."  ·  Hide")
	end
	local grip=button(footer,"Resize",off(22,23),dim(1,-24,1,-24))
	for i=1,3 do frame(grip,"GripLine",off(i*3,1),off(18-i*3,7+i*3),DIM) end

	local stamp=0
	local function defaultStatus()
		return selected=="Config" and "Settings last for this session" or ((selected or "Main").."  /  Interface only")
	end
	local function notice(text)
		stamp+=1; local current=stamp; status.Text=text; status.TextColor3=TEXT
		task.delay(2.4,function()
			if not closed and stamp==current then status.Text=defaultStatus(); status.TextColor3=DIM end
		end)
	end
	local function dismiss()
		if modal then modal:Destroy(); modal=nil end
	end
	local function stopCapture()
		if capture then local id=capture; capture=nil; painters[id](values[id],false) end
	end
	local function stopDrag()
		local oldDrag=gesture; gesture=nil
		if oldDrag and oldDrag.finish then oldDrag.finish() end
	end
	local function track(input,move,finish)
		stopDrag(); gesture={input=input, touch=input.UserInputType==Enum.UserInputType.Touch, move=move, finish=finish}
	end
	listen(Input.InputChanged,function(input)
		if gesture and ((gesture.touch and gesture.input==input) or (not gesture.touch and input.UserInputType==Enum.UserInputType.MouseMovement)) then
			gesture.move(input.Position)
		end
	end)
	listen(Input.InputEnded,function(input)
		if gesture and (input==gesture.input or not gesture.touch and input.UserInputType==Enum.UserInputType.MouseButton1) then stopDrag() end
	end)
	listen(Input.WindowFocusReleased,function() stopDrag(); stopCapture() end)
	local function destroy()
		if closing then return end; closing=true; stopCapture(); stopDrag(); dismiss()
		tween(windowScale,FAST,{Scale=0.92}).Completed:Once(function() if not closed then gui:Destroy() end end)
	end
	close.Activated:Connect(destroy)

	local width,height,x,y=WIDTH,HEIGHT,0,0
	local positioned, compact=false,nil
	local function fit(center)
		local room=stage.AbsoluteSize
		if room.X<1 or room.Y<1 then return end
		local maxW,maxH=math.max(1,math.min(860,room.X-12)), math.max(1,math.min(830,room.Y-12))
		width=math.clamp(width,math.min(340,maxW),maxW); height=math.clamp(height,math.min(270,maxH),maxH)
		local shown=minimized and TITLE_HEIGHT or height
		if center or not positioned then x,y=(room.X-width)/2,(room.Y-shown)/2; positioned=true end
		x=math.clamp(x,0,math.max(0,room.X-width)); y=math.clamp(y,0,math.max(0,room.Y-shown))
		window.Size=off(width,shown); window.Position=off(x,y)
		local narrow=width<COMPACT
		emblem.Visible=not narrow
		local inset=narrow and 10 or 45
		heading.Position=off(inset,0); heading.Size=dim(1,-inset-2,1,0)
		local searchW=narrow and math.clamp(width-270,50,93) or 135
		search.PlaceholderText=narrow and "Search" or "Search this tab"
		search.Size=off(searchW,24); search.Position=dim(1,-searchW-74,0.5,-12)
		drag.Size=dim(1,minimized and -70 or -searchW-81,1,0)
		if compact~=narrow then
			compact=narrow
			for _,page in pages do
				page.left.Size=narrow and scale(1,1) or dim(0.5,-4,1,0); page.right.Visible=not narrow
				for _,group in page.groups do group.box.Parent=(not narrow and group.spec.column==2) and page.right or page.left end
			end
		end
	end
	drag.InputBegan:Connect(function(input)
		if not isPress(input) or closing then return end
		local start,x0,y0=input.Position,x,y
		track(input,function(p) x=x0+p.X-start.X; y=y0+p.Y-start.Y; fit(false) end)
	end)
	grip.InputBegan:Connect(function(input)
		if not isPress(input) or minimized or closing then return end
		local start,w,h=input.Position,width,height
		track(input,function(p) width=w+p.X-start.X; height=h+p.Y-start.Y; fit(false) end)
	end)
	local function showBody(show)
		minimized=not show; tabs.Visible=show; content.Visible=show; footer.Visible=show
		minimize.Label.Text=show and "−" or "+"; search.Visible=show; search:ReleaseFocus(); stopCapture(); dismiss(); fit(false)
	end
	minimize.Activated:Connect(function() showBody(minimized) end)
	stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() fit(false) end)

	local function dialog(titleText, dialogHeight)
		dismiss(); stopCapture(); stopDrag()
		modal=frame(window,"Dialog",scale(1,1),nil,BOTTOM); modal.ZIndex=10; modal.BackgroundTransparency=0.32
		local backdrop=button(modal,"Backdrop",scale(1,1)); backdrop.Selectable=false
		local sheet=frame(modal,titleText,off(math.max(100,math.min(310,width-24)),math.min(dialogHeight,height-12)),scale(0.5,0.5),PANEL)
		sheet.AnchorPoint=Vector2.new(0.5,0.5); sheet.ZIndex=2; sheet.Active=true
		corner(sheet,8); stroke(sheet,ACCENT_B,0.3)
		label(sheet,titleText,dim(1,-50,0,34),off(12,0),15,TEXT,true)
		local cancel=button(sheet,"Dismiss",off(30,30),dim(1,-34,0,2)); label(cancel,"×",scale(1,1),nil,18,DIM,false,CENTER)
		cancel.Activated:Connect(dismiss); backdrop.Activated:Connect(dismiss)
		return sheet
	end
	local function register(id, spec, paint)
		defaults[id]=spec.value; values[id]=spec.value; painters[id]=paint; paint(spec.value,false)
	end
	local function set(id,value,animate)
		values[id]=value; painters[id](value,animate~=false)
		updateShortcut()
		if values[AUTO_ID] then saved=table.clone(values) end
	end
	local function restore(snapshot)
		stopCapture()
		for id,paint in painters do values[id]=snapshot[id]; paint(values[id],false) end
		updateShortcut()
	end
	local function configCommand(command)
		if command=="save" then saved=table.clone(values); notice("Settings saved for this session")
		elseif command=="load" then
			if saved then restore(saved); notice("Session settings loaded") else notice("Save a settings snapshot first") end
		elseif command=="reset" then restore(defaults); notice("Preview defaults restored")
		elseif command=="center" then width,height=WIDTH,HEIGHT; showBody(true); fit(true); notice("Window reset")
		elseif command=="close" then destroy()
		elseif command=="copy" then
			local sheet=dialog("Copy settings",142)
			label(sheet,"Press Ctrl+C or ⌘C to copy the selected text.",dim(1,-24,0,20),off(12,33),13,DIM)
			local text=create("TextBox",{Name="SettingsText", Size=dim(1,-24,1,-69), Position=off(12,57),
				Text=JSON:JSONEncode(values), ClearTextOnFocus=false, MultiLine=true, TextWrapped=true, ClipsDescendants=true,
				TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, Font=Enum.Font.Code, TextSize=12,
				TextColor3=TEXT, BackgroundColor3=ELEMENT},sheet)
			corner(text,4); padding(text,5,5,3,3); text:CaptureFocus(); text.CursorPosition=#text.Text+1; text.SelectionStart=1
		end
	end

	local function createColumn(page,name,pos)
		local column=create("ScrollingFrame",{Name=name, Position=pos, Size=dim(0.5,-4,1,0), Active=true,
			CanvasSize=off(0,0), ScrollingDirection=Enum.ScrollingDirection.Y, BackgroundTransparency=1,
			ScrollBarThickness=3, ScrollBarImageColor3=ACCENT_A, ScrollBarImageTransparency=0.55},page)
		local layout=list(column,8); padding(column,2,6,2,4)
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() column.CanvasSize=off(0,layout.AbsoluteContentSize.Y+6) end)
		return column
	end
	local function filter(page)
		local q=search.Text:lower():match("^%s*(.-)%s*$"); local count=0
		for _,group in page.groups do
			local groupMatch=group.title:find(q,1,true)~=nil; local found=0
			for _,row in group.rows do
				local match=groupMatch or row.key:find(q,1,true)~=nil
				row.object.Visible=match and (q~="" or not group.folded)
				if match then found+=1 end
			end
			group.box.Visible=found>0; group.arrow.Text=(q~="" or not group.folded) and "▾" or "▸"; count+=found
		end
		page.empty.Visible=count==0
	end
	local function selectTab(page)
		stopCapture(); stopDrag(); dismiss(); selected=page.name; stamp+=1
		for _,other in pages do
			local chosen=other==page; other.body.Visible=chosen
			tween(other.tabLabel,FAST,{TextColor3=chosen and TEXT or DIM})
		end
		filter(page); page.body.GroupTransparency=0.65; tween(page.body,SLIDE,{GroupTransparency=0})
		tween(indicator,SLIDE,{Position=dim((page.index-1)/#PAGES,4,0,3)})
		status.Text=defaultStatus(); status.TextColor3=DIM
	end
	local function createSection(page,spec,order)
		local parentColumn=spec.column==1 and page.left or page.right
		local box=frame(parentColumn,spec.name,dim(1,0,0,0),nil,PANEL)
		box.AutomaticSize=Enum.AutomaticSize.Y; box.BackgroundTransparency=0.12; box.LayoutOrder=order
		corner(box,8); stroke(box,rgb(105,105,110),0.64); gradient(box,WHITE,rgb(186,186,191),90)
		padding(box,6,6,4,6); list(box,3)
		local header=button(box,"SectionHeader",dim(1,0,0,28))
		local marker=frame(header,"Marker",off(3,11),dim(0,3,0.5,-6),WHITE); corner(marker,2); gradient(marker,ACCENT_A,ACCENT_B,90)
		label(header,spec.name:upper(),dim(1,-98,1,-2),off(12,0),12,ACCENT_A,true)
		label(header,spec.family:upper(),off(74,25),dim(1,-98,0,0),10,DIM,false,RIGHT)
		local arrow=label(header,"▾",off(18,25),dim(1,-19,0,0),13,OFF_TEXT,true,CENTER)
		local line=frame(header,"Divider",dim(1,0,0,1),dim(0,0,1,-1),WHITE)
		gradient(line,ACCENT_A,ACCENT_B,0).Transparency=NumberSequence.new(0.74,0.98)
		local group={box=box, arrow=arrow, spec=spec, title=(spec.family.." "..spec.name):lower(), rows={}, folded=false}
		table.insert(page.groups,group)
		header.Activated:Connect(function()
			if search.Text:match("%S") then return end
			stopCapture(); group.folded=not group.folded; filter(page)
		end)
		return group
	end
	local function addRow(page,group,spec,order)
		local kind,name=spec.kind,spec.name
		local id=page.name.."/"..group.spec.name.."/"..name
		local row=button(group.box,name,dim(1,0,0,kind=="slider" and 44 or 29))
		row.LayoutOrder=order; row.BackgroundColor3=ROW; corner(row,5); hover(row,0.65,0.30)
		table.insert(group.rows,{object=row,key=name:lower()})
		if kind=="toggle" then
			local box=frame(row,"Checkbox",off(15,15),dim(0,8,0.5,-7.5),ELEMENT); corner(box,4)
			local outline=stroke(box,DIM,0.48); local check=frame(box,"Check",off(0,0),scale(0.5,0.5),WHITE)
			check.AnchorPoint=Vector2.new(0.5,0.5); corner(check,2); gradient(check,ACCENT_A,ACCENT_B,45)
			local caption=label(row,name,dim(1,-39,1,0),off(32,0),14,OFF_TEXT)
			local bar=frame(row,"ActiveMark",dim(0,2,1,-12),off(0,6),WHITE); corner(bar,1); gradient(bar,ACCENT_A,ACCENT_B,90)
			local checkTween
			register(id,spec,function(on,animated)
				if checkTween then checkTween:Cancel(); checkTween=nil end
				local target=on and off(9,9) or off(0,0)
				if animated then checkTween=tween(check,POP,{Size=target}) else check.Size=target end
				bar.Visible=on; caption.TextColor3=on and TEXT or OFF_TEXT
				outline.Color=on and ACCENT_A or DIM; outline.Transparency=on and 0.1 or 0.48
			end)
			row.Activated:Connect(function() set(id,not values[id]) end)
		elseif kind=="slider" then
			label(row,name,dim(1,-68,0,21),off(9,2),13,OFF_TEXT)
			local valueLabel=label(row,"",off(54,21),dim(1,-64,0,2),13,TEXT,true,RIGHT)
			local trackBar=frame(row,"Track",dim(1,-24,0,4),off(12,30),ELEMENT); corner(trackBar,4); stroke(trackBar,WHITE,0.87)
			local fill=frame(trackBar,"Fill",scale(0,1),nil,WHITE); corner(fill,4); gradient(fill,ACCENT_B,ACCENT_A,0)
			local knob=frame(trackBar,"Knob",off(10,10),scale(0,0.5),WHITE); knob.AnchorPoint=Vector2.new(0.5,0.5); corner(knob,5)
			local knobScale=create("UIScale",{},knob)
			register(id,spec,function(value)
				local alpha=(value-spec.low)/(spec.high-spec.low)
				fill.Size=scale(alpha,1); knob.Position=scale(alpha,0.5); valueLabel.Text=string.format("%."..spec.digits.."f",value)
			end)
			local function scrub(p)
				local alpha=math.clamp((p.X-trackBar.AbsolutePosition.X)/math.max(1,trackBar.AbsoluteSize.X),0,1)
				local pow=10^spec.digits; local v=math.round((spec.low+(spec.high-spec.low)*alpha)*pow)/pow
				if values[id]~=v then set(id,v,false) end
			end
			local hit=button(row,"Scrub",dim(1,-10,0,20),off(5,23))
			hit.InputBegan:Connect(function(input)
				if not isPress(input) then return end
				local column=group.box.Parent
				track(input,scrub,function() column.ScrollingEnabled=true; tween(knobScale,FAST,{Scale=1}) end)
				column.ScrollingEnabled=false; tween(knobScale,FAST,{Scale=1.26}); scrub(input.Position)
			end)
		elseif kind=="action" then
			label(row,name,dim(1,-40,1,0),off(10,0),14,OFF_TEXT); label(row,"›",off(20,29),dim(1,-26,0,0),19,DIM,false,RIGHT)
			row.Activated:Connect(function()
				if page.name=="Config" then configCommand(spec.command) else notice(name.."  ·  Preview only") end
			end)
		elseif kind=="color" then
			label(row,name,dim(1,-102,1,0),off(10,0),14,OFF_TEXT)
			local hex=label(row,"",off(61,29),dim(1,-97,0,0),12,DIM,false,RIGHT)
			local chip=frame(row,"Swatch",off(19,19),dim(1,-28,0.5,-9.5),WHITE); corner(chip,5); stroke(chip,WHITE,0.8)
			register(id,spec,function(v) hex.Text="#"..v; chip.BackgroundColor3=Color3.fromHex(v) end)
			row.Activated:Connect(function()
				local sheet=dialog(name,136)
				for i,v in PALETTE do
					local sw=button(sheet,"#"..v,dim(0.25,-9,0,38),dim(((i-1)%4)*0.25,6,0,40+math.floor((i-1)/4)*44))
					sw.BackgroundColor3=Color3.fromHex(v); sw.BackgroundTransparency=0; corner(sw,5)
					if v==values[id] then stroke(sw,WHITE,0,2); label(sw,"✓",scale(1,1),nil,18,ELEMENT,true,CENTER) end
					sw.Activated:Connect(function() set(id,v); dismiss() end)
				end
			end)
		else
			label(row,name,dim(1,-108,1,0),off(10,0),14,OFF_TEXT)
			local value=label(row,"",off(91,29),dim(1,-101,0,0),13,TEXT,true,RIGHT)
			register(id,spec,function(v)
				if kind=="bind" then value.Text=capture==id and "Press a key…" or ("["..v.."]")
				else value.Text=v.."   ›" end
			end)
			row.Activated:Connect(function()
				stopCapture()
				if kind=="bind" then capture=id; painters[id](values[id]); notice("Press a key · Esc clears")
				else set(id,spec.options[table.find(spec.options,values[id])%#spec.options+1]) end
			end)
		end
	end

	for i,spec in PAGES do
		local tab=button(tabs,spec.name,scale(1/#PAGES,1),scale((i-1)/#PAGES,0))
		local body=create("CanvasGroup",{Name=spec.name, Size=scale(1,1), BackgroundTransparency=1, Visible=false},content)
		local page={name=spec.name,index=i,body=body,groups={},tabLabel=label(tab,spec.name,scale(1,1),nil,14,DIM,true,CENTER)}
		pages[spec.name]=page
		page.left=createColumn(body,"Left",off(0,0)); page.right=createColumn(body,"Right",dim(0.5,4,0,0))
		page.empty=label(body,"No matching controls on this tab.",dim(1,0,0,42),off(0,12),14,DIM,false,CENTER); page.empty.Visible=false
		for order,s in spec.sections do
			local group=createSection(page,s,order)
			for rowIndex,row in s.rows do addRow(page,group,row,rowIndex) end
		end
		tab.Activated:Connect(function() selectTab(page) end)
	end
	search.Focused:Connect(stopCapture)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		for _,page in pages do filter(page); page.left.CanvasPosition=Vector2.zero; page.right.CanvasPosition=Vector2.zero end
	end)
	listen(Input.InputBegan,function(input,processed)
		if closing then return end
		if isPress(input) then stopCapture(); return end
		if input.UserInputType~=Enum.UserInputType.Keyboard then return end
		if modal then if input.KeyCode==Enum.KeyCode.Escape then dismiss() end; return end
		if Input:GetFocusedTextBox() then return end
		if capture then
			local id=capture; capture=nil; set(id,input.KeyCode==Enum.KeyCode.Escape and "None" or input.KeyCode.Name); notice("Preview binding updated"); return
		end
		if not processed and input.KeyCode.Name==values[KEY_ID] then gui.Enabled=not gui.Enabled; stopDrag() end
	end)
	updateShortcut(); fit(true); selectTab(pages.Main)
end

local ok, err=xpcall(initialize,debug.traceback)
if not ok then if gui then gui:Destroy() end; warn("["..TITLE_TEXT.."] "..tostring(err)) end
