local Player=game:GetService("Players").LocalPlayer
local Mouse=Player:GetMouse()
local UIS=game:GetService("UserInputService")
local RS=game:GetService("RunService")
local selectedPart=nil
local dragging=false
local axis=nil
local mode="Move"
local space="Global"
local highlight=nil
local startMousePos=nil
local startSize=nil
local startCFrame=nil
local partCount=0
local function clearHandles()
	for _,v in workspace:GetChildren() do
		if v.Name=="Handles" then v:Destroy() end
	end
end
local function deselect()
	selectedPart=nil
	dragging=false
	axis=nil
	if highlight then highlight:Destroy() highlight=nil end
	clearHandles()
end
local function CreateHandles()
	if not selectedPart then return end
	clearHandles()
	local size=selectedPart.Size
	local pos=selectedPart.Position
	local cf=selectedPart.CFrame -- used for local space offset directions
	local function make(dir,color,ax)
		local p=Instance.new("Part")
		p.Anchored=true
		p.Shape=Enum.PartType.Ball
		p.Size=Vector3.new(1,1,1)
		p.Color=color
		p.Name="Handles"
		p:SetAttribute("Axis",ax)
		local offset
		if ax=="X" then offset=size.X/2+1
		elseif ax=="Y" then offset=size.Y/2+1
		else offset=size.Z/2+1 end
		if space=="Global" then
			if ax=="X" then p.Position=pos+Vector3.new(offset*dir,0,0)
			elseif ax=="Y" then p.Position=pos+Vector3.new(0,offset*dir,0)
			else p.Position=pos+Vector3.new(0,0,offset*dir) end
		else
			if ax=="X" then p.Position=pos+cf.RightVector*offset*dir
			elseif ax=="Y" then p.Position=pos+cf.UpVector*offset*dir
			else p.Position=pos+cf.LookVector*offset*dir end
		end
		p.Parent=workspace
	end
	make(1,Color3.fromRGB(255,0,0),"X")
	make(-1,Color3.fromRGB(255,0,0),"X")
	make(1,Color3.fromRGB(0,255,0),"Y") -- green = Y axis
	make(-1,Color3.fromRGB(0,255,0),"Y")
	make(1,Color3.fromRGB(0,0,255),"Z")
	make(-1,Color3.fromRGB(0,0,255),"Z")
end
local function spawnPart()
	local hit=Mouse.Hit.Position
	local p=Instance.new("Part")
	p.Anchored=true
	p.Size=Vector3.new(4,4,4)
	p.Position=Vector3.new(hit.X,hit.Y+2,hit.Z) -- offset Y so it sits on surface
	partCount=partCount+1
	p.Name="Part_"..partCount
	p.Parent=workspace
	if highlight then highlight:Destroy() end
	selectedPart=p
	highlight=Instance.new("Highlight")
	highlight.FillTransparency=1
	highlight.OutlineColor=Color3.fromRGB(0,255,255)
	highlight.Parent=selectedPart
	CreateHandles()
end
Mouse.Button1Down:Connect(function()
	if not Mouse.Target then deselect() return end
	if Mouse.Target.Name=="Handles" then
		dragging=true
		axis=Mouse.Target:GetAttribute("Axis")
		startMousePos=Mouse.Hit.Position -- record drag origin for delta math
		if selectedPart then
			startSize=selectedPart.Size
			startCFrame=selectedPart.CFrame
		end
		return
	end
	if selectedPart and Mouse.Target~=selectedPart then deselect() end
	if Mouse.Target.Name=="Baseplate" then deselect() return end
	selectedPart=Mouse.Target
	if highlight then highlight:Destroy() end
	highlight=Instance.new("Highlight")
	highlight.FillTransparency=1
	highlight.OutlineColor=Color3.fromRGB(0,255,255)
	highlight.Parent=selectedPart
	CreateHandles()
end)
Mouse.Button1Up:Connect(function()
	dragging=false
	axis=nil
end)
UIS.InputBegan:Connect(function(input,gp)
	if gp then return end
	if input.KeyCode==Enum.KeyCode.One then mode="Move" CreateHandles() end
	if input.KeyCode==Enum.KeyCode.Two then mode="Scale" CreateHandles() end
	if input.KeyCode==Enum.KeyCode.Three then mode="Rotate" CreateHandles() end
	if input.KeyCode==Enum.KeyCode.L then space=space=="Global" and "Local" or "Global" CreateHandles() end
	if input.KeyCode==Enum.KeyCode.N then spawnPart() end -- N spawns a new part
	if input.KeyCode==Enum.KeyCode.Delete and selectedPart then
		selectedPart:Destroy()
		deselect()
	end
end)
RS.RenderStepped:Connect(function()
	if not dragging or not selectedPart or not axis then return end
	local hit=Mouse.Hit.Position
	local pos=selectedPart.Position
	local cf=selectedPart.CFrame
	if mode=="Move" then
		if space=="Global" then
			if axis=="X" then selectedPart.Position=Vector3.new(hit.X,pos.Y,pos.Z)
			elseif axis=="Y" then selectedPart.Position=Vector3.new(pos.X,hit.Y,pos.Z)
			elseif axis=="Z" then selectedPart.Position=Vector3.new(pos.X,pos.Y,hit.Z) end
		else
			local dir=(axis=="X" and cf.RightVector) or (axis=="Y" and cf.UpVector) or cf.LookVector
			local delta=(hit-pos):Dot(dir) -- project onto local axis for constrained move
			selectedPart.Position=pos+dir*delta
		end
	end
	if mode=="Scale" then
		local axisVec
		if space=="Global" then
			axisVec=(axis=="X" and Vector3.new(1,0,0)) or (axis=="Y" and Vector3.new(0,1,0)) or Vector3.new(0,0,1)
		else
			axisVec=(axis=="X" and startCFrame.RightVector) or (axis=="Y" and startCFrame.UpVector) or startCFrame.LookVector
		end
		local delta=(hit-startMousePos):Dot(axisVec) -- signed delta along the axis
		if axis=="X" then selectedPart.Size=Vector3.new(math.max(0.05,startSize.X+delta),startSize.Y,startSize.Z)
		elseif axis=="Y" then selectedPart.Size=Vector3.new(startSize.X,math.max(0.05,startSize.Y+delta),startSize.Z)
		elseif axis=="Z" then selectedPart.Size=Vector3.new(startSize.X,startSize.Y,math.max(0.05,startSize.Z+delta)) end
	end
	if mode=="Rotate" then
		local axisVec
		if space=="Global" then
			axisVec=(axis=="X" and Vector3.new(1,0,0)) or (axis=="Y" and Vector3.new(0,1,0)) or Vector3.new(0,0,1)
		else
			axisVec=(axis=="X" and startCFrame.RightVector) or (axis=="Y" and startCFrame.UpVector) or startCFrame.LookVector
		end
		local delta=(hit-startMousePos):Dot(axisVec)
		local angle=delta*0.5 -- scale down so rotation isnt too sensitive
		if axis=="X" then selectedPart.CFrame=startCFrame*CFrame.Angles(angle,0,0)
		elseif axis=="Y" then selectedPart.CFrame=startCFrame*CFrame.Angles(0,angle,0)
		elseif axis=="Z" then selectedPart.CFrame=startCFrame*CFrame.Angles(0,0,angle) end
	end
	CreateHandles()
end)