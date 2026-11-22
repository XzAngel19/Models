local GUI='ViolenceDistrictMenuPreview'
local GAP='Not on HUD'
local function root() return assert(playerGui:FindFirstChild(GUI)) end
local function window() return root().Stage.Window end
local function page(name) window().Tabs[name].Activated:Fire(); return window().Pages[name] end
local function hud() return window().Pages.Main.Left['Live HUD'] end
local function value(row) return hud()[row].Value.Text end
local function control(tab,group,name)
	local p=window().Pages[tab]; local box=p.Left:FindFirstChild(group) or p.Right:FindFirstChild(group)
	return assert(box:FindFirstChild(name),name)
end
local function settings(action) control('Config','Settings',action).Activated:Fire() end
local function item(parent,class,name,text)
	local obj=Instance.new(class); obj.Name=name; if text then obj.Text=text end; obj.Parent=parent; return obj
end
local function timer(screen,text)
	return item(item(screen,'Frame','time'),'TextLabel','TimerLabel',text)
end
local function generator(parent,text)
	return item(item(parent,'Frame','genholder'),'TextLabel','Gencount',text)
end
local function expectEmpty()
	assert(value('Round timer')==GAP and value('Generators')==GAP and value('Interaction')==GAP,'expected no HUD')
end

-- An active panel present before launch, and misleading samples in the layout editor.
local active=item(playerGui,'ScreenGui','Survivor')
local panel=item(active,'CanvasGroup','GenPanel'); panel:SetAttribute('SurvivorGen',true)
local count=generator(panel,'3')
local mobile=item(playerGui,'ScreenGui','Spectatot-mob')
local editor=item(mobile,'Frame','survlayout'); timer(editor,'EDITOR TIMER')
local sample=item(editor,'Frame','Preview'); sample:SetAttribute('SurvivorGen',true); generator(sample,'99')
launch(); local scanAtLaunch=scans
assert(#window().Pages.kids==4 and window().Size.X.Offset<=375 and not window().Pages.Main.Right.Visible)
assert(value('Generators')=='3' and value('Round timer')==GAP)
count.Text='2'; tick(); assert(value('Generators')=='2')
panel.Visible=false; tick(); expectEmpty()
panel.Visible=true; panel.GroupTransparency=1; tick(); expectEmpty()
panel.GroupTransparency=0; active.Enabled=false; tick(); expectEmpty()
active.Enabled=true; count.TextTransparency=1; tick(); expectEmpty()
count.TextTransparency=0; count.Size=UDim2.fromOffset(0,16); tick(); expectEmpty()
count.Size=UDim2.fromOffset(40,16); panel.Position=UDim2.fromOffset(800,0); tick(); expectEmpty()
panel.Position=UDim2.fromOffset(0,0); count.Position=UDim2.fromOffset(120,0); tick(); expectEmpty() -- clipped by CanvasGroup
count.Position=UDim2.fromOffset(0,0); count.Text='3 left'; count.MaxVisibleGraphemes=1; tick(); expectEmpty()
count.MaxVisibleGraphemes=-1; tick(); assert(value('Generators')=='3 left')
count:Destroy(); tick(); expectEmpty()
local renamed=item(panel.genholder,'TextLabel','TextLabel','1'); renamed.Name='Gencount'; tick(); assert(value('Generators')=='1')
renamed.Name='Placeholder'; tick(); expectEmpty()
active:Destroy(); tick(); expectEmpty()

local clock=timer(mobile,'<b>00:44</b>'); clock.ContentText='00:44'; tick(); assert(value('Round timer')=='00:44')
local prompt=item(playerGui,'ScreenGui','ProgressPromptGui'); local frame=item(prompt,'Frame','Frame')
local caption=item(frame,'TextLabel','TextLabel','REPAIR'); local help=item(frame,'TextLabel','Help','FIND HELP…'); help.Visible=false
tick(); assert(value('Interaction')=='REPAIR'); caption.Visible=false; help.Visible=true; tick(); assert(value('Interaction')=='FIND HELP…')
frame.Visible=false; mobile.Enabled=false; tick(); expectEmpty()
local replacement=item(playerGui,'ScreenGui',mobile.Name); replacement.DisplayOrder=8; timer(replacement,'02:30')
tick(); assert(value('Round timer')=='02:30'); mobile.Enabled=true; tick(); assert(value('Round timer')=='02:30')
replacement:Destroy(); prompt:Destroy(); mobile:Destroy()
for _,suffix in {'','-mob','-con'} do
	local screen=item(playerGui,'ScreenGui','SpectatorHUD'..suffix); timer(screen,'00:37')
	generator(item(item(screen,'Frame','bottom left'),'Frame','Gen'),'4'); tick()
	assert(value('Round timer')=='00:37' and value('Generators')=='4'); screen:Destroy(); tick(); expectEmpty()
end
-- A new screen replacing the old one while minimized/off-tab must not reuse old text.
local lobby=item(playerGui,'ScreenGui','Spectatot-con'); timer(lobby,'Waiting For Next Round')
page('Config'); tick(); page('Main'); assert(value('Round timer')=='Waiting For Next Round')
window().TitleBar.Minimize.Activated:Fire(); lobby:Destroy(); tick(); window().TitleBar.Minimize.Activated:Fire(); expectEmpty()
local decoy=item(playerGui,'ScreenGui','OtherGui'); timer(decoy,'not a match timer'); generator(decoy,'unrelated'); tick(); expectEmpty(); decoy:Destroy()
assert(scans==scanAtLaunch,'HUD rescanned the entire PlayerGui')
print('HUD: active, spectator, lobby and prompt labels; hidden/clipped/sample exclusions; removal and replacement passed.')

local function killer() return control('Main','Protection','No Slowdown') end
local function survivor() return control('Main','Actions','No Slowdown') end
local function on(row) return row.ActiveMark.Visible end
local function click(row) row.Activated:Fire() end
local function auto() return control('Config','Settings','Auto Save') end
local FILENAME='ZenithViolenceDistrict.settings.json'
local KILLER='Main/Protection/No Slowdown'; local SURVIVOR='Main/Actions/No Slowdown'; local AUTO='Config/Settings/Auto Save'
local KEY='Config/Interface/Menu Keybind'; local RANGE='Main/Offense/Kill Range'; local COLOR='Visual/Player ESP/Survivor Color'
local BIND='Extra/Speed/Walk Speed Bind'
local function document(v) return http:JSONEncode({version=1,values=v}) end
local function restart()
	local old=root(); launch(); assert(old.Parent==nil and #playerGui.kids==1)
	assert(input.InputBegan:count()==1 and playerGui.DescendantAdded:count()==1 and playerGui.DescendantRemoving:count()==1)
end
page('Main'); click(killer()); assert(on(killer()) and not on(survivor()))
page('Config'); settings('Save Settings'); settings('Reset Settings'); assert(not on(killer())); settings('Load Settings'); assert(on(killer()))
settings('Copy Settings'); local copy=window().Dialog['Copy settings'].SettingsText.Text
local doc=http:JSONDecode(copy); assert(doc.version==1 and doc.values[KILLER]==true and not copy:find('Live HUD',1,true)); window().Dialog.Backdrop.Activated:Fire()
restart(); assert(not on(killer()),'session-only save unexpectedly survived unload')

local disk,writes,reads,denyRead,denyWrite=nil,0,0,false,false
readfile=function(path) assert(path==FILENAME); reads+=1; assert(not denyRead and disk,'unreadable'); return disk end
writefile=function(path,bytes) assert(path==FILENAME and type(bytes)=='string'); assert(not denyWrite,'write denied'); writes+=1; disk=bytes end
isfile=function(path) assert(path==FILENAME); return disk~=nil end
restart(); assert(writes==0 and reads==0,'fresh launch should not write defaults or read missing file')
click(killer()); settings('Save Settings'); assert(writes==1 and http:JSONDecode(disk).values[KILLER]==true)
settings('Reset Settings'); assert(not on(killer()) and writes==1); restart(); assert(on(killer()) and not on(survivor()))
click(auto()); click(survivor()); assert(http:JSONDecode(disk).values[SURVIVOR] and http:JSONDecode(disk).values[AUTO])
local slider=control('Main','Offense','Kill Range'); local bar=slider.Track; local oldWrites=writes
local touch={UserInputType=Enum.UserInputType.Touch,Position=bar.AbsolutePosition}; slider.Scrub.InputBegan:Fire(touch)
for _,frac in {0.2,0.5,1} do
	touch.Position=Vector2.new(bar.AbsolutePosition.X+frac*bar.AbsoluteSize.X,bar.AbsolutePosition.Y); input.InputChanged:Fire(touch)
end
assert(writes==oldWrites,'unexpected disk write during touch movement'); input.InputEnded:Fire(touch)
assert(writes==oldWrites+1 and http:JSONDecode(disk).values[RANGE]==80)
-- Even direct removal while scrubbing flushes the last pending slider edit.
touch.Position=bar.AbsolutePosition; slider.Scrub.InputBegan:Fire(touch); restart()
assert(http:JSONDecode(disk).values[RANGE]==1 and on(auto()) and on(survivor()))
click(auto()); assert(http:JSONDecode(disk).values[AUTO]==false); oldWrites=writes; click(survivor()); assert(writes==oldWrites)
settings('Load Settings'); assert(on(survivor()))
-- A denied write keeps the newer session save, not an older copy on disk.
denyWrite=true; click(survivor()); settings('Save Settings'); settings('Reset Settings'); settings('Load Settings')
assert(on(killer()) and not on(survivor())); denyWrite=false; settings('Save Settings'); assert(not http:JSONDecode(disk).values[SURVIVOR])
denyRead=true; settings('Reset Settings'); settings('Load Settings'); assert(on(killer())); denyRead=false
isfile=nil; restart(); assert(on(killer()),'isfile is optional')
print('Config: session/no-files, manual save across launches, autosave, touch batching, unload flush and denied I/O passed.')

-- Validate a whole snapshot before painting a single row. Unknown keys are not executed or saved.
for _,bad in {'{bad json','[]','{"version":2,"values":{}}',string.rep('x',65537),document({[KILLER]='yes'}),
	document({[KEY]='garbage'}),document({[BIND]='not-a-key'}),document({[COLOR]='##ZZZZ'}),document({[RANGE]='inf'})} do
	disk=bad; restart(); assert(not on(killer()) and disk==bad,'invalid file changed defaults or was overwritten')
	click(survivor()); settings('Load Settings'); assert(on(survivor()) and disk==bad)
end
disk=document({[COLOR]='00abff',[KEY]='Insert',[RANGE]=9000,[BIND]='E',[KILLER]=true,['unknown/key']=42})
restart(); assert(on(killer()) and not on(survivor()) and control('Visual','Player ESP','Survivor Color').Swatch.BackgroundColor3=='00ABFF')
settings('Save Settings'); doc=http:JSONDecode(disk); assert(doc.values[RANGE]==80 and doc.values['unknown/key']==nil and doc.values[BIND]=='E')
local key={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Insert}; input.InputBegan:Fire(key,false); assert(not root().Enabled)
input.InputBegan:Fire(key,false); assert(root().Enabled); window().TitleBar.Close.Activated:Fire(); tick(); tick()
assert(#playerGui.kids==0 and playerGui.DescendantAdded:count()==0 and playerGui.DescendantRemoving:count()==0 and input.InputBegan:count()==0 and #delayed==0)
print('Validation: bad/oversized files, unsupported version, enum/type/color checks, clamped sliders, defaulting, hotkey and cleanup passed.')
