local function root() return assert(playerGui:FindFirstChild('SnowpawFieldConsole')) end
local function win() return root().Stage.Window end
local function bench() return win().Content.Workbench end
local function click(o) o.Activated:Fire() end
local function tab(name) click((win().Sidebar.Visible and win().Sidebar.Navigation or win().TabStrip)[name]) end
local function tickSize(w,h) viewport=Vector2.new(w,h);root().Stage:GetPropertyChangedSignal('AbsoluteSize'):Fire() end
local function key(k,processed) input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode[k]},processed==true) end
local decoy=Instance.new('ScreenGui');decoy.Name='OtherMenu';decoy.Parent=playerGui
launch()
local cover=win().Content.FieldPlate.NightStreet;assert(cover.PhotoStrip and not cover.Photo,'missing fallback photo')
assert(win().Header.Drag.Mascot.PhotoStrip and not win().Sidebar.Visible and win().TabStrip.Visible)
assert(win().Size.X.Offset<375 and bench().Aimbot:GetAttribute('Selected')==false and win().Footer.Count.Text=='0 / 12 SELECTED')
click(bench().Aimbot);assert(win().Footer.Count.Text=='1 / 12 SELECTED');tab('Visual');click(bench()['Player ESP']);assert(win().Footer.Count.Text=='2 / 12 SELECTED')
tab('Extra');click(bench().Flight);tab('Main');assert(bench().Aimbot:GetAttribute('Selected'))
local hit=bench().Tuning.Slider;local p=hit.Track.AbsolutePosition;local width=hit.Track.AbsoluteSize.X
local touch={UserInputType=Enum.UserInputType.Touch,Position=Vector2.new(p.X,p.Y)};hit.InputBegan:Fire(touch)
assert(bench().Tuning.Value.Text=='30°' and not win().Content.ScrollingEnabled)
touch.Position=Vector2.new(p.X+width+20,p.Y);input.InputChanged:Fire(touch);input.InputEnded:Fire(touch)
assert(bench().Tuning.Value.Text=='180°' and win().Content.ScrollingEnabled)
tab('Config');click(bench().Palette.Ember);assert(bench().Palette.Accent.Text=='Accent · Ember');click(bench()['Compact cards']);click(bench()['Module notes']);tab('Main')
assert(bench().Aimbot.Size.Y.Offset==79 and not bench().Aimbot.Note.Visible and bench().Tuning.Value.Text=='180°')
tab('Config');click(bench().ResetRow.Reset);click(win().Dialog.Sheet.Cancel);assert(win().Footer.Count.Text=='3 / 12 SELECTED');click(bench().ResetRow.Reset);click(win().Dialog.Sheet.Confirm)
assert(bench().Palette.Accent.Text=='Accent · Glacier' and win().Footer.Count.Text=='0 / 12 SELECTED');tab('Main');assert(bench().Tuning.Value.Text=='90°' and bench().Aimbot.Note.Visible)
click(win().Header.Minimize);assert(not win().Visible and root().Stage.OpenSnowpaw.Visible);click(root().Stage.OpenSnowpaw);assert(win().Visible)
key('RightShift',true);assert(win().Visible);key('RightShift');assert(not win().Visible);key('RightShift');assert(win().Visible)
click(win().Header.Close);key('Escape');assert(not win().Dialog)
tickSize(1280,800);assert(win().Sidebar.Visible and not win().TabStrip.Visible and win().Sidebar.Profile.Mascot.PhotoStrip)
local grip=win().Header.Drag;local mouse={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(50,30)};grip.InputBegan:Fire(mouse)
input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(9999,9999)});input.InputEnded:Fire(mouse)
assert(win().Position.X.Offset+win().Size.X.Offset<=1280 and win().Position.Y.Offset+win().Size.Y.Offset<=800)
local previous=root();allowed=true;launch();assert(not previous.Parent and decoy.Parent==playerGui and root().Stage.Window.Content.FieldPlate.NightStreet.Photo)
assert(liveImages==2 and draws==2 and input.InputBegan:count()==1);tab('Extra');assert(bench().Flight:GetAttribute('Selected')==false)
click(win().Header.Close);click(win().Dialog.Sheet.Confirm);assert(liveImages==0 and #playerGui.kids==1 and decoy.Parent==playerGui)
assert(input.InputBegan:count()==0 and input.InputChanged:count()==0 and input.InputEnded:count()==0 and input.WindowFocusReleased:count()==0)
assert(scans==0,'unexpected PlayerGui scan');print('Snowpaw: isolated selections, tuning, themes, mobile/desktop layout, both photo paths, dialogs, drag and cleanup passed.')
