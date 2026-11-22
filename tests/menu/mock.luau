-- Narrow client fixture. Unknown services/classes fail instead of quietly working.
local function enum(name)
	local items={}
	local t={GetEnumItems=function() return table.clone(items) end}
	return setmetatable(t,{__index=function(self,k)
		local item={Name=k,EnumType=name}; rawset(self,k,item); table.insert(items,item); return item
	end})
end
local Enum=setmetatable({}, {__index=function(self,k) local v=enum(k); rawset(self,k,v); return v end})
for _,k in {"Unknown","E","F","Escape","RightShift","RightControl","Insert","Delete","End"} do local _=Enum.KeyCode[k] end
local UDim={new=function(s,o) return {Scale=s,Offset=o} end}
local UDim2={new=function(x,a,y,b) return {X=UDim.new(x,a),Y=UDim.new(y,b)} end}
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
local Vector2={new=function(x,y) return {X=x,Y=y} end,zero={X=0,Y=0}}
local Color3={fromRGB=function(r,g,b) return string.format('%02X%02X%02X',r,g,b) end,fromHex=string.upper}
local ColorSequence={new=function(a,b) return {a,b} end}; local NumberSequence=ColorSequence
local TweenInfo={new=function(...) return {...} end}

local function signal()
	local s={connections={}}
	function s:Connect(fn)
		local c={fn=fn}; function c:Disconnect() self.fn=nil end
		table.insert(self.connections,c); return c
	end
	function s:Once(fn) local c; c=self:Connect(function(...) c:Disconnect(); fn(...) end); return c end
	function s:Fire(...) for _,c in self.connections do if c.fn then c.fn(...) end end end
	function s:count() local n=0; for _,c in self.connections do if c.fn then n+=1 end end; return n end
	return s
end
local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),TouchEnabled=true,KeyboardEnabled=false}
function input:GetFocusedTextBox() return self.focus end
local delayed={}
local task={delay=function(_,fn) table.insert(delayed,fn) end}
-- Run one turn of scheduled callbacks. Don't recursively drain the HUD's next tick.
local function tick() local batch=delayed; delayed={}; for _,fn in batch do fn() end end
local tweens={}
function tweens:Create(object,_,props)
	local t={Completed=signal()}
	function t:Play() for k,v in props do object[k]=v end; task.delay(0,function() self.Completed:Fire() end) end
	function t:Cancel() end
	return t
end

local widget={Frame=true,TextButton=true,ScrollingFrame=true,TextLabel=true,TextBox=true,CanvasGroup=true}
local events={Destroying=true,DescendantAdded=true,DescendantRemoving=true,InputBegan=true,MouseEnter=true,
	MouseLeave=true,FocusLost=true,Focused=true,Activated=true}
local viewport=Vector2.new(375,600)
local scans=0
local methods,meta={},{}
function methods:IsA(class) return self.ClassName==class or (class=='GuiObject' and widget[self.ClassName]==true) end
function methods:GetAttribute(k) return self.attributes[k] end
function methods:SetAttribute(k,v) self.attributes[k]=v end
function methods:GetPropertyChangedSignal(k)
	if not self.signals[k] then self.signals[k]=signal() end
	return self.signals[k]
end
function methods:FindFirstChild(name) for _,child in self.kids do if child.Name==name then return child end end end
function methods:GetChildren() return table.clone(self.kids) end
local function walk(obj,fn)
	fn(obj); for _,child in obj.kids do walk(child,fn) end
end
function methods:GetDescendants()
	if self.ClassName=='PlayerGui' then scans+=1 end
	local found={}; for _,obj in self.kids do walk(obj,function(o) table.insert(found,o) end) end; return found
end
function methods:FindFirstAncestorWhichIsA(class)
	local obj=self.Parent; while obj do if obj:IsA(class) then return obj end; obj=obj.Parent end
end
function methods:Destroy()
	self.Destroying:Fire(); for _,child in self:GetChildren() do child:Destroy() end
	if input.focus==self then input.focus=nil end; self.Parent=nil
end
function methods:CaptureFocus() input.focus=self; self.Focused:Fire() end
function methods:ReleaseFocus() if input.focus==self then input.focus=nil; self.FocusLost:Fire(false) end end
meta.__index=function(obj,k)
	if methods[k] then return methods[k] end
	local p=obj.props
	if k=='AbsoluteSize' or k=='AbsolutePosition' then
		if obj.ClassName=='ScreenGui' or not p.Parent then return k=='AbsoluteSize' and viewport or Vector2.zero end
		local parentSize,size=p.Parent.AbsoluteSize,p.Size
		local w=math.max(0,parentSize.X*size.X.Scale+size.X.Offset); local h=math.max(0,parentSize.Y*size.Y.Scale+size.Y.Offset)
		if k=='AbsoluteSize' then return Vector2.new(w,h) end
		local origin,pos,anchor=p.Parent.AbsolutePosition,p.Position,p.AnchorPoint
		return Vector2.new(origin.X+pos.X.Scale*parentSize.X+pos.X.Offset-anchor.X*w,origin.Y+pos.Y.Scale*parentSize.Y+pos.Y.Offset-anchor.Y*h)
	end
	if p[k]~=nil then return p[k] end
	if k=='ContentText' then return p.Text end
	if events[k] then p[k]=signal(); return p[k] end
	return obj:FindFirstChild(k)
end
local function ancestryEvent(parent,event,obj)
	while parent do
		local listeners=parent.props[event]
		if listeners then walk(obj,function(d) listeners:Fire(d) end) end
		parent=parent.Parent
	end
end
meta.__newindex=function(obj,k,v)
	local p=obj.props; if p[k]==v then return end
	if k=='Parent' then
		if p.Parent then
			ancestryEvent(p.Parent,'DescendantRemoving',obj)
			local siblings=p.Parent.kids; table.remove(siblings,assert(table.find(siblings,obj)))
		end
		p.Parent=v
		if v then table.insert(v.kids,obj); ancestryEvent(v,'DescendantAdded',obj) end
	else p[k]=v end
	if obj.signals[k] then obj.signals[k]:Fire() end
end
local Instance={new=function(class)
	assert(widget[class] or class=='ScreenGui' or class=='PlayerGui' or class:match('^UI'),'unexpected instance: '..class)
	local props={Name=class,Visible=true,Enabled=true,Size=UDim2.fromOffset(100,100),Position=UDim2.fromOffset(0,0),AnchorPoint=Vector2.zero,
		Text='',DisplayOrder=0,TextTransparency=0,MaxVisibleGraphemes=-1,GroupTransparency=0,ClipsDescendants=false,ScrollingEnabled=true}
	return setmetatable({ClassName=class,props=props,attributes={},signals={},kids={}},meta)
end}
local playerGui=Instance.new('PlayerGui')
local player={WaitForChild=function(_,name) assert(name=='PlayerGui'); return playerGui end}
local http={JSONEncode=function(_,v) return jsonEncode(v) end,JSONDecode=function(_,v) return jsonDecode(v) end}
local services={Players={LocalPlayer=player},UserInputService=input,TweenService=tweens,HttpService=http}
local game={GetService=function(_,k) return assert(services[k],'unexpected service: '..k) end}
-- Optional local file APIs are injected by each test, not by Roblox.
local readfile,writefile,isfile
