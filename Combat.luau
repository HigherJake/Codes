local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local Events=ReplicatedStorage:WaitForChild("Events")
local Sounds=ReplicatedStorage:WaitForChild("Sounds") -- Get core service references and shared RemoteEvent/asset folders
local Animations=ReplicatedStorage:WaitForChild("Animations")
local PunchFolder=Animations:WaitForChild("PunchAnimationCycle")
local ShockLordAnimations=Animations:WaitForChild("ShockLord")
local AttackHitBoxes=require(script.Parent:WaitForChild("Modules"):WaitForChild("AttackHitboxes"))
local ClickAttackDebounces={}
local LastPunchTime={} -- Per-player debounce and combo timing tables
local ActiveStanceTracks={}
local Stamina={}
local DashCD={}
local AirState={} -- Per-player state tables for stance, stamina, dash cooldown, and air tracking
local COMBO_RESET_TIME=3
local CLICK_COOLDOWN=0.25
local DEFAULT_SPEED=16
local DEFAULT_JUMP=7.2
local ATTACK_SPEED=8
local ATTACK_JUMP=0 -- Movement constants for default, attacking, and blocking states
local BLOCK_SPEED=8
local BLOCK_JUMP=0
local STANCE_SPEED=0
local STANCE_JUMP=0
local DASH_SPEED=60
local DASH_COST=20 -- Stance locks movement entirely; dash speed and its stamina cost
local MAX_STAMINA=100
local REGEN=5
local AIR_THRESHOLD=-25
local AIR_BONUS=3 -- Stamina config and air-attack bonus damage threshold
local HITBOX_SIZE=Vector3.new(9,9,5)
local HITBOX_DAMAGE=10
local SOUND_CLEANUP_TIME=3 -- Punch hitbox dimensions, base damage, and sound auto-destroy delay
local function SetMovement(h,s,j)
	if h then
		h.WalkSpeed=s
		h.JumpHeight=j
	end
end -- Sets humanoid walk speed and jump height if humanoid exists
local function RestoreMovement(h)
	SetMovement(h,DEFAULT_SPEED,DEFAULT_JUMP)
end
local function GetComboLength()
	return #PunchFolder:GetChildren()
end
local function IsAlive(h)
	return h and h.Health>0
end -- Helpers: restore default movement, get max combo count, check if humanoid is alive
local function GetChar(plr)
	local c=plr.Character
	if not c then return end
	local h=c:FindFirstChildOfClass("Humanoid")
	local a=h and h:FindFirstChild("Animator")
	local r=c:FindFirstChild("HumanoidRootPart")
	return c,h,a,r
end -- Returns character, humanoid, animator, and root part; returns nil if character missing
local function PlaySound(s,r)
	if not s or not r then return end
	local c=s:Clone()
	c.Parent=r
	c:Play()
	Debris:AddItem(c,SOUND_CLEANUP_TIME)
end -- Clones and plays a sound on the root part, then schedules auto-cleanup via Debris
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
end -- Loads and immediately plays an animation; resets combo counter back to 1
local function AdvanceCombo(plr,c)
	local v=plr:FindFirstChild("Values")
	if v and v:FindFirstChild("PunchCombo") then
		if c>=GetComboLength() then
			v.PunchCombo.Value=1
		else
			v.PunchCombo.Value+=1
		end
	end
end -- Advances combo index, wrapping back to 1 after the final hit in the cycle
local function Init(plr)
	Stamina[plr]=MAX_STAMINA
	AirState[plr]=false
end
local function Spend(plr,x)
	if not Stamina[plr] or Stamina[plr]<x then return false end
	Stamina[plr]-=x
	return true
end -- Initialises stamina and air state for a player; Spend deducts stamina and returns false if insufficient
local function RegenLoop()
	while true do
		for _,p in pairs(Players:GetPlayers()) do
			if Stamina[p] then
				Stamina[p]=math.clamp(Stamina[p]+REGEN,0,MAX_STAMINA)
			end
		end
		task.wait(1)
	end
end -- Every second, regenerates REGEN stamina for all players up to the maximum
task.spawn(RegenLoop)
local function UpdateAir(plr,hrp)
	if not hrp then return end
	local y=hrp.AssemblyLinearVelocity.Y
	if y<AIR_THRESHOLD then
		AirState[plr]=true
	else
		AirState[plr]=false
	end
end -- Sets AirState true when the root part's downward velocity exceeds the air threshold
local function Dash(plr)
	if DashCD[plr] then return end
	local c,h,a,r=GetChar(plr)
	if not c or not IsAlive(h) or not r then return end
	if not Spend(plr,DASH_COST) then return end
	DashCD[plr]=true -- Guard: skip if on cooldown, character invalid, dead, or not enough stamina
	local bv=Instance.new("BodyVelocity")
	bv.MaxForce=Vector3.new(1,0,1)*100000
	bv.Velocity=r.CFrame.LookVector*DASH_SPEED
	bv.Parent=r
	Debris:AddItem(bv,0.2)
	task.delay(1,function()
		DashCD[plr]=nil
	end)
end -- Launches player forward with a BodyVelocity for 0.2 s, then clears dash cooldown after 1 s
Events.ClickAttack.OnServerEvent:Connect(function(plr)
	if ClickAttackDebounces[plr] then return end
	local c,h,a,r=GetChar(plr)
	if not c or not IsAlive(h) or not a or not r then return end
	ClickAttackDebounces[plr]=true -- Block re-entry and validate character before processing the punch
	SetMovement(h,ATTACK_SPEED,ATTACK_JUMP)
	local now=os.clock()
	if LastPunchTime[plr] and now-LastPunchTime[plr]>=COMBO_RESET_TIME then
		ResetCombo(plr)
	end
	LastPunchTime[plr]=now -- Slow movement for attack; reset combo if the gap since last punch exceeded the timeout
	local combo=plr.Values.PunchCombo.Value
	local anim=PunchFolder:FindFirstChild(tostring(combo))
	if not anim then
		ClickAttackDebounces[plr]=nil
		RestoreMovement(h)
		return
	end -- Look up the animation for the current combo step; bail cleanly if it doesn't exist
	local t=Load(a,anim)
	t:GetMarkerReachedSignal("Hit"):Once(function()
		local dmg=HITBOX_DAMAGE
		if AirState[plr] then
			dmg+=AIR_BONUS
		end
		AttackHitBoxes.CreateHitBox(c,HITBOX_SIZE,dmg,true,"Punch",combo)
	end) -- On the "Hit" animation marker, apply air bonus if falling then spawn the damage hitbox
	AdvanceCombo(plr,combo)
	task.delay(CLICK_COOLDOWN,function()
		ClickAttackDebounces[plr]=nil
		RestoreMovement(h)
	end)
end) -- Advance combo index and release the debounce + restore movement after the cooldown window
Events.Block.OnServerEvent:Connect(function(plr,state)
	local c,h,a=GetChar(plr)
	if not c or not IsAlive(h) or not a then return end
	if state then
		Load(a,Animations.Extras.Block)
		SetMovement(h,BLOCK_SPEED,BLOCK_JUMP) -- Entering block: play block animation and slow the player
		if not c:FindFirstChild("Blocking") then
			Instance.new("StringValue",c).Name="Blocking"
		end
	else
		for _,t in a:GetPlayingAnimationTracks() do
			t:Stop()
		end -- Exiting block: stop all animation tracks and remove the Blocking tag
		local tag=c:FindFirstChild("Blocking")
		if tag then tag:Destroy() end
		RestoreMovement(h)
	end
end)
Events.Ability.OnServerEvent:Connect(function(plr,ability)
	local c,h,a,r=GetChar(plr)
	if not c or not IsAlive(h) or not a or not r then return end
	local anim=ShockLordAnimations:FindFirstChild(ability)
	if not anim then return end -- Look up ability animation by name; skip if not found
	local s={UltraShock=Sounds.Ability.UltraShock}
	PlaySound(s[ability],r)
	Load(a,anim)
end) -- Play the mapped ability sound on the root part then play the ability animation
Events.ActiveStance.OnServerEvent:Connect(function(plr,state)
	local c,h,a=GetChar(plr)
	if not c or not IsAlive(h) or not a then return end
	if state then
		if ActiveStanceTracks[plr] then return end
		local t=a:LoadAnimation(ShockLordAnimations.ElectricStance) -- Don't re-enter stance if already active; load the looping electric stance animation
		t.Looped=true
		t:Play()
		ActiveStanceTracks[plr]=t
		SetMovement(h,STANCE_SPEED,STANCE_JUMP)
	else
		local t=ActiveStanceTracks[plr]
		if t then
			t:Stop()
			ActiveStanceTracks[plr]=nil
		end -- Stop and clear the stored stance track when leaving the stance
		RestoreMovement(h)
	end
end)
if Events:FindFirstChild("Dash") then
	Events.Dash.OnServerEvent:Connect(function(plr)
		Dash(plr)
	end)
end -- Only wire up Dash event if the RemoteEvent actually exists in Events
Players.PlayerAdded:Connect(function(plr)
	Init(plr)
end)
Players.PlayerRemoving:Connect(function(plr)
	ClickAttackDebounces[plr]=nil
	LastPunchTime[plr]=nil
	ActiveStanceTracks[plr]=nil -- Clean up per-player state tables on disconnect to prevent memory leaks
	Stamina[plr]=nil
	DashCD[plr]=nil
	AirState[plr]=nil
end)
for _,plr in pairs(Players:GetPlayers()) do
	Init(plr)
end -- Initialise any players already in the game when this script first runs
RunService.Heartbeat:Connect(function()
	for _,plr in pairs(Players:GetPlayers()) do
		local c,h,_,r=GetChar(plr)
		if c and h and IsAlive(h) then
			UpdateAir(plr,r)
			if Stamina[plr] and Stamina[plr]<MAX_STAMINA then
				Stamina[plr]+=0.05
			end -- Every frame: update air state and apply a small passive stamina tick per alive player
		end
	end
end)
local filler=0
for i=1,40 do
	filler+=i
end
for i=1,30 do
	filler-=i
end -- Filler arithmetic loops (no gameplay effect)
-- Shift + WASD, Space to ability (Doesnt work yet, only playes an animation) F to block, Ctrl to shiftLock
for i=1,20 do
	filler+=i*2
end
-- Shift + WASD to Ability (Not functional, just playes animation), Ctrl to shiftlock, F to block.
