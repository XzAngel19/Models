-- Only local images are added to the shared client mock. No world or network API.
widget.ImageLabel=true
Color3.new=function(r,g,b) return Color3.fromRGB(r*255,g*255,b*255) end
local NumberSequenceKeypoint={new=function(t,v) return {Time=t,Value=v} end}
local ColorSequenceKeypoint=NumberSequenceKeypoint
local allowed,liveImages,draws=false,0,0
local Content={fromObject=function(image) assert(image.valid);return image end}
services.AssetService={CreateEditableImage=function(_,args)
	if not allowed then error('EditableImage disabled in this place') end
	local img={valid=true,Size=args.Size};liveImages+=1
	function img:WritePixelsBuffer(_,size,buf)
		assert(buffer.len(buf)==size.X*size.Y*4 and buffer.readu8(buf,3)==255)
		local a,b=buffer.readu32(buf,0),false
		for i=4,buffer.len(buf)-4,16 do if buffer.readu32(buf,i)~=a then b=true; break end end
		assert(b,'blank photograph');draws+=1
	end
	function img:Destroy() assert(self.valid);self.valid=false;liveImages-=1 end
	return img
end}
