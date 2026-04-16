-- Local Script, Has Mobile controls

-- Services
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

-- Player / Character
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

-- Remotes
local Events = RS:WaitForChild("Events")
local dashBE = character:WaitForChild("Dash")
local AbilityEvent = Events:WaitForChild("Ability")

-- GUI
local gui = script.Parent
local attackBtn = gui:WaitForChild("Punch")
local blockBtn = gui:WaitForChild("Block")
local dashBtn = gui:WaitForChild("Dash")
local stanceBtn = gui:WaitForChild("Stance")
local directions = gui:WaitForChild("Directions")

local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

gui.Enabled = isMobile


-- State
local isBlocking = false
local stanceActive = false
local SIDE_DASH_CD = 1.2
local FB_DASH_CD = 1.0
local lastSideDash = 0
local lastFBDash = 0
local CLICK_ATTACK_CD = 0.45
local lastClickAttack = 0

local function Attack()
	if isBlocking then return end

	local now = os.clock()
	if now - lastClickAttack < CLICK_ATTACK_CD then
		return
	end
	lastClickAttack = now

	Events.ClickAttack:FireServer()
end

local function StartBlock()
	isBlocking = true
	Events.Block:FireServer(true)
end

local function StopBlock()
	isBlocking = false
	Events.Block:FireServer(false)
end

local function StartStance()
	directions.Visible = true
	stanceActive = true
	Events:WaitForChild("ActiveStance"):FireServer(true)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
end

local function EndStance()
	directions.Visible = false
	stanceActive = false
	Events:WaitForChild("ActiveStance"):FireServer(false)
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 7.2
end

local function CastAbility(ability)
	AbilityEvent:FireServer(ability)
end

local function GetDashDirection()
	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude == 0 then
		return "Front"
	end

	local look = hrp.CFrame.LookVector
	local right = hrp.CFrame.RightVector

	if moveDir:Dot(look) > 0.5 then
		return "Front"
	elseif moveDir:Dot(-look) > 0.5 then
		return "Back"
	elseif moveDir:Dot(right) > 0 then
		return "Right"
	else
		return "Left"
	end
end

local function Dash()
	if isBlocking then return end

	local direction = GetDashDirection()
	local now = os.clock()

	if direction == "Left" or direction == "Right" then
		if now - lastSideDash < SIDE_DASH_CD then
			return
		end
		lastSideDash = now

	else
		if now - lastFBDash < FB_DASH_CD then
			return
		end
		lastFBDash = now
	end
	Events.Dash:FireServer()
	dashBE:Invoke(direction)
end

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Attack()
	end

	if input.KeyCode == Enum.KeyCode.F then
		StartBlock()
	end

	if input.KeyCode == Enum.KeyCode.Q then
		Dash()
	end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		StartStance()
	end
end)

UIS.InputBegan:Connect(function(i, gpe)
	if gpe then return end
	if not stanceActive then return end

	if i.KeyCode == Enum.KeyCode.W then
		CastAbility("UltraShockHit")
	elseif i.KeyCode == Enum.KeyCode.S then
		CastAbility("Pull")
	elseif i.KeyCode == Enum.KeyCode.D then
		CastAbility("SlideRight")
	elseif i.KeyCode == Enum.KeyCode.A then
		CastAbility("SlideLeft")
	elseif i.KeyCode == Enum.KeyCode.Space then
		CastAbility("ShockFloor")
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		StopBlock()
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		EndStance()
	end
end)
attackBtn.Activated:Connect(function()
	if stanceActive then
		CastAbility("ElectricThrow")
	else
		Attack()
	end
end)

stanceBtn.MouseButton1Down:Connect(StartStance)
stanceBtn.MouseButton1Up:Connect(EndStance)

blockBtn.MouseButton1Down:Connect(StartBlock)
blockBtn.MouseButton1Up:Connect(StopBlock)

dashBtn.Activated:Connect(Dash)

directions.Up.Activated:Connect(function()
	CastAbility("UltraShock")
end)

directions.Down.Activated:Connect(function()
	CastAbility("Pull")
end)

directions.Right.Activated:Connect(function()
	CastAbility("SlideRight")
end)

directions.Left.Activated:Connect(function()
	CastAbility("SlideLeft")
end)

directions.Grab.Activated:Connect(function()
	CastAbility("Grab")
end)