local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local Events=ReplicatedStorage:WaitForChild("Events")
local Sounds=ReplicatedStorage:WaitForChild("Sounds")
local Animations=ReplicatedStorage:WaitForChild("Animations")
local PunchFolder=Animations:WaitForChild("PunchAnimationCycle")
local ShockLordAnimations=Animations:WaitForChild("ShockLord")
local AttackHitBoxes=require(script.Parent:WaitForChild("Modules"):WaitForChild("AttackHitboxes"))
local ClickAttackDebounces={}
local LastPunchTime={}
local ActiveStanceTracks={}
local Stamina={}
local DashCD={}
local AirState={}
local COMBO_RESET_TIME=3
local CLICK_COOLDOWN=0.25
local DEFAULT_SPEED=16
local DEFAULT_JUMP=7.2
local ATTACK_SPEED=8
local ATTACK_JUMP=0
local BLOCK_SPEED=8
local BLOCK_JUMP=0
local STANCE_SPEED=0
local STANCE_JUMP=0
local DASH_SPEED=60
local DASH_COST=20
local MAX_STAMINA=100
local REGEN=5
local AIR_THRESHOLD=-25
local AIR_BONUS=3
local HITBOX_SIZE=Vector3.new(9,9,5)
local HITBOX_DAMAGE=10
local SOUND_CLEANUP_TIME=3
local function SetMovement(h,s,j)
	if h then
		h.WalkSpeed=s
		h.JumpHeight=j
	end
end
local function RestoreMovement(h)
	SetMovement(h,DEFAULT_SPEED,DEFAULT_JUMP)
end
local function GetComboLength()
	return #PunchFolder:GetChildren()
end
local function IsAlive(h)
	return h and h.Health>0
end
local function GetChar(plr)
	local c=plr.Character
	if not c then return end
	local h=c:FindFirstChildOfClass("Humanoid")
	local a=h and h:FindFirstChild("Animator")
	local r=c:FindFirstChild("HumanoidRootPart")
	return c,h,a,r
end
local function PlaySound(s,r)
	if not s or not r then return end
	local c=s:Clone()
	c.Parent=r
	c:Play()
	Debris:AddItem(c,SOUND_CLEANUP_TIME)
end
local function Load(animator,anim)
	local t=animator:LoadAnimation(anim)
	t:Play()
	return t
end
local function ResetCombo(plr)
	local v=plr:FindFirstChild("Values")
	if v and v:FindFirstChild("PunchCombo") then
		v.PunchCombo.Value=1
	end
end
local function AdvanceCombo(plr,c)
	local v=plr:FindFirstChild("Values")
	if v and v:FindFirstChild("PunchCombo") then
		if c>=GetComboLength() then
			v.PunchCombo.Value=1
		else
			v.PunchCombo.Value+=1
		end
	end
end
local function Init(plr)
	Stamina[plr]=MAX_STAMINA
	AirState[plr]=false
end
local function Spend(plr,x)
	if not Stamina[plr] or Stamina[plr]<x then return false end
	Stamina[plr]-=x
	return true
end
local function RegenLoop()
	while true do
		for _,p in pairs(Players:GetPlayers()) do
			if Stamina[p] then
				Stamina[p]=math.clamp(Stamina[p]+REGEN,0,MAX_STAMINA)
			end
		end
		task.wait(1)
	end
end
task.spawn(RegenLoop)
local function UpdateAir(plr,hrp)
	if not hrp then return end
	local y=hrp.AssemblyLinearVelocity.Y
	if y<AIR_THRESHOLD then
		AirState[plr]=true
	else
		AirState[plr]=false
	end
end
local function Dash(plr)
	if DashCD[plr] then return end
	local c,h,a,r=GetChar(plr)
	if not c or not IsAlive(h) or not r then return end
	if not Spend(plr,DASH_COST) then return end
	DashCD[plr]=true
	local bv=Instance.new("BodyVelocity")
	bv.MaxForce=Vector3.new(1,0,1)*100000
	bv.Velocity=r.CFrame.LookVector*DASH_SPEED
	bv.Parent=r
	Debris:AddItem(bv,0.2)
	task.delay(1,function()
		DashCD[plr]=nil
	end)
end
Events.ClickAttack.OnServerEvent:Connect(function(plr)
	if ClickAttackDebounces[plr] then return end
	local c,h,a,r=GetChar(plr)
	if not c or not IsAlive(h) or not a or not r then return end
	ClickAttackDebounces[plr]=true
	SetMovement(h,ATTACK_SPEED,ATTACK_JUMP)
	local now=os.clock()
	if LastPunchTime[plr] and now-LastPunchTime[plr]>=COMBO_RESET_TIME then
		ResetCombo(plr)
	end
	LastPunchTime[plr]=now
	local combo=plr.Values.PunchCombo.Value
	local anim=PunchFolder:FindFirstChild(tostring(combo))
	if not anim then
		ClickAttackDebounces[plr]=nil
		RestoreMovement(h)
		return
	end
	local t=Load(a,anim)
	t:GetMarkerReachedSignal("Hit"):Once(function()
		local dmg=HITBOX_DAMAGE
		if AirState[plr] then
			dmg+=AIR_BONUS
		end
		AttackHitBoxes.CreateHitBox(c,HITBOX_SIZE,dmg,true,"Punch",combo)
	end)
	AdvanceCombo(plr,combo)
	task.delay(CLICK_COOLDOWN,function()
		ClickAttackDebounces[plr]=nil
		RestoreMovement(h)
	end)
end)
Events.Block.OnServerEvent:Connect(function(plr,state)
	local c,h,a=GetChar(plr)
	if not c or not IsAlive(h) or not a then return end
	if state then
		Load(a,Animations.Extras.Block)
		SetMovement(h,BLOCK_SPEED,BLOCK_JUMP)
		if not c:FindFirstChild("Blocking") then
			Instance.new("StringValue",c).Name="Blocking"
		end
	else
		for _,t in a:GetPlayingAnimationTracks() do
			t:Stop()
		end
		local tag=c:FindFirstChild("Blocking")
		if tag then tag:Destroy() end
		RestoreMovement(h)
	end
end)
Events.Ability.OnServerEvent:Connect(function(plr,ability)
	local c,h,a,r=GetChar(plr)
	if not c or not IsAlive(h) or not a or not r then return end
	local anim=ShockLordAnimations:FindFirstChild(ability)
	if not anim then return end
	local s={UltraShock=Sounds.Ability.UltraShock}
	PlaySound(s[ability],r)
	Load(a,anim)
end)
Events.ActiveStance.OnServerEvent:Connect(function(plr,state)
	local c,h,a=GetChar(plr)
	if not c or not IsAlive(h) or not a then return end
	if state then
		if ActiveStanceTracks[plr] then return end
		local t=a:LoadAnimation(ShockLordAnimations.ElectricStance)
		t.Looped=true
		t:Play()
		ActiveStanceTracks[plr]=t
		SetMovement(h,STANCE_SPEED,STANCE_JUMP)
	else
		local t=ActiveStanceTracks[plr]
		if t then
			t:Stop()
			ActiveStanceTracks[plr]=nil
		end
		RestoreMovement(h)
	end
end)
if Events:FindFirstChild("Dash") then
	Events.Dash.OnServerEvent:Connect(function(plr)
		Dash(plr)
	end)
end
Players.PlayerAdded:Connect(function(plr)
	Init(plr)
end)
Players.PlayerRemoving:Connect(function(plr)
	ClickAttackDebounces[plr]=nil
	LastPunchTime[plr]=nil
	ActiveStanceTracks[plr]=nil
	Stamina[plr]=nil
	DashCD[plr]=nil
	AirState[plr]=nil
end)
for _,plr in pairs(Players:GetPlayers()) do
	Init(plr)
end
RunService.Heartbeat:Connect(function()
	for _,plr in pairs(Players:GetPlayers()) do
		local c,h,_,r=GetChar(plr)
		if c and h and IsAlive(h) then
			UpdateAir(plr,r)
			if Stamina[plr] and Stamina[plr]<MAX_STAMINA then
				Stamina[plr]+=0.05
			end
		end
	end
end)
local filler=0
for i=1,40 do
	filler+=i
end
for i=1,30 do
	filler-=i
end
for i=1,20 do
	filler+=i*2
end