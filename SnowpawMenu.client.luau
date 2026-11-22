-- Snowpaw / Field Console. Standalone client UI; selections never affect the game.
-- Both mascot pictures are embedded below. No asset IDs, downloads or file APIs required.
local off, ud = UDim2.fromOffset, UDim2.new
local full = UDim2.fromScale(1,1)
local hex = Color3.fromHex
local C = {base=hex("131A20"), rail=hex("10171C"), panel=hex("192229"), edge=hex("2C3942"),
	bright=hex("ECF3F7"), muted=hex("A8B7C1"), dim=hex("8DA0AE"), tile=hex("26323A"), mint=hex("A3D4BC")}
local sans,bold,mono = Enum.Font.Gotham,Enum.Font.GothamBold,Enum.Font.Code
local function new(class, parent, props)
	local o=Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel=0 end
	for k,v in props do o[k]=v end
	o.Parent=parent
	return o
end
local function place(o,x,y,w,h) o.Position=off(x,y); o.Size=off(math.max(w,0),math.max(h,0)) end
local function round(o,r) return new("UICorner",o,{CornerRadius=UDim.new(0,r)}) end
local function outline(o,color,thick) return new("UIStroke",o,{Color=color,Thickness=thick or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function frame(parent,name,color,r,class)
	local o=new(class or "Frame",parent,{Name=name,BackgroundColor3=color or C.base,BackgroundTransparency=color and 0 or 1,Size=off(0,0)})
	if r then round(o,r) end
	return o
end
local function box(parent,name,color,r)
	local o=new("TextButton",parent,{Name=name,Text="",AutoButtonColor=false,BackgroundTransparency=color and 0 or 1,BackgroundColor3=color or C.base,Size=off(0,0)})
	if r then round(o,r) end
	return o
end
local function text(parent,name,value,size,font,tint,align)
	return new("TextLabel",parent,{Name=name,Text=value,TextSize=size,Font=font,TextColor3=tint,TextXAlignment=align or Enum.TextXAlignment.Left,
		TextTruncate=Enum.TextTruncate.AtEnd,BackgroundTransparency=1,Size=off(0,0)})
end
local center,right=Enum.TextXAlignment.Center,Enum.TextXAlignment.Right
local function dot(parent,name,colour,size)
	local o=frame(parent,name,colour,100);o.Size=off(size,size);return o
end
local function rgbParts(s) return tonumber(s:sub(1,2),16),tonumber(s:sub(3,4),16),tonumber(s:sub(5,6),16) end
local function mix(s,t,k)
	local a,b,c=rgbParts(s);local x,y,z=rgbParts(t)
	return Color3.fromRGB(math.round(a+(x-a)*k),math.round(b+(y-b)*k),math.round(c+(z-c)*k))
end

-- Decode the local indexed rasters. If EditableImage is disallowed in the place,
-- draw the same pixels as static gradient strips instead of showing an empty decal.
local function decode64(s,n)
	local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"; local key={}
	for i=1,64 do key[alphabet:byte(i)]=i-1 end
	local out=table.create(math.ceil(n/3))
	for i=1,#s,4 do
		local a,b,c,d=s:byte(i,i+3); a,b,c,d=key[a],key[b],key[c] or 0,key[d] or 0
		out[(i+3)/4]=string.char(a*4+math.floor(b/16),(b%16)*16+math.floor(c/4),(c%4)*64+d)
	end
	return table.concat(out):sub(1,n)
end
local function picture(holder,asset,owned,small)
	local colours,packed={},{}; local w,h=asset.w,asset.h
	for i=1,#asset.palette,6 do
		local s=asset.palette:sub(i,i+5); local r,g,b=rgbParts(s)
		table.insert(colours,hex(s)); table.insert(packed,r+g*256+b*65536+4278190080)
	end
	local pixels=decode64(asset.data,w*h);local edit,display
	local ok=pcall(function()
		local size=Vector2.new(w,h)
		edit=assert(game:GetService("AssetService"):CreateEditableImage({Size=size}))
		local bytes=buffer.create(w*h*4)
		for i=1,#pixels do buffer.writeu32(bytes,(i-1)*4,packed[pixels:byte(i)+1]) end
		edit:WritePixelsBuffer(Vector2.zero,size,bytes)
		display=new("ImageLabel",holder,{Name="Photo",BackgroundTransparency=1,Size=full,ScaleType=Enum.ScaleType.Stretch,ImageContent=Content.fromObject(edit)})
	end)
	if ok then table.insert(owned,edit);return end
	if display then display:Destroy() end;if edit then edit:Destroy() end
	local bands=small and 22 or 48
	local splits=small and {0,.5,1} or {0,.48,.66,.81,1}
	for row=0,bands-1 do
		local sy=math.min(h-1,math.floor((row+.5)*h/bands))
		for j=1,#splits-1 do
			local l,r=splits[j],splits[j+1];local points={}
			for k=0,15 do
				local t=k/15;local sx=math.min(w-1,math.floor(w*(l+(r-l)*t)))
				points[k+1]=ColorSequenceKeypoint.new(t,colours[pixels:byte(sy*w+sx+1)+1])
			end
			local strip=new("Frame",holder,{Name="PhotoStrip",Position=ud(l,0,row/bands,0),Size=ud(r-l,1,1/bands,1),BackgroundColor3=Color3.new(1,1,1)})
			new("UIGradient",strip,{Color=ColorSequence.new(points)})
		end
	end
end

local function glyph(parent,paths,name,size,colour)
	local root=frame(parent,name);root.Size=off(size,size);local ink={};local k=size/24
	local function part(cx,cy,w,h,angle,filled,radius)
		local shape=frame(root,"Ink",filled and colour or nil,radius)
		shape.AnchorPoint=Vector2.new(.5,.5);shape.Position=off(cx*k,cy*k);shape.Size=off(w*k,h*k);shape.Rotation=angle
		if filled then table.insert(ink,{shape,"BackgroundColor3"}) else table.insert(ink,{outline(shape,colour,math.max(1,1.5*k)),"Color"}) end
	end
	for _,p in paths[name] do
		if p[1]=="o" then part(p[2],p[3],p[4],p[5],p[6],true,100)
		elseif p[1]=="c" then part(p[2],p[3],2*p[4],2*p[4],0,false,100)
		elseif p[1]=="b" then part(p[2]+p[4]/2,p[3]+p[5]/2,p[4],p[5],0,false,2)
		else
			for i=2,#p-3,2 do
				local x,y,dx,dy=p[i],p[i+1],p[i+2]-p[i],p[i+3]-p[i+1]
				part(x+dx/2,y+dy/2,math.sqrt(dx*dx+dy*dy)+.4,math.max(1.5,1/k),math.deg(math.atan2(dy,dx)),true,nil)
			end
		end
	end
	return root,function(tint) for _,p in ink do p[1][p[2]]=tint end end
end

local gui
local function mount(kit,assets)
	local players=game:GetService("Players");local input=game:GetService("UserInputService");local tweens=game:GetService("TweenService")
	local pg=players.LocalPlayer:WaitForChild("PlayerGui");local old=pg:FindFirstChild("SnowpawFieldConsole")
	if old and old:IsA("ScreenGui") and old:GetAttribute("SnowpawOwned")==true then old:Destroy() end
	gui=new("ScreenGui",pg,{Name="SnowpawFieldConsole",ResetOnSpawn=false,AutoLocalize=false,DisplayOrder=26,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
	gui:SetAttribute("SnowpawOwned",true)
	local external,images={},{};local closed=false
	local function listen(signal,fn) table.insert(external,signal:Connect(fn)) end
	gui.Destroying:Connect(function()
		closed=true;for _,c in external do c:Disconnect() end;for _,e in images do e:Destroy() end
		table.clear(images);table.clear(external)
	end)
	local tabs,accents=kit.tabs,kit.accents
	local state={tab=1,on={},levels={},accent=1,notes=true,compact=false}
	local function ice() return hex(accents[state.accent].hex) end
	local icon=function(p,n,s,c) return glyph(p,kit.icons,n,s,c) end
	local function at(o,x,y) o.Position=off(x,y);return o end
	local function tile(p,name,glyphName,s)
		local o=frame(p,name,C.tile,6); outline(o,hex("394751"));o.Size=off(s,s);at(icon(o,glyphName,17,hex("C5D8E3")),(s-17)/2,(s-17)/2);return o
	end
	local stage=frame(gui,"Stage");stage.Size=full
	local win=frame(stage,"Window",C.base,12);win.ClipsDescendants=true;win.Active=true;outline(win,hex("3A4A55"))
	local rail=frame(win,"Sidebar",C.rail);local railLine=frame(rail,"Edge",C.edge)
	local brand=frame(rail,"BrandMark",ice(),10);place(brand,18,24,38,38);at(icon(brand,"paw",26,hex("132632")),6,6)
	place(text(rail,"Brand","Snowpaw",23,bold,C.bright),65,20,131,31);place(text(rail,"Edition","FIELD CONSOLE",10,mono,C.dim),66,47,130,15)
	place(text(rail,"NavLabel","WORKSPACE",10,mono,C.dim),22,96,135,16)
	local wideNav=frame(rail,"Navigation");local token=frame(rail,"Colophon");at(icon(token,"snow",20,C.dim),1,6)
	place(text(token,"System","WINTER SYSTEMS",10,mono,C.dim),32,0,120,16);place(text(token,"Vol","Edition nº 001",10,mono,C.muted),32,15,126,15)
	local profile=frame(rail,"Profile");local profileLine=frame(profile,"Rule",C.edge);profileLine.Size=ud(1,0,0,1)
	place(text(profile,"Name","Snowpaw",13,bold,C.bright),64,17,110,18);place(text(profile,"Role","Resident mascot",11,sans,C.muted),64,35,115,16);at(dot(profile,"Indicator",C.mint,6),181,32)
	local avatar=frame(profile,"Mascot",C.tile,8,"CanvasGroup");avatar.ClipsDescendants=true;picture(avatar,assets.avatar,images,true)
	local bar=frame(win,"Header");local drag=box(bar,"Drag");drag.Selectable=false
	local crumb=frame(drag,"Breadcrumb");at(icon(crumb,"panel",16,C.dim),0,0);place(text(crumb,"Root","Workspace   /",12,sans,C.dim),26,-1,95,18)
	local current=text(crumb,"Current","Main",12,bold,C.bright);place(current,117,-1,76,18)
	local pocket=text(drag,"MobileBrand","Snowpaw",19,bold,C.bright)
	local mode=frame(bar,"Mode",hex("1B2827"),5);outline(mode,hex("31443E"));at(dot(mode,"Dot",C.mint,5),8,8);place(text(mode,"Label","UI ONLY",10,mono,hex("C1DACF")),18,1,50,20)
	local min=box(bar,"Minimize");at(icon(min,"minus",17,C.muted),8,8);local exit=box(bar,"Close");at(icon(exit,"close",17,C.muted),8,8)
	local smallNav=frame(win,"TabStrip");local navItems={}
	for i,t in tabs do
		for _,pair in {{wideNav,false},{smallNav,true}} do
			local b=box(pair[1],t.name,nil,6);local stroke=outline(b,C.edge);local sym,tint=icon(b,t.icon,pair[2] and 14 or 17,C.muted)
			local title=text(b,"Title",t.name,pair[2] and 12 or 14,bold,C.muted);local number=text(b,"Index","0"..i,10,mono,C.dim,right)
			local mark=frame(b,"Marker",ice(),2);table.insert(navItems,{b=b,small=pair[2],i=i,title=title,stroke=stroke,sym=sym,tint=tint,number=number,mark=mark})
		end
	end
	local divider=frame(win,"HeaderRule",C.edge)
	local scroll=new("ScrollingFrame",win,{Name="Content",BackgroundTransparency=1,BorderSizePixel=0,ScrollingDirection=Enum.ScrollingDirection.Y,
		ScrollBarThickness=3,ScrollBarImageColor3=C.dim,ScrollBarImageTransparency=.45,CanvasSize=off(0,0),Active=true,ClipsDescendants=true})
	local hero=frame(scroll,"FieldPlate",hex("16232C"),9,"CanvasGroup");hero.ClipsDescendants=true;outline(hero,hex("364750"))
	local plate=frame(hero,"NightStreet");picture(plate,assets.plate,images,false)
	local shade=frame(hero,"PocketTint",hex("12222B"));shade.Size=full
	new("UIGradient",shade,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.48),NumberSequenceKeypoint.new(.46,.64),NumberSequenceKeypoint.new(.77,1),NumberSequenceKeypoint.new(1,1)})})
	local dash=frame(hero,"Rule",ice());local edition=text(hero,"Series","WINTER SERIES  /  001",10,mono,hex("C7DBE6"))
	local heading=text(hero,"Title","",48,bold,C.bright);heading.RichText=true;local caption=text(hero,"Caption","",13,sans,hex("C3D5DF"));caption.TextWrapped=true
	local fig=text(hero,"Figure","+  FIG. 01",9,mono,C.bright,center);fig.BackgroundColor3=hex("172630");fig.BackgroundTransparency=.22;round(fig,3)
	local kicker=text(scroll,"SectionIndex","",10,mono,C.dim);local section=text(scroll,"SectionTitle","",22,bold,C.bright);local suite=text(scroll,"Suite","",11,mono,C.muted,right)
	local bench=frame(scroll,"Workbench");local foot=frame(win,"Footer");local footLine=frame(foot,"Rule",C.edge);footLine.Size=ud(1,0,0,1)
	local footDot=dot(foot,"LocalDot",C.mint,6);local status=text(foot,"Status","Local preview · no game effects",11,sans,C.muted);local tally=text(foot,"Count","",10,mono,C.dim,right)
	local launcher=box(stage,"OpenSnowpaw",C.rail,11);outline(launcher,C.edge);launcher.Size=off(153,49);launcher.Visible=false
	local stamp=frame(launcher,"Mark",ice(),8);place(stamp,8,8,33,33);at(icon(stamp,"paw",22,hex("132632")),5.5,5.5)
	place(text(launcher,"Name","Snowpaw",16,bold,C.bright),50,5,98,22);place(text(launcher,"Hint","Open console  ↗",10,sans,C.muted),50,26,102,15)
	local width,height,px,py=0,0,0,0;local gesture,modal,buildPage,layout,fit
	local cards,swatches,tuning,settingsRow,resetRow={},{},nil,nil,nil
	local total=0;for _,t in tabs do total+=t.cards and #t.cards or 0 end
	local function count()
		local n=0;for _ in state.on do n+=1 end;tally.Text=string.format("%d / %d SELECTED",n,total)
	end
	local function stopGesture() gesture=nil;scroll.ScrollingEnabled=true end
	local function dismiss() if modal then modal:Destroy();modal=nil end end
	local function ask(head,body,verb,fn)
		dismiss();stopGesture();modal=frame(win,"Dialog",hex("081018"));modal.ZIndex=10;modal.Size=full;modal.BackgroundTransparency=.28;modal.Active=true
		local backdrop=box(modal,"Backdrop");backdrop.Size=full;backdrop.Selectable=false;backdrop.Activated:Connect(dismiss)
		local sheet=frame(modal,"Sheet",C.panel,10);outline(sheet,C.edge);sheet.Active=true;sheet.ZIndex=2;sheet.AnchorPoint=Vector2.new(.5,.5);sheet.Position=UDim2.fromScale(.5,.5)
		local w=math.min(330,width-18);sheet.Size=off(w,170)
		place(text(sheet,"Kicker","SNOWPAW  /  CONSOLE",10,mono,C.dim),16,13,w-32,16);place(text(sheet,"Title",head,21,bold,C.bright),16,37,w-32,28)
		local desc=text(sheet,"Detail",body,13,sans,C.muted);desc.TextWrapped=true;place(desc,16,66,w-32,45)
		local cancel=box(sheet,"Cancel",C.tile,5);place(cancel,w-177,118,76,36);local cl=text(cancel,"Label","Cancel",13,bold,C.bright,center);cl.Size=full;cancel.Activated:Connect(dismiss)
		local yes=box(sheet,"Confirm",ice(),5);place(yes,w-90,118,74,36);local yl=text(yes,"Label",verb,13,bold,C.rail,center);yl.Size=full;yes.Activated:Connect(function() dismiss();fn() end)
	end
	local function paintCard(c,animate)
		local on=c.get();local tint=accents[state.accent].hex
		c.btn:SetAttribute("Selected",on);c.btn.BackgroundColor3=on and mix(tint,"182228",.9) or (c.hover and hex("202D35") or C.panel)
		c.border.Color=on and mix(tint,"23313A",.55) or (c.hover and hex("495A65") or C.edge)
		c.track.BackgroundColor3=on and ice() or hex("35434C");c.knob.BackgroundColor3=on and hex("19303D") or hex("B9C5CE")
		local target=off(on and 17 or 3,3);if c.motion then c.motion:Cancel();c.motion=nil end
		if animate then c.motion=tweens:Create(c.knob,TweenInfo.new(.13,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=target});c.motion:Play() else c.knob.Position=target end
	end
	local function makeCard(d,i,get,change)
		local b=box(bench,d.name,C.panel,8);local c={btn=b,border=outline(b,C.edge),get=get}
		c.tile=tile(b,"Glyph",d.icon,27);c.id=text(b,"Serial",tabs[state.tab].name:sub(1,1).." / 0"..i,10,mono,C.dim)
		c.track=frame(b,"Switch",C.tile,100);c.track.Size=off(32,18);c.knob=dot(c.track,"Thumb",C.muted,12)
		c.title=text(b,"NameLabel",d.name,16,bold,C.bright);c.note=text(b,"Note",d.note,12,sans,C.muted)
		b.Activated:Connect(function() if modal then return end;change();paintCard(c,true);count() end)
		b.MouseEnter:Connect(function() c.hover=true;paintCard(c,false) end);b.MouseLeave:Connect(function() c.hover=false;paintCard(c,false) end)
		table.insert(cards,c);paintCard(c,false)
	end
	local function sliderPaint()
		if not tuning then return end;local spec=tabs[state.tab].slider;local v=state.levels[state.tab] or spec.initial;local ratio=(v-spec.min)/(spec.max-spec.min)
		tuning.out.Text=tostring(v)..spec.suffix;tuning.fill.Size=ud(ratio,0,1,0);tuning.knob.Position=ud(ratio,0,.5,0)
	end
	local function scrub(x)
		if not tuning then return end;local track=tuning.track;local spec=tabs[state.tab].slider
		state.levels[state.tab]=math.round(spec.min+(spec.max-spec.min)*math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1));sliderPaint()
	end
	local function press(i) return i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch end
	local function makeSlider(spec)
		local c={};tuning=c;c.row=frame(bench,"Tuning",hex("172027"),8);outline(c.row,C.edge)
		c.tile=tile(c.row,"Dial","range",26);c.label=text(c.row,"NameLabel",spec.name,13,bold,C.bright)
		c.out=text(c.row,"Value","",12,mono,ice(),center);c.out.BackgroundTransparency=0;c.out.BackgroundColor3=hex("24313A");round(c.out,5)
		c.hit=box(c.row,"Slider");c.track=frame(c.hit,"Track",hex("34434D"),4);c.track.Position=ud(0,0,.5,-2);c.track.Size=ud(1,0,0,4)
		c.fill=frame(c.track,"Fill",ice(),4);c.knob=dot(c.track,"Thumb",ice(),11);c.knob.AnchorPoint=Vector2.new(.5,.5)
		c.hit.InputBegan:Connect(function(i) if modal or not press(i) then return end;stopGesture();gesture={kind="slider",input=i};scroll.ScrollingEnabled=false;scrub(i.Position.X) end);sliderPaint()
	end
	local function theme()
		local hue=ice();brand.BackgroundColor3=hue;stamp.BackgroundColor3=hue;dash.BackgroundColor3=hue
		for _,v in navItems do
			local active=v.i==state.tab;v.b.BackgroundTransparency=active and 0 or 1;v.b.BackgroundColor3=mix(accents[state.accent].hex,"182027",.90)
			v.stroke.Transparency=active and 0 or 1;v.stroke.Color=mix(accents[state.accent].hex,"28323A",.82);v.mark.BackgroundColor3=hue;v.mark.Visible=active and not v.small
			v.title.TextColor3=active and hue or C.muted;v.number.TextColor3=active and hue or C.dim;v.tint(active and hue or C.muted)
		end
		if settingsRow then settingsRow.label.Text="Accent · "..accents[state.accent].name end
		for i,s in swatches do s.stroke.Color=hue;s.stroke.Transparency=i==state.accent and 0 or 1 end
		for _,c in cards do paintCard(c,false) end
	end
	local function makeSettings()
		local p=frame(bench,"Palette",C.panel,8);outline(p,C.edge);settingsRow={row=p,tile=tile(p,"Paint","palette",26),label=text(p,"Accent","",13,bold,C.bright)}
		for i,a in accents do local b=box(p,a.name,nil,5);local s=outline(b,ice());at(dot(b,"Swatch",hex(a.hex),16),8,8);swatches[i]={btn=b,stroke=s};b.Activated:Connect(function() state.accent=i;theme() end) end
		for i,d in {{name="Module notes",icon="notes",note="Card descriptions",key="notes"},{name="Compact cards",icon="grid",note="Denser spacing",key="compact"}} do
			makeCard(d,i,function() return state[d.key] end,function() state[d.key]=not state[d.key];layout() end)
		end
		local row=frame(bench,"ResetRow",nil,8);outline(row,C.edge);local b=box(row,"Reset",C.tile,6);local captionLabel=text(b,"Label","Reset",13,bold,C.bright,center);captionLabel.Size=full
		resetRow={row=row,btn=b,title=text(row,"Title","Reset preview",13,bold,C.bright),note=text(row,"Note","Restore the default look and switches.",11,sans,C.muted)}
		b.Activated:Connect(function() ask("Reset the preview?","This clears selections, tuning and appearance for this session.","Reset",function()
			state.on={};state.levels={};state.accent=1;state.compact=false;state.notes=true;buildPage(4)
		end) end)
	end
	buildPage=function(index)
		stopGesture();dismiss();for _,child in bench:GetChildren() do child:Destroy() end
		cards={};swatches={};tuning=nil;settingsRow=nil;resetRow=nil;state.tab=index;local tab=tabs[index]
		current.Text=tab.name;kicker.Text="WORKBENCH / 0"..index;section.Text=tab.cards and "Module library" or "Preferences";suite.Text=tab.type
		heading.Text=tab.lead..' <font face="Garamond" color="#D2E8F1"><i>'..tab.script..'</i></font>';caption.Text=tab.caption
		if tab.cards then
			for i,d in tab.cards do makeCard(d,i,function() return state.on[d.id]==true end,function() state.on[d.id]=not state.on[d.id] or nil end) end
			makeSlider(tab.slider)
		else makeSettings() end
		theme();count();scroll.CanvasPosition=Vector2.zero;if width>0 then layout() end
	end
	layout=function()
		local small=width<750;local pocketSize=width<500;local side=small and 0 or 204;local body=width-side
		local top=small and 47 or 53;local strip=small and 46 or 0;local footer=small and 30 or 34
		local pad=pocketSize and 11 or (small and 14 or 21);local inner=math.max(1,body-2*pad)
		rail.Visible=not small;place(rail,0,0,side,height);place(railLine,side-1,0,1,height)
		place(wideNav,11,123,side-22,182);place(token,18,height-129,165,32);token.Visible=height>483;place(profile,0,height-72,side,72);profile.Visible=height>417
		place(bar,side,0,body,top);place(drag,0,0,body-153,top);crumb.Visible=not small;pocket.Visible=small
		place(crumb,21,(top-16)/2,198,16);place(pocket,49,0,math.max(1,body-215),top)
		avatar.Parent=small and drag or profile;if small then place(avatar,13,(top-29)/2,29,29) else place(avatar,17,18,36,36) end
		place(mode,body-148,(top-22)/2,70,22);place(min,body-71,(top-33)/2,33,33);place(exit,body-37,(top-33)/2,33,33)
		place(smallNav,0,top,width,strip);smallNav.Visible=small;place(divider,side,top+strip-1,body,1)
		for _,v in navItems do
			if v.small then
				local w=(width-21)/4;place(v.b,6+(v.i-1)*(w+3),5,w,35);local inset=math.max(2,(w-57)/2)
				at(v.sym,inset,10);place(v.title,inset+19,0,w-inset-20,35);v.number.Visible=false
			else
				place(v.b,0,(v.i-1)*46,182,42);at(v.sym,14,12.5);place(v.title,45,0,94,42);place(v.number,141,0,28,42);place(v.mark,0,12,3,18)
			end
		end
		place(scroll,side,top+strip,body,height-top-strip-footer);place(foot,side,height-footer,body,footer);at(footDot,pad,(footer-6)/2)
		place(status,pad+13,0,body-2*pad-108,footer);place(tally,body-pad-98,0,98,footer)
		local h=pocketSize and 135 or (small and 155 or 200);place(hero,pad,pad,inner,h);local pw=math.round(h*assets.plate.w/assets.plate.h);place(plate,inner-pw,0,pw,h);shade.Visible=pocketSize
		local hx=pocketSize and 14 or 25;local ht=pocketSize and 33 or (small and 42 or 53);local hy=(h-(ht+53))/2
		place(dash,hx,hy+6,16,2);place(edition,hx+23,hy,inner-hx-29,15);heading.TextSize=ht;place(heading,hx,hy+15,inner-hx-12,ht+9)
		caption.TextSize=pocketSize and 11 or 13;place(caption,hx,hy+ht+24,pocketSize and math.max(100,inner*.49) or inner*.54,pocketSize and 29 or 21);place(fig,inner-64,h-24,54,16)
		local headY=pad+h+(small and 12 or 16);place(kicker,pad,headY,inner,14);section.TextSize=pocketSize and 20 or 22;place(section,pad,headY+14,inner-98,26);place(suite,pad+inner-101,headY+15,101,24)
		local by=headY+49;local gap=pocketSize and 7 or 10;local cols=inner<269 and 1 or 2;local cw=math.floor((inner-gap*(cols-1))/cols);local cy=0
		if settingsRow then
			place(settingsRow.row,0,0,inner,49);at(settingsRow.tile,10,11);place(settingsRow.label,44,0,inner-163,49)
			for i,s in swatches do place(s.btn,inner-113+(i-1)*36,8,32,32) end;cy=59
		end
		local ch=state.compact and 79 or (pocketSize and 93 or 101);local inset=pocketSize and 10 or 14
		for i,c in cards do
			place(c.btn,((i-1)%cols)*(cw+gap),cy+math.floor((i-1)/cols)*(ch+gap),cw,ch);at(c.tile,inset,10);at(c.track,cw-inset-32,13)
			place(c.id,inset+34,10,cw-2*inset-69,26);c.id.Visible=cw>139
			c.title.TextSize=pocketSize and 15 or 16;place(c.title,inset,state.notes and ch-43 or ch-31,cw-2*inset,21);c.note.Visible=state.notes
			place(c.note,inset,ch-23,cw-2*inset,17)
		end
		cy+=math.ceil(#cards/cols)*(ch+gap)
		if tuning then
			local c=tuning;place(c.row,0,cy,inner,52);at(c.tile,10,13);local nameW=pocketSize and 108 or 135
			place(c.label,44,0,nameW,52);c.label.TextSize=pocketSize and 12 or 13;local tx=44+nameW+6
			place(c.hit,tx,4,inner-tx-65,44);place(c.out,inner-55,14,44,24);cy+=52
		elseif resetRow then
			local r=resetRow;place(r.row,0,cy,inner,55);place(r.title,12,6,inner-97,21);place(r.note,12,27,inner-97,18);place(r.btn,inner-74,10,63,35);cy+=55
		end
		place(bench,pad,by,inner,cy);scroll.CanvasSize=off(0,by+cy+pad)
	end
	fit=function(recenter)
		local room=stage.AbsoluteSize;if room.X<2 or room.Y<2 then return end
		width=math.max(1,math.min(1016,room.X-(room.X<500 and 12 or 26)));height=math.max(1,math.min(686,room.Y-14))
		if recenter then px=(room.X-width)/2;py=(room.Y-height)/2 end
		px=math.clamp(px,0,math.max(0,room.X-width));py=math.clamp(py,0,math.max(0,room.Y-height));place(win,px,py,width,height)
		launcher.Position=ud(0,10,1,-59);layout()
	end
	local function fold(hidden)
		stopGesture();dismiss();win.Visible=not hidden;launcher.Visible=hidden;if not hidden then fit(false) end
	end
	for _,v in navItems do v.b.Activated:Connect(function() if state.tab~=v.i and not modal then buildPage(v.i) end end) end
	min.Activated:Connect(function() fold(true) end);launcher.Activated:Connect(function() fold(false) end)
	exit.Activated:Connect(function() ask("Close Snowpaw?","This clears the local session. Run the menu again to reopen it.","Close",function() gui:Destroy() end) end)
	drag.InputBegan:Connect(function(i) if press(i) and not modal then stopGesture();gesture={kind="move",input=i,x=px-i.Position.X,y=py-i.Position.Y} end end)
	listen(input.InputChanged,function(i)
		local g=gesture;if not g then return end
		if not (g.input==i or (g.input.UserInputType==Enum.UserInputType.MouseButton1 and i.UserInputType==Enum.UserInputType.MouseMovement)) then return end
		if g.kind=="slider" then scrub(i.Position.X) else
			local room=stage.AbsoluteSize;px=math.clamp(i.Position.X+g.x,0,math.max(0,room.X-width));py=math.clamp(i.Position.Y+g.y,0,math.max(0,room.Y-height));win.Position=off(px,py)
		end
	end)
	listen(input.InputEnded,function(i) if gesture and (gesture.input==i or gesture.input.UserInputType==Enum.UserInputType.MouseButton1 and i.UserInputType==Enum.UserInputType.MouseButton1) then stopGesture() end end)
	listen(input.WindowFocusReleased,stopGesture)
	listen(input.InputBegan,function(i,processed)
		if closed or i.UserInputType~=Enum.UserInputType.Keyboard then return end
		if modal then if i.KeyCode==Enum.KeyCode.Escape then dismiss() end;return end
		if not processed and not input:GetFocusedTextBox() and i.KeyCode==Enum.KeyCode.RightShift then fold(win.Visible) end
	end)
	stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() fit(width==0) end)
	buildPage(1);fit(true)
end

-- BEGIN EMBEDDED KIT (generated from snowpaw/kit.json and snowpaw/assets)
local CATALOG={
tabs={{["name"]="Main",["icon"]="grid",["type"]="Aim suite",["lead"]="Night",["script"]="patrol.",["caption"]="A field kit for the quiet hours.",["cards"]={{["id"]="aimbot",["icon"]="target",["name"]="Aimbot",["note"]="Target assistance"},{["id"]="trigger",["icon"]="mouse",["name"]="Triggerbot",["note"]="Trigger response"},{["id"]="lock",["icon"]="focus",["name"]="Target lock",["note"]="Focus retention"},{["id"]="predict",["icon"]="path",["name"]="Prediction",["note"]="Motion estimate"}},["slider"]={["name"]="Field of view",["min"]=30,["max"]=180,["initial"]=90,["suffix"]="°"}},{["name"]="Extra",["icon"]="layers",["type"]="Movement suite",["lead"]="Snow",["script"]="tracks.",["caption"]="Movement studies from the night shift.",["cards"]={{["id"]="flight",["icon"]="wing",["name"]="Flight",["note"]="Air movement"},{["id"]="speed",["icon"]="speed",["name"]="Walk speed",["note"]="Travel pace"},{["id"]="jump",["icon"]="jump",["name"]="High jump",["note"]="Jump height"},{["id"]="noclip",["icon"]="layers",["name"]="Noclip",["note"]="Collision style"}},["slider"]={["name"]="Travel speed",["min"]=16,["max"]=80,["initial"]=32,["suffix"]=""}},{["name"]="Visual",["icon"]="eye",["type"]="Visual suite",["lead"]="Low",["script"]="light.",["caption"]="Sightlines in a snow-covered city.",["cards"]={{["id"]="esp",["icon"]="focus",["name"]="Player ESP",["note"]="Player overlay"},{["id"]="box",["icon"]="cube",["name"]="Box outlines",["note"]="Frame style"},{["id"]="tags",["icon"]="tag",["name"]="Name tags",["note"]="Label display"},{["id"]="trace",["icon"]="path",["name"]="Tracers",["note"]="Line style"}},["slider"]={["name"]="Overlay opacity",["min"]=0,["max"]=100,["initial"]=70,["suffix"]="%"}},{["name"]="Config",["icon"]="sliders",["type"]="Interface",["lead"]="Base",["script"]="camp.",["caption"]="Settle in. Make the console yours."}},
accents={{["name"]="Glacier",["hex"]="AEDBF2"},{["name"]="Aurora",["hex"]="ACE3CC"},{["name"]="Ember",["hex"]="EDBE99"}},
icons={["paw"]={{"o",4.9,10.1,4,6.2,-24},{"o",9.3,6.8,4.4,6.6,-8},{"o",14.8,6.8,4.4,6.6,11},{"o",19.2,10.1,4,6.2,24},{"o",12,15.6,10,9.2,0},{"o",9.3,16.7,7,6.5,-20},{"o",14.7,16.7,7,6.5,20}},["grid"]={{"b",3.5,3.5,6,6},{"b",14,3.5,6,6},{"b",3.5,14,6,6},{"b",14,14,6,6}},["layers"]={{"p",2.5,8,12,3,21.5,8,12,13,2.5,8},{"p",3,12.5,12,17.5,21,12.5},{"p",3,17,12,22,21,17}},["eye"]={{"p",1.5,12,5,7.8,8.7,5.8,12,5.3,15.3,5.8,19,7.8,22.5,12,19,16.2,15.3,18.2,12,18.7,8.7,18.2,5,16.2,1.5,12},{"c",12,12,3.1}},["sliders"]={{"p",3,7,7.6,7},{"p",13.6,7,21,7},{"c",10.6,7,2.8},{"p",3,17,11.2,17},{"p",16.8,17,21,17},{"c",14,17,2.8}},["target"]={{"c",12,12,7.2},{"p",12,1.5,12,6.5},{"p",22.5,12,17.5,12},{"p",12,22.5,12,17.5},{"p",1.5,12,6.5,12},{"o",12,12,3.2,3.2,0}},["mouse"]={{"p",5.4,10,5.4,8,6,5,8,3,10,2.4,14,2.4,16.5,3.3,18.5,6,18.6,9,18.6,15.3,18.1,18.1,16.6,20.5,14.2,21.5,10.5,21.5,7.8,20.5,6.2,18.5,5.4,15.3,5.4,10},{"p",12,2.8,12,9.3}},["focus"]={{"p",3,8.5,3,3,8.5,3},{"p",15.5,3,21,3,21,8.5},{"p",21,15.5,21,21,15.5,21},{"p",8.5,21,3,21,3,15.5},{"c",12,12,2.7}},["path"]={{"c",4.5,17.5,2},{"c",19.5,5.5,2},{"p",6.3,16.5,10,11,13,14,17.8,7}},["wing"]={{"p",3,13,21,3,16,20,12.8,13.7,3,13},{"p",12.8,13.7,21,3}},["speed"]={{"p",3,17,12,6},{"p",9,17,18,6},{"p",15,17,21,9.5}},["jump"]={{"p",4,19,8,19,8,6},{"p",4,10,8,6,12,10},{"p",14,16,18,16,18,3},{"p",14,7,18,3,22,7}},["cube"]={{"p",12,2,21,7,21,17,12,22,3,17,3,7,12,2},{"p",3,7,12,12,21,7},{"p",12,12,12,22}},["tag"]={{"p",3,3,11,3,21,13,13,21,3,11,3,3},{"c",7.8,7.8,1.3}},["snow"]={{"p",12,2,12,22},{"p",3.4,7,20.6,17},{"p",3.4,17,20.6,7},{"p",9,4,12,7,15,4},{"p",9,20,12,17,15,20}},["range"]={{"p",3,14.8,7,9,12,6.9,17,9,21,14.8},{"p",12,14,17,9},{"p",3,18,21,18}},["minus"]={{"p",5,12,19,12}},["close"]={{"p",6,6,18,18},{"p",18,6,6,18}},["panel"]={{"b",2.5,4.5,19,15},{"p",9,5,9,19}},["check"]={{"p",4,12,9,17,20,6}},["palette"]={{"c",8,9.5,4.5},{"c",16,9.5,4.5},{"c",12,16,4.5}},["notes"]={{"p",4,6,20,6},{"p",4,12,20,12},{"p",4,18,14,18}},["reset"]={{"p",3,9,5,5,9,3,14,3,18,5,20,9,20,14,18,18,14,20,10,20,6,18},{"p",3,3,3,9,9,9}}}
}
local PHOTOS={
plate={w=460,h=134,palette="15212C18242E1624311825311727331C29341C2B39212D38202D3624313A313D452C394228353D4C566039454D3D495235414A293640414D5529353D4D596149555D545E6745515A3B465039444B4B565C434E585C6770323E4855616959646C5D6971515C646E79801E303D1A272F616C74646F772433406571797D888E848F97717C8369747B79848B758187757F88828C9389949B88939A7E89906C777F9EA9B0A9B4B8C2CDD1B9C4C9A2ACB298A3A969747A879297C9D4D8E4EFF3D9E4E8C6D1D5919CA2BEC9CFB2BDC2A9B4B99AA5AA5A656B8E99A0AEBABF0D1A23111E2708151DD2DDE1",data=table.concat({
"AAAAAAAAAAAAAAAAAAAAAAEBAQEBAQEBAQAAAAAAAAAAAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQEAAAAAAAABAQAAAgIDBAUFBAQEBQUEBQUEAwMDAwMCAgICAgICAgAAAgEBAAEAAAAA",
"AQECAgIAAgIAAgICAgQEBgYGBgQCAgICAgICAgICAgMDAgIDAgICAgICAgYGBAIDAgICAgMDAwMDAgIEBgIDAwIDAwMDAwMCAwYEAgICAgICAgIDAwYEAgICAwICAwMCBAYCAgMCAgICAwMCBQYCAwMDAwQDBQMB",
"BAcEAwMCAwUFAwUFAwYHBQUDCAcFBQUFBQUHCQkFBQgHCgUHCAkLCQkJCAMHDAsLCQkICAgJCQgIBQUHCQgJDQwFBQsODwsIDAUICQgICAgFBRAKCAgJCAkJBQUDBQgMEAgJCAwLCQgJCQkJCQcHBwcFEQwFCQUM",
"CwgSDAgJCQgJCAUIDAkJCAkICQwMCQgJBwgJCQgMDAkLCQkJDAgMDAwJChAJEwoMDA8NCQwQDBAQEg8KFBUOFhcQGBIQGRkaFw8QEhIYGxQcEhAPCxAVChUQEQsTCwkLEAgRGAAAAAAAAAAAAAAAAAEBAQEAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAQEAAQIAAAICAgICAgICAgMDBQUFBQUFBQUFBQUEBQQEBAQEBAICAgQEBAQEBAQEBAYGBgYGBgUEAwIC",
"AgICAgICAgICAgICAgICAgICAgMCAgIGBgICAgICAgICAgICAgICBAYCAwICAgICAgICAgIGBAICAgICAgICAwIGBAICAwICAgMDAgQGAgICAgIDAwMDAgYFAgMCAwMEAwMFAwYGAwMFBQMFAwMDAwUHBQUFBQMF",
"BQUFBQYFBwkJCAgIBwgRCQgFCBEMCQgFCQcICQ8IBwUIEAkIBQgJCQkFBQoJCQkFDAsJBQkJCQUJCAwICQkMCQwXCAgJCQUFBQkPCAUICAkIDAkJCAkJCQcICAgICAcICQkICQwBFA8ADBAICAgJBwgIBQkMCgsF",
"CwkJCAUJCRATCQkIEwkJCAkMCRMJEAkIDgwSEBELGA0VDAoKCwoYDgsKChQPEAsQChAdHhUQFxkQEA8XHwsSDgsQEA4OCgsLDA4KDBUJCgsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQEAAAAAAQEAAAAAAAAAAAAAAgICAgICAwMCBQYEBAQFBQUFBQYGBgYGBgYFBQUEBAQEAgICAQMCAgICAgICAgICAgICAgICAgICAgIC",
"AgIFCQUCAgICAgICAgMDAgIDAgUGAgICAgICAgICAgICBgQCAgICAgMDAgICBgQCAgMCAgIDAwIEBgICAwICAgIDAwIGBAMDAgQCAwIDAgYHBAMDAwMDBQUDBQMHBgMFAwwMBwkFBQYGCQUDBQgRCQgHCQcFCQkJ",
"CQkICAgJCAkKBQgICQsJCQUJDAkICAkFBQsPCAUKEAkFCwsICAkLCAkJBQgMCQgICQkJCAgRCAgICAkMEAUJCQkJCQgIBQUICAgFBQkJCQUMAxAPCQgJBQUICAkJCAkICQwMCxAFCQkICQkRCwkFCwkJCQ4MEQwI",
"CAsJCwsQExkLCxgeFRkSGQsKEA8aDxAOFxcQDhcXFSAeDhIPDhUPGBkOFBAYDAoQCxEPGAwPDwkQCQkIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAEBAAAAAAEAAAEBAAEAAAEBAAAAAAACAAABAQEBAgICAgIBAQAAAgAAAgEBAAAAAAAAAgICAgIDAwAAAgICAwICAwICAgICAgICAwICAgICAgICAgICAgMCAgIEBgYCAgMCAgICAgICAgICAwIG",
"BgICAgICAgICAwIDAgYFAgICAgIDAwIDAgYGAgICAwICAwMCBQYCAgICAgMDAwIDBgQDAwMCBQUCAwMFBgMDAwUGBQUDBQUFBgMFBQMJCQMJCQUFCQcHBQkMCQUICQkFCAsIBQkLCQkJCAcJCQgFCQkQCwUFGQwJ",
"CQgJCAgJCQgJCQkICAUJCQgMAwgQCQUJDAkICQkJCwUFCAgFBQgJCBAJDAkMCQkICAgICAcFBwsJCAgIBQgDBQ4XCAcFBQUHCQgJCAgJGQ4LBRkICQgJEwkJCAkTDAgYDAwJEQsMDgwLDAwKCgsODhAOEAoLDg8L",
"FxIVDg8XGxUXFx8NFQ4UFBIPEg4SGRgQCwoPCwwPFxcKEAwLBQsJDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAECAQIBAQICAQEBAQAAAAAAAAAAAAAAAAAA",
"AAAAAAEAAAEBAAEBAQAAAgEAAAABAQEBAAABAAABAQECAQEBAgICAgICAgICAwICAgICAgICAgICAgICAgIDAgUDAgMCAgICAgICAgIDAwICBgYDAgMDAgICAwICAgICAgICBgYCAwMCAgIDAgICAgIGBgIDAgIC",
"AgICAwIGBgIDAgICAgMDAgQGAgICAgMCAgICBAYDAgQEAgQEBQMDBgUDAwMDBQUDBQUFBgkFAwUFBQUFBQUGCQcDBQwJCAUICAgFCAcHCQUMCAUJCAkJBwkIBQkMEBEFCREJCQgJCQUQCQkJCQkMDAkJBQgICQgF",
"CwkICwkMCAkJCBAJBQsICwoFCQUFBwkJCQkJCAkJCQkIBQgJBQgJCAgICAUJEggJBwgFCAcMBQgICQUMDAkeCQwFBQsJBQkICQsMCggJCAwKCwsICRgODwsQEA4QFxAQDxgZDxcPEhcUDRIPFRIaGxIXIRoXFQ8O",
"Fw4QCgsLChIKChkSCQwLCxAKCwwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgICAwICAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwQEBAQEBAQDBAMCAgIBAQEAAAAAAAAAAAABAQABAQAA",
"AQEBAQAAAAABAQEBAQEBAQICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwICAgICAgICAgICBgYEAgICAgICAwMCAgICAgICAgYGAgMCAgIDAwIDAwMCBgYCAwICAgICAgMCBgYCAwICAgIDAwIFBgIC",
"AwICAgICBQYGAgMDAwICAwUDAwYDAwMDAgUGAwUHBwYFBQcJAwcHBQUFBwYRCQUKBQgFCQkICAwMBwcJCwgICAgJBwsICAcJDAgICAkJCAkJGQUFBR0OCAgHCw4JCQkJCQgICAgICQwJChAICQgICQkLCQwJCAUI",
"CQgRCQwJCQkICAkJCAgIBQgICQkICAgICwgFBQsKBQgICQodCAgJCAgMGBEJAQgICAsJCAkRDAwLCQkQEAsMDAgOEBULCxgKEBkYEBAZDxIPEBciEhgYFyEVDRoUFxcXFxcOFRIQEBkSEhgPCxAOCw4LCwwTDAkM",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAICAgICAgMCAgICAQABAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAgICAgICAgIDBAUDAwMDBQMDAwMCAgIAAAAAAQAAAQEBAQEBAQEBAQEBAQEBAQEBAQEB",
"AgICAgEBAQECAgICAgICAgICAgICAgICAgICAgMCAgICAgICAgICBCMGAgICAgICAgMDAgICAgICAgIGBgICAgICAwIDAwMCAgYGAgMCAgICAgMDAgYFAgICAwICAgICBQYCAgICAgIDAwIFBgIDAwMDAgMCAwYG",
"AwMFAwMDBQMDBQcDBwUFBQUFAwYJBQcFCAcFBQkJBQwHBQkHCQcFCwsIBwgHCAkQCAgHCQgFCwkJGQwJDAwICQgMEQgJCAUFDAkJCQkICQkICAUQEAUMCAkJCQkFCRAJBQgJBQgJCBEJCQkIDBMICAkICAgHCAUI",
"GQsIBRILBQULGAUFBQUJCQgJDAgDCxcFCRALBQUJCQkJCQwJDAsLEQsLCwgJDAkFDAkNDwsLDx8hFxcNDw4PHw4bIRchHiEfIB8UFSAXHx4SCxAYFxcQCxAQCwsKCgwLEAoMCQAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAABAQECAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEBAQEAAAAAAAAAAAAAAAAAAAAAAAAAAQICAwMEBAUFBAQEBAMDAgIBAAAAAAAAAAEBAQEAAQIBAgIBAgICAgIBAQABAgICAgICAgICAgIC",
"AgICAgICAgICAgICAgICAgECBAYGAgICAwICAgIDAgICAgIDAgICBgYCAQICAgMCAgICAgIGBQIDAgIDAwMCAgIGBAACAgMCAgICAgYFAgIDAgIDAgICBgUDAwQDBAQDAwQJBAMDAwMFBQMDAwcFAwUFBQMFBgUF",
"BwcFBQUFBQUJCQUFBQkICQcICAgICQkHCQgICAkFDAwICgwJEx0MCAkJBQkJBQUICQkICQkJCQkJCAkICAgIDBEICAgJCQgYHQURCQkJCRgMBQkJCQgJJA4YBQkJCAcICAkMCAsMCQUZCwgFCxIICQgJCAUFCAgM",
"CAkJCAgPEAsAEQkTCQkTEAwLCggJCQoZCQwQCxEPCw4YEA4VDRQZCyEiEhUUFSEfHCUlJhwNIRQeDx4VEg4XCxsKGQkQDxEREBQVCggFCQsAAAAAAAAAAAAAAAAAAAAAAAAAAAEBAQEBAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAwEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQEBAAAAAQAAAAAAAAAAAAECAgIEBAQEBQQFBAMCAgICAAAAAgICAgIBAQIBAQICAgICAgIBAQIBAQICAgMDAgICAgICAgICAQMCAgICAgACBgYn",
"BAICAgMCAgICAgICAgICAgMCBAYFAgICAwICAgICAgICBgQCAwICAgIDAgICBgQCAgICAgIDAgUGBgICAgICAgIDAgYEAwMDAwQCAwMFBgIDBQMDAwUFAwYHAwUDBQUGBQUFBgcGBQYICQUFBQUIBwsHBQkIBQgH",
"BwcJCQkHCQkICQsMCBEkDAwWCAkMAR0ZAwkICAgICAkJCQkJCQkIDAwJCQUZEgkJCQkJCwsJCAUJCRMQCQUQFwUJCQUOEQUFCQsMCQkMCwwICQwMAAAJBQoZBQkICwUFCAgJCQgFEwUFBQsICBAIBRQYChELCxEK",
"CQkLGQwQCxMMGBALDiUoHykqKB8cKCEhHyUgKysmKywWJRYUDhweFBAXFRAPHRAQDhAOEAsJEQwQFCwsAAAAAAAAAAAAAAAAAAAAAAEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAEBAQEAAAAAAAAAAQICAwMEBQUFBQQEBAMCAgIAAgIAAgICAgICAgICAgICAQECAgICAgICAgICAgICAgMCAwECAgIEBgYFAwICAgICAgICAgICAgICAgICAgQG",
"BAIDAgICAgICAgICAgYFAgICAgICAwICAgYEAgICAgIDAwICBgUCAwMCAgIDAgQGAwMDAwMDBQMCBgYCAwUFAwMDAwUHBQUDAwcGBQUFBQcGBQUFCAwFCAgFCAkJDAUICAgICAcHCQkICREMBwkREAUFCQgKCwkM",
"CQkJCwkICQgIBQkJCQkICQkJBQwLCQkICAwJDAgTDAUJCQgFERAFCRIJCRMJDAUFDAsLDgwICQkJCRALHQsICBUMBQkJCAUJCAwMCAgFCAkICQkFBQEZCwgMCQkTCQkRDBAJDxAMDAkRDAsKCwgSFB4tLi8lHist",
"LiEeHC8uMDEyMTMoJiUNHw0VFw8PFwoKCg4hGAsKISQZFxwuLh4OCQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AwIAAAAAAAABAQEBAQEBAAEBAQEBAAAAAgICAgIEBAUFBQUFBQUEAgICAgICAgICAgICAgICAQECAgICAgICAgICAgMFAgECAgUGBgYEAgACAgICAgICAgICAgICAgIDAgIjJwICAwICAgICAgICAgIGBAICAgIC",
"AgMCAgIGBAICAgICAwIDAgYEAgIDAgICAwIEBgMDAwQDAwUEAwYEAwMDAwMDAwMIBwUFBQUDBQUFBQcIBQUGBQUDBQcJCAkHCAwDCAkICAgJCQkJCAkIBwwRCQkJEQkFEAsLCQgJCAkMCAkICAgICQsJCAkMCQkL",
"CQgJCQkJDgkJCQsJCAkFCAUICQkIDAkLFwUSEhwgHismFwoMCQgJCAkJBQgKCCQMCQgQCAgFGBEJCAUJCQkJCQUFCQsMDAgdEAgJEQwJCQsJExMTDgoQEBkQJTEoHyUfJiYmHyshHzQrNTY3ODkpLSgfJRQXDxUQ",
"EAoKCwoVDAkTCiEiKS4fDggJCQUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAAAAAAAAAAAAAAAAAAAAAAABAAEBAAAAAAAAAAAAAAAAAAAAAAIAAAAAAQEBAAABAQAAAAAAAAAB",
"AAABAAIFAgIBAAAAAgIDAwMEBQUGBgUEBQQEAgICAgACAgAAAgICAgICAgICAgICAgQFBgYGBgQCAgICAgICAwICAgICAgICAgICAgICIwYCAgIDAgICAwICAgICBgQCAgICAgIDAgICBgQCAgICAgIDAwMGBAIC",
"AgICAgICBQYCAwMDAwMDAgUGAwMDAwMDAwMFCQYFAwUFBQUFBQYHBQUGCQcFBQUJCQcJBQgFBwULDAgHCAkICAkJCAkMEQkICQwJERAFDAwJCAgMCwgICQkJBRgPCAwICQkJCwkHCQkJDBkIDAwMCQkLCQgICAkJ",
"CQkJEwUJKCsrLCUeGhIcIhAMCQwJCQUICBALCQgLIQkFCAgICAgICQwMCAcICAULEQwJDAsLDAsKCxAMHREKCRAODBAULDowGiYfISAeGxINOyYlPD0+Pj81MzArJiUfIiAPEhUbDwsJHRc7MjEiHgoICwkLCgoM",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQICAwMDAwQEBAQEBAQEBAQEBAQEBAUEBAQEBQUFBQQDAgIAAAIAAAAAAAAAAAAAAAIAAAABAQAAAAAAAgIBAAABAQEBAAAAAAAA",
"AgMDAwUFBgYGBQUGBQQEBAQEBAQEBAQEBAUGBgYGBgYFAwICAgICAgICAgICAgICAgICAgICAgICBAYEAgICAgICAgMCAgICBAYDAgMCAgICAgICAgYEAgIDAgIDAwMEBgMCAgICAgICAgYFAgMDAwMDAgIGBQME",
"AwMDAwMDBgYDAwMFBQUFBQUHBQUFBwcFBQgHBwcFBQgFCQgJEQkJBwwMCAgJBwkHCQkIBQgICQwZBQkKCAUICAgICAgJCQgICBEQBQkMDAsJDAwJBQ8MBQwMCAkJDAgJCBEFCQkICQgOFCEgIRwsKDMsGhAhJgcJ",
"CQwQBwkQHQkLCSQICAUICAgHCQUJDAgICQcICAkLERELCgsIDA4PCwsMChALDCUsIC0rJiYfHxQPDw8SFx87Ljo/Pj5AQTAqKxolKCEeGhASGhIfMyozLRUQCRkJEQwJEwgJCwAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAQIDAwMDAwMDAwEBAQEAAAAAAAAAAAAAAAAAAAAAAAACAgMDAwMDAwMFAwUDBQUEAwMCAgICAAMFAAAAAQEAAQEBAAEBAAICAQEBAQEBAQEBAQABAQECAAICAgIEBAQEBQUGBgYG",
"BgYGBgYGBQUFAwICAgICAgICAgICAgICAgICAgICAgICAgICAgYGAgICAgICAgICAgICAgQGAgIDAgICAgICAgMGBAICAgICAgICBAYCAwICAgICAgIGAwMDAwMDAwEDBgQDAwMDAwMDBQcFAwMFBQMFBQUHBQUF",
"BQUFCQcHCQcFCAgJCwsFCAgFCQgJCQgIBwgJBwkICQkIDAsIBQkJBQMHEAkJCQgLCQkJCQkICR0JCAUICQwLCQkIDAkTCQsICAgICQkQCAkJCQULOyYhIR8QHyUrLTAeDhAhDgUIGQwJCQgJCwgIBQMFCwsHBwwM",
"EQsJCAwHBQkJCQkIDAsTDhALDBATGQkfJhYfDSAwQSUaHiESHQ8SDhIWFjE2OEJDNkFERSUcJhcZChYuLTk6Mh8LCQ4MEQoOCgoXEAkLFwgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEBAgIDAgIB",
"AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAACAwMEBAUFBAQDAgICAAAAAAAAAQEBAAAAAAEBAQEBAQEBAQEBAQEAAAEBAAICAgACAgICAgICAgICAgICAgICAgEBAgIDAwICAgIC",
"AgICAgICAgICAgICAgICAgQGBAACAgICAgICAgICAgIEBgICAgICAgICAgIEBgICAgICAgICAgUGAgMCAgICAgIEBgIDAwMDAgMFBQYDAwMDAwMDAwUGAwMDBQMFBQUHCQkFBQYGBQkHCAcGBQUIBRAMCAUICQ4J",
"BQcICQcIBwgJFwgICAwLEAsFCAkJBR0IDAgIEwkJCQkICAkJCAkREwoIEREYDAkJCgkMCQkJCAkQBQkBHRkFCxwhIR8lIRIXHiErKhwXEBINIRMBBQkJBQgMBRAMBQwJDBEFCQoKCwsFBQsMCAkPCwkJEQwKCw4Q",
"CBcUHzAYGSUyMSVGFB8UEBkJCw4fHyhBPDoyK0FDQEUNKywsMUdEOS0lGAoOChsdCQ4OCwsMHRgLCQsLAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQICAgICAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAABAAAAAAAAAQAAAAAAAAABAQAAAAAAAAAAAAICAwUFBQUEBAMBAAAAAAABAgEAAQEBAAABAQAAAQEBAAICAgIBAgIBAQICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIDAwIGBgIC",
"AgIEAgICAgICAgICBgUCAgIDAgICAgICBQYCAgICAwICAgIFBgICAgICAgIBBQYCAwMDAwIDAwYFAgMDAwMDAwQGAwMDAwMDBQcFBwcMBQgGBQUFBgkFCAgFCAgIBQwLCB0MCAwMCAgICAkIGBwFCQgJCQwOCwgJ",
"CQkFBQgJCQgICQkJCAcICRgIEBMJCQoYCAUICRAMBQkJCQkICAkFEA0JCRQNDg8OGiUiJSYcHjsrFhULEDAlChAICxIKCBMLDBgLBREUFxYhMRoeKSgyMSsXDCIQDyIVEgsgJhUvHiseDyhHKUZGJiwWEwkYCh0P",
"FB8oIispMS4eOT1CMUBERDorHhcKDw8PDxkHCQwMCRAJHQsMCwoTEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEBAQEBAQAAAAAAAAAAAAEDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAICAgMEBAQEBAMCAgAAAAABAQEBAQEBAQAAAAEBAQEBAAEBAQEBAQECAgICAgICAgIBAQICAgICAgICAgICAgICAgICAgICAQIDAgIBAQIEBgQFAwICBgMCAgICAgICAgYFAgICAgIC",
"AgICAgQGAgIDAgMCAwMCBgYCAgICAgICAgYEAgIDAwMDAwMGAwMDAwMCAwMGBgMFBQMFBQUFCAYDBQUGBQYGBwkIBQgICAgHCAUJBwULCQURCwcFBQgFBQsQCAgLCw8HDAkJCQwLCAkJBwkJCQgLDAUMCwwbDggT",
"DAkJCBAQBQgJCRkOCwgJCAwMBQsOAQogIQ8KEQsQGxQeNDIxMyxGHhIYLB4SDg0gHh5BFSgtCi0mHykUJjpGMEUsK0QwOi05KilERTAtPEE5OSoqJSsxMCY8KiULBRARFQodGRoeNCggHx8gLTc3N0QpIBIhKBcZ",
"GQ8QHQ4QDRAJEAkLEBAKEBEPCwkAAAAAAAAAAAAAAAAAAAAAAAEBAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAwAAAAAAAAAAAAAAAAAAAAAA",
"AAACAwQFBQUEBAICAAACAgAAAAABAQICAQEBAQEBAQEBAQEBAgICAgICAgICAQECAgICAgICAgECAgICAgICAgIDAgECAwICAgIDBgYCAgICAgIDAgICAgIDAgQGAwICAgICAgICAgIGBQICAgICAgICAicFAgIC",
"AgICAgIGBAIDBAMDAgIEBgMDAwMDAwUDBgQDBQcDBQUFBwcDBQUFBQUFBwkJBQgICQgHCAgHCAgMCQgFCwoFDAkFCwgJCQgREAcJCQgJCAkMDAkJCAgJCQkJCQkJCQkkHhcFDAwJCQkLDAgMCQsSCQkJCAwKCQUJ",
"CQsIFB4bEAoTEx0bFBsXJSwuMSwpFyUxOy0wHysgOhoSMjA5MAkULTpEKzpBOjAcDjFFKzsiKiUrMTk6OUNDOTFFQS05NSEXGxwXChcKEhoNISArKxooQTg5KjAgLyUsLBQUFxAXFh0XFxcRCQwQEREJDAsRCxgP",
"AAAAAAAAAAAAAAAAAAABAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAEAAAAAAAEBAAAAAAAAAAAAAAACBAQFBQUFBAICAAAA",
"AQECAgEBAQEBAQEBAQEBAQICAgICAgICAgEBAgICAgICAgIBAgICAgICAgMFAgIBAgUEAgIEBgYCAwICAgIDAgICAgICAgIFBgICAgICAgICAgICBgQCAgICAgICAgMGAgICAgICAwMEBgICAwQDAwIDBgYDAwMD",
"AwUHBQYDAwUDAwUDBQcFBQUFBQwHBwcJBwUFCAgICQgHEAkLCAcIEAgJEQwJCAkRDwgHDAcJCAcJJAoQEwwICAkJCAwLCAgICAkMCwgJCQkTCQgIDAgJCQUIAwkJBRERCQkIEwkLHSAeGw4QCgsLCh0VHh4vKy9H",
"REcuRDEzQTAlITopKCgbKygwMxYqLSE7HigrJhosQRcPEjJBISw1Kx4uNTg3QkU6MSguMCIPHRgLCRoVFx8lIS5ERCoeRjE9KRQhKiESHR4hHhkOFw4SDxASHwwMFxIeFA0hGQAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAAAAAAAAAICAgICAgICAgEBAAAAAAAAAAAAAAAAAAEBAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAICBAUFBQUDAQAAAAAAAQEBAQEBAQABAgICAgIC",
"AgICAgIBAQICAgICAgICAgICAgICAgICAwICAgIDAgICBgYEAgICAgICAgICAgICAgICBgUDAgICAgICAgICAgYEAgICAgICAgIEBgICAgICAgMCBQUCAwIDAwMDAwYEAwMDAwIDAwUFAwMDAwMDAwcGBQUFBQcH",
"BwcHBwgFBQwLBQkJCQgHCQkJCAkFCQ8JBQgFCAwIBQkJCQkJBQUREwkJBwkMCQgJCQUODA8IDBEJCQkJCxMJCQkIDAgQHQgFCAgQEQoLCAkJCAkfHx8XDxgQCRMTJBcgLUQxKURDNSktRjsxMSpBDhsvNCsrOjAw",
"LRYWGRk7OTo5LhINKxorREFGMRolISw6Qzo6NjE6RyEOCwsICB0YEhUlHywtJhcWHhJFOCweFRsNHxcfHx8XCxEKFw8QHiEcIB4XFA8MChEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAABAgMDAwMDAwQEBAQEBAQEBAQEBAQEBAQEBAQEBQUEAwICAgIAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAABAQEAAAAAAQIEBQUFBQQCAQAAAgEAAQACAgICAQECAgIBAQECAgICAQECAgIBAQICAgIC",
"AgICAgICAgIDAwIEBgYEAQICAgICAgIDAgMCAgICBAYEAgICAgICAgICAgQGAgICAgICAgICBgYCAgMCAgMCAgYEAgMCAwMDAwUGAwMDBQMFAwUGBQUDAwMFBwUHBQUFBQcHBQMJBwgFBwUFCQkFCQsJCQkJCQgI",
"BwgKCwUFCQkICAgJBwkJCAUJCQUJGAgICQkJCxAFCRMPCAkMCAkJERAFCAkFDhEJCwwFCwwJDBELCQUMCwwBFyUfIRIKCg4aKCslKB4wSEQ2OTIgO0YUFR8iFA4yCkkNRERIRCUWEg4tHCkxMTMSSRUfDR8mChkK",
"Jh8hLSsyRDY5Lx4PDgoJDBAODw8VIBQeFxceKCIlOTUwIRUbIR4hGBkODhkLFCEVDR4UDhcXCQsQDAkJAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAgIDAwMDAwMCAgEBAAAAAAAA",
"AAAAAAAAAAAAAAAAAAACAgICAgMDAwUFBQUEAwMCAgAAAAAAAQAAAAAAAAAAAAAAAQEBAQEBAQECAAACAgMFBgYFBAQCAAICAQECAQIBAgIBAQEBAgICAgEBAgIBAQEBAgICAgICAgICAgICAgIFBgYEAgICAgIC",
"AgICAgICAgICAgUGAgICAgICAgICAgIGBgICAgICAwMCAgYEAgICAgICAgIGAgIDAwMDAwMGBQMDAwMCBQUHBQUFAwUFBQcFBQYFAwUHBgMHBwUFBQcHBQwHCQgIDAkJCAgHCQUIDAwHCQsRCQUJCQkJCAwIEQwM",
"ChAFCQkJCQkLCQsJCgsXCwUICAkMCAgJBxAJCAgICRAMCAkMCQkJEREKChofISEUDxMKDg4cRUQ5Ojk1OjAoIRwsBwklKxYeKQ4IAStIOTobFB4aJQolKiYPDyUZCRMYLSsaFRcuHyhGLjFFLB8tKCwUHRAJCRAX",
"IB4PDQ0mFw8lFDE4QRccDSEbHRkSFx4lLB8fEhkTCAsMGQsXCwkLCwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAECAwMDAwICAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAICAwMEBAUFBAMCAgAAAAAAAAAAAAAAAAABAQEBAQEBAAEBAAEAAgICBAUGBQYFAwICAAACAAABAQEBAQICAgICAgICAgICAgICAgICAgICAgICAgQGBgYCAgICAgICAgICAgICAgICAgIGBAICAgICAgIC",
"AgICBgQCAgICAgICAgMGAgICAgICAgIEBgIDAwMDAwMDBgQDAwMDAwMFBgMDAwUIBQMJCQMDBQkFBQUIBwcIBwUJDAUIGA8FCQgICAUICQgMDAkJBQwPDAkICAwLBQkJBQ8KBQkJCREFDg8KBRkSCQkQHgkMCQgJ",
"CAkJCQkFCAkJCQoJJBMJCQsJCAUICQkOHg0SFxsbDgcKEBkuRDg1NS1GIB8bGh9GLisOHiI1LAsrOUYsMy4SFysJIjk0Ex5BQTA6MC4mRTkgFRcNGiwtLi46NUE8HhIJBQsOFxIQFS0gEiEhGAswODkPHR8XFiAs",
"LB4lGxAOExEgGwwKCgoTDAkJCgkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEDAwICAgAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQMEBQUFBQMC",
"AQAAAAAAAAABAQABAQEAAAEAAAICAgEAAAAAAAIDBAUGBgYEAwIBAAAAAQECAgICAgIBAQICAgICAgICAgICAgICBAYGBgQCAgICAgICAgICAgIDAgICAgIGBgICAgICAgICAgICAwYEBQICAgICAgIEBgICAgIC",
"AgICBQUCAgIDAwMDBQYDAwMDAwMDBgUDAwUFBQMFBwYDAwwLBQUFCQcHCAkFBQUFBxEJBwkJCAgKEQcLGAsICAULDgkIBwkJCREMCAULCgUTCQgMCRAHChEICQ4JCRkICQkICwsFCAkJCAkJBQkJCxcLDAkJBQgJ",
"CQwLECUcFxgOGRkOH0ExLjpEOi0iOyUaHyVFQS5EREQ6RDkwIR87QTkiLR4eCyktFC46REFEQ0dFMTFDOi8gLBshHy05OUE6PCUoDh0KChJKCRYoFxIWFRQKOzg2LCUzLCUWDxUQGB0RDw4LEAoJDhUJCwsLDAsM",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAQICAgIBAQAAAAAAAAAAAAAAAAAAAAUBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAABAgMFBQUFBAIAAAAAAAAAAAEAAQEAAAAA",
"AQAAAQABAQECAgECAAIFBwYGBgYFBAMCAAABAQAAAAEBAAEAAAAAAAICAwQGBgYGBQICAgICAgICAgICAgICAgICAgICBgQCAgICAgICAgIDAgYGAgICAgICAgIBBQYCAgICAgMCAgYEAQICAgIDAgYFAgMDAwMC",
"AwYDAwUHBQUGBgYFBQMHBwUFBgcHBwcFCQgICQUJBQkJCAgHCQkJHQUFCQkJCwkFCAkJCQkPCAkMBQwMCQgJCQkJCQodCQoJCAgIDAgJDAkMBQ8LCQkMCQgJEwsQDBERCAkICQwTEQpGIQ0XEBMJDhsaOkQ2QS0h",
"ISguIDEpNUM2LDA6RDo6OjMZLEQpLDEtGhIpKwoyRTk6OCUfRUNERURDMC0rDhI7Li48RUVEKiEVEhslJRIUFB4XCwsPGipENi4hGBIREgsLGQ8ODAwKCwoZDAsZCRAOCgoOCgAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAABAQEBAQAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAQAAAAACAgMFBQQEAgAAAAAAAAAAAQEBAQEBAQEBAQEBAQEBAQAAAAACAgMD",
"BQYGBgYGBQQEBAQEBAQEBAQEBAUGBgYGBgUEAgICAgICAgICAgICAgICAgMCAgICBgYCAgICAgICAgICAgIGBQICAgICAgICAgYEAgICAgICAgQGAgMCAgIEAwMGAgMDAwMDAwYGAwMFAwUFBQcFBQYFBQUFCREI",
"BwcHBQwFCQkFBQURBwwJCAkHCQcJCQcMCQkJDAkJCAcJEwgJCQULCgkJCQwKCQkMCQwKCQgJCQkICgsHCAkOCwUICwoJCQkOCwMICwULDgUJCAEVLgsLCgoJExgrLC5BOiogFRceJQ8ZMEQ2Og4LHjk6OkEtLzoO",
"IRotKCgPGx4gKzExREQwFhsrREQ5OEQwRS4WEisiQUU5MS4wLA8XHEEhCw0aFRIVJSYrSEgmEBQVDxAODhASDAodEB8bCxgZEQ4QEBAJCwsAAAAAAAAAAAAAAAAAAAAAAAABAQAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AQMAAAAAAAAAAAACAAAAAAAAAAAAAAAAAAMBAAAAAAADAQAAAAAAAAAAAAAAAAAAAAAAAAEBAAAAAAAAAAAAAAICBAQFBQMCAAAAAAAAAAABAQEBAQEBAQEBAQACAAICAAAAAAABAgIEBAQFBgYGBgYGBgYGBgYG",
"BQUEAgICAgICAgICAgICAgICAgICAgIDAgICBAYCAgICAgICAgICAgEEBgICAgICAgICAgMGAgMCAgICAgIFBgADAgIDAwIGBgQDAwMDAwMGBgUDBQUFAwYGAwcHBQUFBQcJCwcHBwUJDAgJDBEIEQgRDAgHCQsI",
"CQwHCAkJCwkHCQgJDAwICQkKCQwMCQwJEwgMDggJCwwICAkJCxAMCQkJBQMJCwkZCggDDAwICAkFCA4HEAwQCxodFxoSChgsRUQ5RDouGyUlMCsQEjFENSYOBTQ6OTo6HhcvDiggHyYwEhIVFzAwMTk1MBsfKEE5",
"OTAlOTorJRQsKyoxOkFERClGEh4tDhcKDiEoKB8QIUQ2Lg0LEA4VEh0XDA4dChgOGRMODgwQEAkRCQwOAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAwAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgIEBQUDAgAAAAAAAAAAAAABAQABAQEBAQABAAACAgIBAAACAAAAAAAAAQICAgICAgICAgAAAQECAgICAgICAgICAgICAgIC",
"AgICAgECBAYEAAECAgICAgIDAgMBBgYCAwICAgICAgIGBgICAgICAgICBgQCAAICAgICBgQDAwMDAwMFBgMDAwMDBQUGAwUHCAMFCQUHBQkHBwcHCQkFCAsJCQUJCQkdBQUFCQkMDAkJBwUFCQkJCQwSCAkJDBEI",
"CAgJDAkJDBAICQsRCQkIEwkFDwoJCQkMCwwFBQkMCwkICAUJBQsPCRgMHQkQHC4hEhohKjY2REUsJS06MDwlCiwpQTUiEh4wKTE6OisOGDIrGgocKRkhLiUwLi1BMTssGhIqRygOFhYhLzk5LCssKUE1RDVHKRUe",
"LxgVFB8hGAoeFSU5OisXDhAhGhMPGA8iFBgKER0HCgsJCQwKDgwLEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAQICAgICAAAAAQAAAAAA",
"AAAAAAAAAAAAAAAAAAEAAAAAAAEAAAAAAAAAAAAAAAACBAUFBQQCAAAAAQAAAAAAAgEBAAAAAAAAAQEAAAIBAgEBAQIAAAECAAAAAAAAAQIBAQEBAgICAgEBAgECAgEBAgICAgICAgIFAgYGAgICAgICAgICAgIC",
"AwYEAgICAgIBAgACIwQCAgICAgICBAYCAgICAgECBAYCAgMCAgMDBgUDAwUFAwMFCAMFBQUFBQUIBxEHBwkHBQkIBQkJBQUHCQkICAkMCAcJDAwHCAUJDAgJDAwMCQkOEwkJCQkICQwLDAkJCQsMCQwMCQkMEwkF",
"CBALGQkMCwwJCwwJCAsLEQwMCQgFCQUIEiwrDxAyNjY4NjEzRitBLiYsLCwsMDExMxVGPDEpLTIoISscCSEdECEoKyFGKzssLSkrLRQWLSkoHyUVHjMxM0EtHiktMjk5NkEgJUEeFBcdDAoPEhIPNUQtChgKEhAS",
"CgoQHw4YCAwMCxcKDwsLEBATCQkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQIDAwMDBQUDBQQDAwUFBQUFBQUFBQUFBQUFBQQDAgIBAAAAAAAAAAAAAAAAAAAA",
"AQAAAQAAAAAAAAAAAAAAAgMEBQUEAgICAAABAgEBAQEBAQEBAQEBAAABAAEBAQECAgEBAgEBAQEBAQEBAAECAgICAgIBAQEDAgIBAQICAgICAgICBAYGAgICAgICAgICAgIDAgYFAgICAgICAgICBAYCAgICAgIC",
"AgUGAgICAgICAQYFAgIDAwMCBQYDAwMFBQMFBwUFBQMFBQMICAUHBwcHCAcHBQUJCAgJEQkFBwwJEAkMCQkJCAkJCRAMCwwMDAkICxMMCREJCQgPDhEICQwOCQkJCAgICQwJDBMMBRIRCQwKEAkICQwTHQwICAkQ",
"CAkFCw4aJRUeQUM4NjEzHC06LRoXGAkTEBQlLDMpJi4tLiw7JSgtDx0tIQcZLSwfGxcOKEYmLigeJR8aFxMJDhQZFRQuMCwcKkc8MUEwLjsmEg4LEAoYDwsQCkFEMhYSDiETHQ4PEBALCwoLCxkKCwsLCxMJCQwL",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAICAwMDAwUDAwICAgEAAAAAAAAAAAAAAAAAAAAAAAICAgMDBAUFBQUFAwMCAAAAAAAAAAAAAAEAAAEAAAAAAAAAAAAAAQAAAAAC",
"BAUFBAMBAAAAAQEBAQEBAQEBAAECAQEBAQEBAAIBAQEBAQEBAgEBAQEBAgIBAQEBAgICAQICAQECAgICAgICAgYGAgICAgICAgICAgICAgMGAgICAgICAgIDAgUFAgIBAgICAgIGBAIBAgIDAgIGBAICAwMDAQYG",
"AgMFBgMFBQkFAwUFAwcJBwUIBwcHBwcHCAgHCAgICR0JCREMCQUHCQkJCAkRCQkRCwwMDBEJBwkMDAwMCQwJCgwTEAgJDAwMCQsICQkJCQgYEQkMDAkICgsFBwkFBQsKDA4ODggMDAkOLSsULTVFRDUxLC1HKxkB",
"SkpKSklJAwULKDAqKSsrKyUSKBYlLSEJHRYXEh4hGx4hKDssJQoAGANJAEoKSkoJGygwIDsrLSsuMCgKAAwNFxULGQ4LEAo8REEUFxcXHRkOCxAKDA8bEBgLCQsKCx0LCQsKCwAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAACAgMDAwMDAgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAgMFBQUFBQMBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgMFBgUEAwEAAAAAAAABAAAB",
"AgABAAAAAAAAAAAAAQEBAQEBAQEBAQEBAQEBAQACAAUDAgEBAgICAgICAwYGAgICAgICAgICAgICAgIGBgICAgICAgICAgQGAgICAgICAgIEBgICAgICAgIFBQIDAgMDAwMGAwMDAwMDBQYHBQUFBQMHEQUHBQYH",
"BwcHCAcFBQgHCQwMBwkRCwkJCQkJCQkLDAkJCQkMCQwRCQkHCQwMDAsTCQsQCwkJDAoJDAwLCAkICwsICwgJCB0QCAkFCAwJDAsJDAkTGggTCxAIHTAxJSU6RDoyK0YwKwoFBwFKSgNKSQVKS0kbMUExKiwcFBcf",
"HiIQEw4ZDhQVGBQfIDMuRgpJSgBKCQBJSQAASQgPKCshHypHKyYbEwsMCgoOGRMSFRIQK0RBFgoQFw8ZEA8LEyUPCwwKDAkJChAKDxcTEQkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAECAgMD",
"AwMBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAQIEBQQFBAMCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEDBQYGBQMAAAAAAAAAAAEBAAAAAAAAAQEAAAEBAgIAAQEA",
"AQECAgEBAQEBAgEDAgECAgICAQECBAYGAgIBAQICAgICAgICAgIEBgICAgICAgICAgIGIwICAgICAgICBgQCAgICAgICBgQDAgMDBQEFBQIDAwMDAwUGAwUFBQUFBQUFBQUnBwgHBgUICQkHCBEMBwkICQcJDAkM",
"CQcJEQcJCQkMCQkJCQgJCQkICREQDAkMCwsMDAkJDAsJDBcICQsKBQUQCQkJEAkJBQkIBQkJCQgFEAsJCAkJCQoYFR8tPEExLiEwOxlKBQcACyYfCQABDgVJSRgyRTlBLSgfHxocFxAbFRIXFxkWKy0qHwgFSgAL",
"BwMKCAMACAgBCRsvJRwpMUFFLwoOFRAKGxIVHg4KDitFOh4LGRQKGRAQChASEQgQEAwRCgkRCxAYDAsJAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQECAwMCAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAADAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAACAgMFBQUFAwIAAAAAAAAAAAEAAAABAQABAAAAAQAAAAACAgUFBgUEAgACAAAAAQEAAQEBAQEBAQEBAQEBAQEBAQEBAgIBAQEBAQECAgEBAQEBAgAE",
"BgYEAAEBAgICAgICAgICAgICBgQCAgICAgICAgIDBgICAgICAgICAwYCAgICAgICBAYCAgIDAwMCBgUFAwMDAwMGBQMDBQUDBQwFBQUIBwUHCQYHCAkMCQkIHQoHCQcHCQoMCQkJCQkIBwkLDwsJCwkJDAwJCQwJ",
"CAkTDAwJEQsMCQwLCQkMCQkKHQkJDwkJCQkLDAwJBQUHCQUMDAkJCQkICQwRBUkLKypBQS4sLRQZEBoTISAVCxgFBRADSUpLFjU2Q0UpIixGFxUXFiAhISEaLDwxLAUIAAsMEgoFBQkKBQwQAQohLTwoJSk5REEt",
"Gh8lHg4YGQkZDwkhOkcmDgsJDhcZDg8KCh0LCwkQFxkLCgsICgkQGQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEBAQEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAACBAUFBQMCAgAAAAAAAQAAAQEBAQAFAgABAAAAAAAAAAIEBQUGBQMDAgAAAgAAAAABAQICAQEBAQEAAAECAgEBAQEBAQICAQECAQABAgIGBgYEAAEBAQICAgICAgICAgICBgYC",
"AgICAgICAgICBgYCAgICAgACAgYEAgMBAgICAgYEAgICAgMFBQUDBQMDAwMFBgMFAwMFBQUFAwUFBQUHCQcHBwcIBwkJCQwJCQkHBwwMCQkHCQwJBwcFCwoIDgoICQwMCQsLDA4MCAkLEQwJDAwMCwkODBEMDAkJ",
"BQUPCAsMCQwFCAkJCQUMCQkMDAkICQwMCAsHCUYxQSsmMiosChUXCB4OCwUkAAEkBQFJSghBODg2Mi4sRjsfISAeHiUmHyk6Mg5JAEkOCQgFAwUDDgUACxEQJS4wLCwwQUExOh8vIhMLEAkKDxgQFDpBLhAMDRUO",
"DwsODBIdCQkJCxcJCQkLDwoPIQoAAAAAAAAAAAAAAAAAAAAAAAAAAQEBAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAA",
"AAAAAgIFBQUFAgAAAAABAAAAAAAAAwAAAQEAAAAAAAEAAAAAAgQFBgYFBAIAAAAAAAABAAEBAQABAQEBAgIBAAEBAQECAgEBAAABAwYGBgMCAgICAgIBAQICAgICAgICBgYCAgICAgICAgICAwYCAgICAgIBAgIG",
"AgICAgICAgIGAgMDAgIDAgYDAwIDAwUFBgUDBQMIBwkFBQUFBQUFBwcHDAUJCAkMCQcFBQgICREJCQkJCQwJDAsJBwkICQsJDAsLEQwLCxMMCwsMERELCwkdHwsLChELEQkMCQgIDAgTCwgLFREJDAkBDxsLCwMJ",
"CAwMESQbFhVGNTktKkU6MBIfCkkIEQUIAQADAwUFAAVJIDg3Q0UyKDsrLB5GOy0iISUqOisBSUoFDAUIAAAFCQNKSQsKDCgrMCotQTFBRTUyDRIdCwkXFxAYChc6OisYHxUKEBAKCgsQEBARCwsPCgkKCggIEw8I",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACBAUFBQMAAAAAAQAA",
"AAAAAAAAAAAAAAAAAQEBAAAAAAADBAUGBQYFBAICAgAAAQAAAAABAQICAgAAAQABAAAAAgQGBgYFAwABAQECAgICAgIBAgIBAgIABAYCAQIBAgIBAgECAgYEAAECAgICAgAFBQICAgICAgIGBQACAgMDAgQGAQMF",
"AgUDBggGBQUFBQUFBQUFBQYFBQcICQUJDAUHCQgICAcJCRERCQkLCQkJBwkLCwkMCQkJCwkTDAwLCwwJEAsYFwkJDgsICRALEQkMCRAPDgUKDAgLDAkICQoMCQkFERAPBQ4ZCQgICQwKDyEeRUQ6LUVBMTELGxlK",
"CBEJBUpKBQkICwEJSgs1QjdFLS4tLi4uHi4wK0YoMTENSQBKJAsFAUkAAQUHCAUYDAUwKkE6KCsyOjU1RRULGCEQCgsSFw8UPEcvDwoLEA8OEAsLEAkLCgsREgoKBQoQDAkQCwAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgMEBQUDAQAAAAAAAAAAAAAAAAAAAAABAQEAAAAA",
"AgAAAgMEBAYGBgYFBAQEBAICAgIBAQEAAgIEBAQGBgYGBgQCAgABAQICAQECAgICAQICAQIABAYEAgICAQICAQEBAgQGAgIBAgICAgICBgMCAgICAgICBgIAAgIDAwIGAwIDBQMDAwcFBQUFBQcFCQUFBQUGBQcH",
"CAcIBwgFCQgICQkMCQsbCQkFEQkJCQkMCQsMEQkJDAsRDAkMDAwLCQsLBQsLEwkMCQkQEAkJEQkIDAoJCQkMEBAREQwFCAkFCAkJCAkQDwgIBQkRCR0VMEVFKS5BQTo5HhkhBQkSCQVJSQAFCEkBC0oKMTg4MTIx",
"MDEyMSwuKSwmKzoxDgADAEoFBQBJAQEABQUMDwANRTIpRyUePDo5OUcSCxAlDxAQDAkRCkExKxILCwsLCSAXCwkLDx0JCAkQEQkKCgULEAsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAwAAAAAAAAAAAAAAAAAAAAIDBQUFAwIAAAAAAAAAAAAAAAABAQEBAAAAAAABAQACAgAAAgIDBAQEBgYGBgYG",
"BgYGBgYGBgYFBQQCAgIAAgECAQIAAQICAgICAgIBAQICBAYCAgICAgIBAQIBAgIGBAICAgICAgICBQUAAgICAgICBQUBAwMBAwEEBgIDAwMDAwYGAwYFAwUFCQcDBQUGBQcHBggIBwkJBwkICQkJCAsMCR0JCQsJ",
"CQsLCAkMDAkJCQwLCwwdEQsRDAkJGxUTEQwMCQ8KDAsJExMTDBAQCQkJDAgFCQsRDAkFCwkICQkMDAMFCQwICgwXMEQ6MTswQTE8RDkeCg8IAwsLAAAFBQAFDgsABStDNjFHMS4wMzAtMi4vKyA8MBlKCA4BAAAD",
"AwABBQMIEA4bMUclECAvJS4wMTVIKA8LChkKECEeDTRFMC0NEBAIDBAKEAwLEBAJDAsMCQUICQkYCgUIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABA0oAAAAAAAAAAAAAAAAA",
"AAAAAAAAAQECAgICAgIBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAACAgQFBQMCAAAAAAAAAAAAAAEBAAAAAAAAAAABAAAAAAAAAAAAAAAAAgICAgICAwMCAAEAAgAAAQAAAQECAQIC",
"AgICAgICAgICAQEABAYEAQICAgICAQACAgIGBgICAgICAgICAwYCAQICAgIBAgYDAgICAwIDBgQCAwMDAwMGBQMDBQYFBQkFAwcRBQYHBgYICAwLCQkMCQgICAcKEAkLEQwJCQkMEQkMDAsMCRELChEMDAwLCQkT",
"CwshDAwLEQkdCQoQDAsMDAkLHQwJCwwMCQkJCQUJCwoMGQkMEAsJDAkLDgsLJUQ2OUUtMDNGITw2OR4KDAkJAwMBAElKDBELEQsbR0EyMi4rMDoqLTAsLCUlKCsOBQkJBUkBDAAJCgUACw8cNTAfFQsJHh4aLDw6",
"OS0aCg4QCRUxMiIhHDApFxALCw8PCwsJGQ4KDAkIBwwFCQsRHQoIDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgMEBAUFBQUFBQUFBQUFBQUFBQUEBAUF",
"BQUEBAMDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIEBQUFAgAAAAAAAQAAAAAAAAAAAQAAAAABAQABAQEBAQEAAAAAAAAAAAAAAQEBAQIBAgICAgEBAQEBAQECAgIAAgICAgICBSMFAAICAgEB",
"AgIAAQAEBgICAgICAQICAgYEAgIAAQICAQUGAQMCAgICBAUDAwMDAwMFBQMFBQMDBQcFBQYFBQUHBwUFBQcHCAsJCQgIBwgLEQcHCQkJDAwMDAkJCQkRDAkRCwsMCQkLDAsLCRERCAwREQwJDAwRCwwLDAwJDhkM",
"CQ4MCQgIDAwXCBkXDAoMCQkJCAgJEQsJDDA2NTktO0ErGyAwMDo1PC4eEAwFAAETEhUXEBsdCyAzKisiLCoyKyslKCUlJSEhHQsJBx8hEgoJDSgeOykyQSshCxIZECUmHRYoMEUxEgoKFQ4LJAgIITkyLSEOCgoe",
"DwwJCRALDAwJCAwLCQkJGAsMDAoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAgMFBQUFBQQDAwMDAgIAAAAAAAAAAAAAAAAAAAACAgIDBAUDBQUFBQUEAwAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACBAUFBAIBAAAAAQEAAAAAAAAAAAEAAAAAAQEBAQEBAQEBAQEBAQEBAQEBAAABAQECAQABAAABAQEBAAEBAQACAgICBgYAAAEBAgIBAQICAgACBgICAgICAgECAgQGAgIB",
"AQICAQMGAwICAwICAgUFAwMDAwMDBgMDBQUDBgYHBQUFBgcFCQUFCQkFBwcHDAgFCAgJCwwJBQkJCQkJCQwMCREMCwkJDAwRCxELEAwKEBALDAsLCwsJCwoMCQwJGg4MCQoQDAkMCwgFBQgJEBARCwsICAkICAkJ",
"CQkXCA86NjpBLSw7HhklLRshRitBNTpFOUE6RERELhYYCg4hKys7RiYuLzsoRhYfIRISDxgdEg4uRUREOTE6KkFBKTsXGxIOEg8VHBY0KzAxQR8VCwwLCQwUGikrIikeGREMCQodEB0KCxAKEQkICwwJCQkJCQwJ",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAgIDAwMDBQMDAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQMEBQUFBQUDAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AQAAAAAAAgQFBQUEAgAAAAAAAAAAAAABAQEBAQEBAAAAAAAAAAAAAAEBAQAAAAEBAQEBAQEBAQABAQABAQEBAQECAgIFBgQCAAABAQABAgIAAgICBgMAAgICAgICAgIGAwIAAQECAgEGBQIBAwICAgQGBQIDAwMD",
"BQUDAwMFAwUGBQUFBQUJCAcFBQkKBQcHBwsJCAkICQkIBwsMBwkLEQwMEAsJEQwJDAwMCxMLChgTGBgLGQwLCwsLCRAKCQwMCgsTDBAeCwwMEwkJCQkLBQgMBQUMCQkJCQkJCAkJCQUlOTk6LBo7Kx4FDhwdLDsX",
"IR5GJio1Qzg4OS0sDxAKGiYmOyglJSAiLB8UIRYVEhkOCxgURjA1NUU1LSsfJSwhHg8VHCYOGR8YChcuMToUDgkLDgwKKDwrJSs8HBAICxEKCwsJDBEKCQ8KEhAJEwwKDBUJDAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAQEBAQIDAwMDAwMCAgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgMEBQUFBQQCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQEAAAIEBQUFBQQAAAAA",
"AAAAAAAAAAAAAAAAAQEAAAAAAAACAQAAAAEBAgEBAQACAQEBAQEBAAEBAAAAAgUGBgICAQABAgABAQICAQICBgUAAgICAgICAgAGBQIBAAECAAEDBgICAgICAwMGAwEBAwMDAwYFAwMFBQMIBgUFBQUFBQcJCAYH",
"BQYnCQcIDAkHCQkJCQwMCQkJEQsMDAkRCQwMCQsMDBgQEQwJEQoRCwsRCgsLCwsJDAsMCwoLEQsKCwsQCwwJCQkJCwUJCR0KCQkJCQgMCAUJCwoBFjk5QSIaMjIrIUYrKBcUGh8UIR8cJSwtQUUyFh0QEkZGHiU7",
"HxolIi4VFg0fJh8QEAsOFCIrLisgFCElFBcXGRIWHiUpJSUrHgUTRikzIRAMCx0IDhcMC0YzKUYPGBAOCgsJCwsQCwgLCgkQDAsLEBAMDggAAAAAAAAAAAAAAAAAAAAAAAAAAAEBAAABAQEBAQEBAQEBAQECAQAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQMDBAUEBAIAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAEBAAAAAgQEBQUEAgAAAAAAAAAAAAAAAAAAAAABAQAA",
"AAAAAAICAQAAAAAAAAAAAgEAAAEBAAECBAYGAgEAAQEBAQEAAAACAgQEBgUAAgIBAQEBAQAEBgACAgIBAgIABgMAAwICAgIEBQIDAwMDBQYFAwUFBQUFBwUFBQUFBQcGBwcFDgsIBwkJCAgIBwkJEQkJCQcJCQkQ",
"BwkJDAsRCxEMDAwKCwsREQsKCgoMCgsdCxALEBALCwwLCgwRDAkLCgsKGw8MCAkJCQULDgwICQkJCQgJCQUIJB44NTMhO0cvKTAwKS0oHhkXH0YlDR47KTw7FhghIRsbFSEhGhQaJg0SGxcVGxsXGB0SIRIiQSse",
"FhoVEhcPCBgSDyYuPCosJiwaJSpHIg4OFxgKGQwDExgVLixGDxMXGQsLCR0KEAsJEBkVCAkJCQsLCBEIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAwMFBQUDAQAAAAAAAAAAAAIDAAAAAAAAAAAAAAAAAAAAAAIDBQUFBQQCAQAAAAAAAAEAAAAAAQEBAAEBAQEAAQEBAAAAAAEBAAACAgAA",
"AgQGBgUDAAABAQEBAQEAAQAAAwICBgUAAQEBAAEBAQECBgIBAgEAAQICAwYAAQMCAQIDBgICAwMDAwMGAwMFBQUDBQcGBQMFBQYHBQUFERAJCQgJCQgICQkJCQsJCQkJDAwLEQkLCxELEQsRDBAMCxALDwoQDgsL",
"Cx0QCw8SEBkKExMMCwsTEQsRCwsMCwsLCwkJBwUMEwkJDAkIDAwFEwkXCQkPPDowLis7DyY8MikeJSwSCw4hFh4mPDFGRhohOyEYEBIUEhoXEhohFxsXGBAOGRIQFRcODhUvJRUSIB4dCRIoLCwvMC0iJSUuLS0w",
"OkEUCQ8YEA8LCgoJGC0pKA8LCBEQCwwJCRELCQsdDAUJDQsMHQkICQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgIEBQUFBAIAAAAAAAAAAgAAAAAAAQEAAAAAAAIAAAAAAAAAAgQEBQUFBQMDAQAAAAAAAAAAAAAAAAAAAAEBAQEBAQAAAAAAAgIDBQYGBAQAAQEAAQEBAQEBAQEBAgIC",
"BgUAAAABAQEAAgEABgQAAQECAgAAAgYCAQICAQIBBQUCAgMCAwIHCQMFBQUFBQYFBQUFBQUHCAUFBgcFBREMCAcJCQwJCQkHCQwMCQkMDB0MDBERERERCQsSCRMKCxAMHRcQDwkKCgoXDgoKCg4MCQoMDAkMCwoM",
"EwsJEwsMCQkJCQoLCQkJCQkMCggFDgwMCTA1MDwuGgtGPC0xJRYeHh4QChorKSsrHh5GKygeGg4ODxgSEhkUFxUNEg4KDhMJDxUeFhIQISEUFAoSEBUtLDsmJSEeHg4fKS4uMDpFFAkJDAkMDAsJBRApKzsNDwkT",
"DBMLChEJCQgICRARCwkICQUJCQgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAEAAAACAwUGBgQCAQAAAAAAAAAAAAAAAAAAAAAAAAAEAgAAAQAAAAACAgQFBQYGBQQDAgICAAAAAAAAAAAAAAAAAAABAgMFBQYGBQQCAQAAAAICAgEBAQIAAQEBAQAEBgQAAAEBAQEBAQEABQUAAAICAgEC",
"AAYEAQIBAQMCAgYDAwMCBQMDBgUDAwMDAwUFBwUFBQYHBwUGBwYGCQkLCAoMBQcMCQkHCREJCwwJDAkLCwwRDBERDAkRDAsTCwodFwsQCgsQCh0KEQoQEAsPFwwRCwwICxkTEwoRCwkJGRMJCQwLHQwJCwwICRAL",
"EAgJCQkvOjAsHhcSOysaGkY8MC4uKxccKy0mHh8gKywmJRUNDgoPFxINGAoOEh0KDhMJChMSFSEsICYWGx4XGRISJRoSEhsLICwZDjs7KDBBQQ8QEAsMFxcFFRQULiwoIRALEgwFCxITCQUJCQoZBQkKCQwFChMI",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIEBQUFBAIC",
"AAAAAAAAAAAAAAAAAAAAAgEAAAAAAAAAAAAAAAAAAwMEBAUFBgYGBgUFBQUFBQUGBgUFBgUGBQQDAgAAAAABAQEAAAEBAQECAgEBAAIFBgIAAAEAAAEAAQEABQUAAgACAgICAgQFAgIBAgIDAgUFAwMDAgMDBQUD",
"AwMDCAcFBQwFBQUGEQUFBwcGCAkRCQUdDAgJCQkJCQwJCQwRCQwJDAsMDBELCwwJCwsLCwwLDg8dDhkKDwsKCwsZEBIXHQ4LCwoJDBAQCRALExMQCwoLCQkLCxEQEwkIBwsMCRIQEAwJFyoxLCEdDSUpLR4fHxsW",
"IQosKyYuRiE7Ky4uLyghFQoJChAdFBAeGRAdHQoICRAQFSEeHw0NFRYdFxIQEhYlICweISsuGwAKDSUrKS4LCBAQCAwNCwwKCiw7LA0LHRAKCQkMJAwMCQkJCAkMHQgJCQsJCQAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAACAwUFBQUDAgIAAAAAAAAAAAAAAAABAAAA",
"AQAAAAAAAAAAAAAAAAAAAQICAgIEBAQEBAMDBAMCAgICAAABAAEBAAEBAQABAQEBAQEBAQEBAAQGBQICAQEBAQEAAAEABQYCAAEBAQICAgQGAgIBAQECAQUGAgICAwMCAwUDBQMDAwUJAwUFBQUFBwcFBQgHBgcJ",
"CQgIBQgJCQkMBwcJCQkMCQwMEQsMEREMCQsQEwwRDBEKCg4QEBIXGA4QGAoLEAsXDw4LCwsLDBEMDAwKEQsMGBkMCwkMCAsQDwwRDwoKDAkLGQoLDBErPCshDBQqMUExMyhGJiwcKiocFBoPISUtMTEwLhcICgoZ",
"DhIPFw8XHRMICAgIHygsJSUlIR4gHx4hHx8eJSAmOysrMSYLBRo7OyIUEAsLCwwIFwoMSh46HCUWHBMJHRIJDRsJDwUQCxEJCwwFCQsICQwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwIAAAAAAAAAAAAAAAEDBQYFAwIAAAAAAAEAAAAAAQAAAAAAAQEAAAAAAQAAAAAAAAAAAAAA",
"AAAAAgAAAAACAAAAAQEBAQAAAAEBAQEAAQEBAQICAgEAAgUGAwICAgEBAQEBAgEABQYAAgAAAQACAgIGBAICAAICAgIFAwIDAwMDAwcFAwMFAwMFBQMFCAUFBgkGBwUFBwYHBQUIBwkJDAkJDAcMCxEMEQwMDAkL",
"DBERCRQLCwsTEQsLDg8ZEhcUHg0XDxgPChgPEgoQEAwLHQwMCgsVERMMCQkMCQsMDgoIDgkLDAoQCwwLCwwMEQwJISowLBUQJTxBMS0oLC4wMDItIUYgJi4xMDFBNUVGBRMMCBkYEAoKExEIJAVJESswQS0fHxQU",
"Gx8UEiAoJiwrLBwcLC4sJhUSHyUgGRAOEQkLDA8bBSlEKSs4RCwrDgUMCxcQCQkICwkFCAgLEggJCQgJAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAwQFBQUDAgAAAAAAAAEAAAAAAAAAAQAAAAAAAAAAAAAAAgICAgAAAAAAAAAAAAAAAQEAAAAAAAEA",
"AAEBAAEBAQABAAAABAYEAAABAQEBAAEAAQEABQUCAgEBAQIBAgIFBAICAgECAgIFBAIDAwIDAggGBQMDAwUDCAUDAwcFBQcGBgYGBwcHEQwJCAcJCQkJDAkJCwsMCQkRDAwQCwwRDBgOEBALGQoQEAoODx8lLCUg",
"HhcPHw4PEBIOEBAPFQsLERMLFwkLEwkMDBEJCQsLCQoJDAsIGQwKEAgJCRAQEBkrKyETCyJBOi0sLi4uKy8rKChGFywsLCo6OkU5MhoISUoDCgsLCQUMDEtJCCVBQToqLSUmLRwfGhceHyUmLChGHiAmHxQUFxUW",
"FQsJCh0MEQsJBS89ISEzNyEAERkHCQkDBQsMEBEkBwgIDgokCw8IBQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADBQUFBAIAAAAAAAAAAQAAAAEAAAAAAAEAAAAAAQAAAAEAAAABAAABAAABAQABAQAAAAEBAQEBAQACAgAAAAIEBgUCAAEBAAEB",
"AQAAAgAABgYAAAEBAQAAAQAEBQABAgIBAgAEBQMCAQMDAgQGAwUDAwMDBQUFAwMFBwwIBQUFBQYHBwcJBwkJCQkJDAkJBwkJCQkMDAwLHQsMEQsYCwsLChALEAoPDxYrMUM2KSAXFQ0PCwsXEhkLDh0RCgwMCwoL",
"CwkLEwwLCwwLDBELDAgLCQsTCRETDBAKEBAZDSwlITsyMTM7KzArLi4tKyUiOyUuLjA5RUU1OTFGFQsBSQkMCAgISkpKDB4wQUExQTo6OjkxMTApLCgsHCAlHx4cHyUlFBQeIQ4LEQkLCwsLCwVHMUYxRDoeKx4O",
"DAsMCQUFCQoQDAkJARgOJAwYDAUAAAAAAAAAAAAAAAAAAAEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgUFBQUEAwIAAAAAAAACAQAAAAABAAEAAAAAAAAAAAAAAQABAQAAAQEAAAEBAQEBAAAAAQEAAAACBAUGBQAAAQIBAgIAAAACAgACBgUAAQEBAAAAAQAFBgIC",
"AAEBAQADBgIDAQABAwEGAwIFBQUFBQYDBQMFBQYJBgUGBQcGBwgRBQkJBwkJCQwLCQcRDAkMDBEKEQwRERERDAsLERQfFSEhICYuMT0+PjYsIRcPEhQQEBgQDx0MCwsLDAkLCwkJEBAMCwkMCwsJCQodDAsLEg4L",
"DxAKCgoZCw8sKy4qKTAtLjAwKS0wOkE6RDZDSERERDlIOEQ6MC0lEggLEQUJCAABChwiMDE8LS4rHBw7LCItLCsuLCwoJSUlJSEWKBYhJSETDBAdERAJCREXR0csMDweLjglHRAdGAwIDAgBCgsIBQkQDgwJCwwI",
"AAAAAAAAAAAAAAAAAAAAAAEBAQEBAQEBAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgIDAwMDBQMEBQUFBQUFBQUFBQUFBQUFBQUFBQUDAwIBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAQAAAAAAAgACBQUFBQUDAwIAAAAAAAAAAAEBAAAAAAAAAAEAAAAAAQEAAAEBAAABAQEBAQEAAAAAAQQFBgUEAgAAAAAAAQAAAAAAAQAEBgQAAQEBAQECAgADBQICAgABAQACBgYAAgEAAQIFBQADAwMF",
"AwkFBQUFBgUJCQUHBQcMBx0RBwwMBQcLCQgLCggJEQwLCxEJEQwJEQsRDAsQCxAVFw8SDw8UHzA4Pz9COiklHh8XDhgPGQ8QDBAPCgoPEAsYCwsOCRETEBALCQwLCgoQEBAQCwoZDwoODBMPLC0sHB47Li8tMzMy",
"Mjo6OkVBMTwpKSkwMkFFNTEqMjsOCQUDAQAJDR8rKTIqKTwuLiwlOysuLSwlOyYlHx8fHx4YHRshHygaDAwMDAkLBQgLDQsONCgoKDsbCQgMER0JCBkQCQEAABkPCRAQCgsdEAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAQEBAQICAgICAgICAgIDAgIDAgMDAwMEBQUFBQUFBQUFBQUFBAQEBAQEBAMDAwMDAwIDAwMDBAQEBAQEBQUFBQUFBQUEBAIBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAID",
"BAQFBAUDAgIAAQAAAAAAAAABAQAAAAAAAAEBAAABAAAAAAAAAAAAAgQEBQYFBAIAAAAAAgAAAAAAAAAAAAEFBgMAAAABAQAAAgADBQIAAQICAAAABQUAAQABAQIDBQABAwMDAwYGAwUFBQUHCQUFBQYFBQwMBwcJ",
"DBALCgkJCQkJCwwJEQoMCwoLCwsREQsYEBESFBAdGBIUFB4wRTg4ODU8KzsgFhcVDxIPEBAdCwsYGgsLGQsKChERDBMKHQoQDgoQEAsRDAsMCw8LDhASGS5HMC0iLC4lJSwuMDwqPDEwMioqKTAwMTE5OToxQTAo",
"HBgBSgAIISI7LCkzMjEqMTEwMypBRyo8LS4rJhYhHxYhDRUhHywvGhELDBARDAkJCAMJFxIYKCgTExAJCQgJCSQLEggJCAULCQkFCQgICRMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAA",
"AgICAgICAgIDAwMDAgICAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAECAgUFBQUGBQUFBQMCAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIDBAUFBQUFBQQDAwIBAAAA",
"AAAAAAAAAAAAAAABAgIDBAUFBQYFBAICAAAAAAEAAQABAAAAAAAAAAIGBQIAAQAAAQACAgAEBQIAAQACAAMABAUAAQEAAAACBQMAAgMDAwMHAwUFBQcIBwYFBQUFCAcHBQcJBwsOCgUJCQkJDAoMCQkJDAsLEQsR",
"DAsRDhAMHw0TFxUXHhQfMDI6RDk1PCsqMStGRhYVDxIPEBgPHRAKCgsLCgoKEBAODhgPGR0QDAsLDAsKGRgKDgoODwooQTAsKyUgJSsyMTFFOTU5RENDRDY2OTY2NkU1RS0iLiwhC0kIDx8lKzAwJSIuKTAqKjAq",
"MCkuLikwKywsJhwlJUYsHiUtHBEQDgwHEwkLCQwLCwsOFDsfFBsUEwgTBwkJCAkJCAEJBQgSJAgJBQUFAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAICAwUFBQUFBQQCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAACAgMDBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQQEAwIA",
"AAAAAAABAgMAAQEBAAAAAQAAAgYFAgACAQEBAQAAAgIEBgICAQAAAQAAAwUAAAACAgIABQMCAgMDAwMGBQUFBQcFBwcGBQUHBQcJCQsICQkJCQUJCQkJCQkJDAkJCQoLDAsMCxERCgoKCx4eERIVFSEfJS0pMEdB",
"MjAqRD5EKyUfIRUaFQ4QDxkQCxAQEg4OEhIZEAodEBALCwwZEAsQEAoPEAoZEBMMKEVBKSkpKS4uLS0qRTlFNURERTo6MDpBOkFBLiw7KywXDgoACBkXGiUsNCU7LCwoLCwrKysrKywsJSgoJSUcKCw7KCUoKxII",
"CQsJEQkTEwkLCgwJExcuHzMqLR8FCQwICQwJCAoXAQkMCxEFDAsLCQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAwQFBQUFBQMDAAAAAAAAAAAFAgAAAAAAAAAAAAAAAAAAAAMCAAAAAAAAAAAAAAAAAAAAAAICAgICAgIDBAQEBAICAgIAAAAAAAAAAAAAAAAAAAADAAEBAAACAAACBQYE",
"AAAAAAEBAAECAAIFBQAAAgAAAAIAAgUAAAIBAQAAAwUAAQICAwMFBQUDBwkDAwkFBgUFBgcJBwcMCQkJDAkLCwkJDAwJCQwLCRgPCgkMCwsLCw4QHQseIgsPFBQXLyw7Ji0pKjI8Okg3QkEuJiUmIRQVFxUVFxcX",
"EhcPGQsQCgsLCgsdEQwLCxEYGQsOEAsQDgoKEUY1RUEyLiYrKy0wMjFBQTFHMC4wMTIzMDAiLSUcKy4WEhcKAAASIRYlFiUsLCY7LS4oKzEtKSsiLzslICAgICUgLy4pLiwZDhIKCg4SEwgSCQgLDAAOMzsWKS4l",
"CAcIDAUIDAgQFAgJCAkKCQgFBQgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAACAgQFBQYFBAMCAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAEBAQAAAAIFBgQAAAEAAAAAAAAAAAIFBAAAAAAAAAEB",
"BAUAAQAAAAEAAwUBAQEBAgUFBgMFBQUFBQUHBwgGBwYHCQcFCAgJDAkJCQkJCREMCwkMCwwQEAwLCQsLCwodEB0KHCAQDxcbFR8lJiwrMCkqKjFFOUQ6KjIzPDsmICEhFRISEhISDhAKEBAKEAsLExAQCh0LCxAL",
"GRAdDhUKDw8gOkEyMCoxMDMwMC0pPCoxMTExOjMrLikiKyYgKCYhGxcZCwgMCg4ZEhUhHkZGRiUsKysrLCsuKCAsKzslICYoLCspKSklCiESExkSIRAMCgkIDAgFCzAoFUEpLgwRCAUJCAgMEwsQCAkMCAoMCAgF",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwMEBQYG",
"BQMDAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAABAQEAAAABAAAAAAAAAQEAAAAAAAABAQAAAAAAAAAAAQIBAAAAAAACBAUFAwAAAAEAAQAAAAAAAAQGAwIAAAEAAAECAwUBAAEAAAICAgYBAQMBAAIDBgUD",
"AwUGAwYFBwwGBgYHBwkJBQcHCQwHCQkJCREJCREREQwRCwoKCwsLCxUZDAoQCx8gGBISFB8oICgsJiwrKkFFOjVBMjArLjwlJR8aFw8PEg8ZHRAdEBkKGg4QDhAQGBAQCgoLEBAKEBkQEBkUIDo1QUE6OkEqLisu",
"Ky0qMjFBRykrLiwmJkYSEiEVGBIbHQoTEBAQGQ8VFQ8SFRYgKCw0LCwoKCwrKCUmKSksLC8tKTA5KAoFERARCAkLEwwIBRgYGAguQS0oKCULCQkIDBMJCAkICwwMCwUREQUJCQAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAwQEBQUFBQQDAAAAAAAAAAAAAAAA",
"AAAAAAAAAAABAAABAAAAAQAAAAEBAQEBAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAAAgMFBQUCAAAAAAAAAQEBAQAAAAUFAgACAAEBAAAAAwUBAAEBAAACAgYDAQICAwECBQUFAwMFAwUHBQcJBwcFBwcHCAcHBwkJ",
"CQkHCQoOCRELEQsRCxEMEQsLEQ4PCwsKCgssIB4hDxIfHB4WKCssLTMtMTEyMTAtLTopIh8hIRcVFw8ODw8PEg4OGRIXCwsOEAoQGQsdEA8LCxcPGRUXDhdBOUVFNTVFPC0rLi4pLjAxLS0uKywlRiUhGhoUFxoh",
"FBcXGQoSIRQVHh8hFiEWHxwlJjQsJSUmJTssHCswMzApKSkpMhoLCwwICgkJCRERHQsJCQgDKyotGA4ICQsICAcJCwwMCAUFCQoTCAkJCQkAAAAAAAAAAAAAAAAAAAEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgMEBQUFBQUDAwICAAAAAAAAAAAAAAAAAQAAAQAAAAAAAAAC",
"AQEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAgIEBQUFAwIAAAEAAAAAAAEAAAACBAYDAAEAAAABAQECBAUCAAAAAAAAAgUEAgEBAwMCBQUDAwMDAwUHBQMFBwcJCQcHBwcJBwkJBwkJCQkMCwwMCxEMEQoLCwsLCwsL",
"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",
"IAwIBQMFBQUJBQEABQUMCQUMCQwAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgMEBQQDAgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAQIDAwUFBQUEAgIAAAAAAAAAAAAAAAAAAAAAAQUFBAAAAAAAAQAAAAADBQMA",
"AQEAAQMDBAcGAgUFBQYHCREJBwYFBwMCBgIHBQUHCRERCwsRCwwLCxELEBAYDxcVFRUUISwhFxsODg4OGBIQFSwgHzEpKiEUFxcUHiENHh8cRiw7JSwlRh8fIiYgHB4fJRYXFg0VFxIXEhcSFw8SGA0XDw4UFBAP",
"FxcPEA8NFCZBOTZDNjk2OUEzKyspIispJRcVIhwhJiUoJUYeGhohFhYlKB4cHx8WIR4eISEeIUYgHh4YEhMICiEXIR8lKywsLC0qMTFBKhQLJBELCQgJCQoOHQsICAAoMxUQISETCQwJBQMDBQkLBQgICQgDCAkJ",
"AAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAwQFBQUEBAMCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAgIDAwQFBAQEBAUFBQYGBgYGBgUGBQYGBgUFBgUG",
"BQYFBQUFBQQEBAMDAwMCAgICAgIAAAAAAAABAQAAAAAAAAAAAAAAAAICAgICAgICBAQFBQQEBQQFBAMCAQAAAAAAAAAAAAAAAQAAAAAAAAAEBQUDAAABAAABAAAAAAEEBQAAAQIBAgMFBAYFAwMFBQgGCREHBwkR",
"BwkJDAMHBwcHBQkMEQkFCQsRCxELChAOGQ8PFRcXFx8sFBcPDw8SEg8PEA4WEiEtJSgUFRcVFCEeHh47K0YgLDsrKCAlLysrHx8eISEeFBUVGxcXFRcXFx4YDxUSGxIPDw8XFxISDxISEhIODzsxQTU5NjkxJQ4S",
"CAkLGywsOzsrHg0eJiUcJSAlJSUlJR5GJiZGRiAsKEYhRhQaIRUVFCEbFxUNHygoKykuMDAxQUFBQUEWEwwJCwsLEBAFCwkFCQkBHi0VChcODAsKBQUFCQwMCwkJDAUFBQkJAQAAAAAAAAAAAAAAAAAAAAAAAAAA",
"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",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAACAgQFAwMDAwMAAAAAAAAAAQAAAAAAAAABAwMDAAABAAAAAAAAAAMF",
"AwAAAQABAQADBQcFAwgFCAUMDAkFBwwHAwUJEQwLEREKChAYDhgOGBkQEBkQDg4XHx8cKBwfHh4UHh4hHh8UIBwcJSsfIBwgHh4fIA0uLi0pPEExMTotKSwiKywoIB8eIR4fHx4NDRUVDxceLiwVFSEXGA8PDyAg",
"DhgSFRIULDxHKzA6Q0NINkM2NjY5OTlFMTAqKTMsKysuJiUWChoXIRUKFCxGRiwoK0YrLSwtLCwmRiUlJhwVEBMHCxAUKC0uMzIxMTwxOjpFLhoODAkJCAgBCwsJCQgKLBYSGSEKCQsMCAUFAwgRBQMFHSQJDCQJ",
"AAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAICAgICBAUFBQQDAgAAAAAAAAAAAAAAAAAAAAAAAAMFBQIAAAAAAAAAAAAAAgMDAAAAAAAAAwACBgUDBQMFCREFDAwI",
"CQkJCQUDCQwRCxEREA8PDxcPDxgPFBgQDhAZGBQfHyAeFB4WHh8fHx4VIR4lHx8vHxQfIh4hHi40JSUvMUEyKjwuIisfHC8tIR4UFBQeHB8fFA8UIRcYHzkxFRIUFQ8XDxUPDw8SDw0NDxAfKEYhRjFFNkM2OTk1",
"OTlFMTwpLiUoLywrMCsmLCIpLDsmGhUfISUrRiwlRiZGHiEXHx4cFAoLEwwSDg8aHCstLTBBQUExPDExOjwXEQsZCxAMJAUJCAkDBSwaDhAgEAsMCAwDDAsICQADAQAJCQUBAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAEBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
"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",
"AAAAAAAAAAAAAAAAAAADAwAAAAAAAAAAAAAAAAACAwAAAAAAAAAAAAADAwMCAAAAAAAAAAAAAgMDAAAAAAAAAAAAAAMDAgAAAAAAAAAAAAABAwMAAAAAAAAAAAAAAAACAwMCAAAAAAAAAAAAAAAAAAECAwMDAAAA",
"AAAAAAIBAwMDAwUFBwcJCQkHBwcJDBEMCwwLEQsLCxkYGA8bFRUXIR8UIQ0NHhwcHh8oKCg0LCUfIRwtLisrLDAtHDsxMDAwPDEqMkU5OjEwMUcxOkUxQTpFOjpFRTVFOkEuLSssISw7LiwtLUFFNUFFOUQ1NTIt",
"KSksOyUsPDExR0ExLTBBOipBOiotHgkBEDstJh4eIRobEh4VGxcaFBohIRcUICUlRh4hRh4hHiEeHyEUHhwmICAtMB4PCwgKDiUsJiU7OzAuKB8YChIKDwoSHzQgLEE5OTlEREREREREOUREOTo5QTowQURDSERE",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAQEAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMBAAAAAAAAAAAAAAAAAQMDAAAAAAAA",
"AAAAAAAAAAADAwAAAAAAAAAAAAAAAwMAAAAAAAAAAAAAAwMAAAAAAAAAAAAAAwMBAAAAAAAAAAAAAAMDAwAAAAAAAAAAAAAAAgMDAQAAAAAAAAAAAAAAAAACAwMDAgAAAAAAAAAAAAAAAgIDBQUHBwkHBwYFCAkJ",
"DAwMCwsLCAkJDBELEB0PFxcNFA0hHx4hFB4fHh8oKCAlKCglHx8cKy0uLystMC4lKzMqMjwwKTwxQTo6MiIrMTEqMCoyR0E6OjpFNTlFMS0wLDstLiYmIDspMEFBNUU6OjotRiswRkYhJS4wMUcuLTopOi0xQTEx",
"LhQABRYuKSkoHB4hGiEUGhoXGxcXFxIODhIaISEfKBYeIRoPGyEhFB4mOyAcJh4UEAAFDxsfLCwgLCwsLDsoFhkQFR8cJiUmIEYwMjo5OTk1REQ5REQ5OTlERDk5QTE6MEREOQAAAAAAAAAAAAAAAAAAAAAAAAAA",
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAACQAAAAAAAAAAQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwMCAAAAAAAAAAAAAAAAAAIDAQAAAAAAAAAAAAAC",
"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"
})},
avatar={w=64,h=64,palette="33333B3131352C2D342A2C343836383639423A3C433E414A595B636D7078686A737A7C83888B938E929A92959C999BA269676942434B34363F52545B4649523C3E483D4046282727302F353A393C8482834A4B537D81895D606A505053595656747272716D6B484646413E41646262625D5B595453312D2B413C3B514D4B6965637C7A7B79767685817D18171645413E75716D9896968B8A8B928D8A23201E211D1D33312E827D7A88868695918DAFADAEA29C99A7A6A7807E80A7A29D2E3037B7B5B6CCC9C7C2BBB7100E0D605F62DFDBD765615D9DA1A8B8BBC0C9C2BCA0968F080808C1BDC19F9CA0",data=table.concat({
"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",
"HwogEQUHBxYGBQAAAQEBAA=="
})}
}
-- END EMBEDDED KIT

local ok,err=xpcall(function() mount(CATALOG,PHOTOS) end,debug.traceback)
if not ok then if gui then gui:Destroy() end;warn("[Snowpaw] "..tostring(err)) end
