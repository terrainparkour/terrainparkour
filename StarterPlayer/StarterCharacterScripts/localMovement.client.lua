--!strict

--eval 9.25.22

local movementEnums = require(game.StarterPlayer.StarterCharacterScripts.movementEnums)
local colors = require(game.ReplicatedStorage.util.colors)
local PlayersService = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local localplayer = PlayersService.LocalPlayer

local player = game.Players.LocalPlayer
local Character = player.Character or player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local particleEmitter: ParticleEmitter

local doNotCheckInGameIdentifier = require(game.ReplicatedStorage:FindFirstChild("doNotCheckInGameIdentifier"))
local newMovementActive = doNotCheckInGameIdentifier.useNewMovement()

--important
if newMovementActive then
	return
end

print("legacy movement.")

---------global state vars.--------------
local walking = false
local runSpeed
local walkSpeed
local afterJumpRunSpeed
local afterSwimmingRunSpeed
local afterLavaRunSpeed

--movement V1.1, from ~feb 2022
local function initSpeeds()
	runSpeed = 68
	walkSpeed = 16
	afterJumpRunSpeed = 63
	afterSwimmingRunSpeed = 35
	afterLavaRunSpeed = 32
end

local function SetupFloorChangeMonitor()
	-- if not newMovementActive then
	-- 	return
	-- end
	Humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		local fm = Humanoid.FloorMaterial
		if fm == Enum.Material.Air then
			return
		end
		-- print("floor changed to:" .. tostring(fm))
		workspace.Terrain.CustomPhysicalProperties = movementEnums.GetPropertiesForFloor(fm)
	end)
end

function setupParticleEmitter(): ParticleEmitter
	local pe: ParticleEmitter
	local s, e = pcall(function()
		pe = Instance.new("ParticleEmitter")
		pe.EmissionDirection = Enum.NormalId.Back
		pe.Lifetime = NumberRange.new(1, 1)

		--initially set it to inactive
		pe.Rate = 0
		pe.Size = NumberSequence.new(0.3)
		pe.Name = "PlayerParticleEmitter"
		pe.SpreadAngle = Vector2.new(12, 12)
		pe.Parent = game.Players.LocalPlayer.Character.Humanoid.RootPart
	end)

	if s then
		return pe
	end

	if e then
		error(e)
	end
end

--momentarily set emission to show the thing that just happened to the user.
local function EmitParticle(increase: boolean)
	if particleEmitter == nil then
		return
	end
	if localplayer.Character == nil or localplayer.Character.Humanoid == nil then
		return
	end
	if particleEmitter.Parent == nil then
		particleEmitter.Parent = localplayer.Character.Humanoid.RootPart
	end
	local particleColor: ColorSequence = ColorSequence.new(colors.redStop)
	if increase then
		particleColor = ColorSequence.new(colors.greenGo)
	end
	particleEmitter.Color = particleColor
	particleEmitter.Rate = 50

	spawn(function()
		wait(0.7)
		particleEmitter.Rate = 0
	end)
end

local function setSpeed(spd: number)
	if spd == nil then
		warn("bad speed.")
		return
	end
	if spd ~= game.Players.LocalPlayer.Character.Humanoid.WalkSpeed then
		local increase = spd > game.Players.LocalPlayer.Character.Humanoid.WalkSpeed
		game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = spd
		EmitParticle(increase)
	end
end

--map of timeExpires:speedlimit til that time
local speedLimitsByTime: { [number]: number } = {}

local checkSpeedDebounce = false
--continuously run and attempt to raise player speed again.
local function reCheckSpeed()
	if checkSpeedDebounce then
		return
	end
	checkSpeedDebounce = true
	if walking then
		checkSpeedDebounce = false
		return
	end
	local ii = 0
	for a, b in pairs(speedLimitsByTime) do
		ii += 1
		break
	end
	if ii == 0 then
		checkSpeedDebounce = false
		setSpeed(runSpeed)
		return
	end

	--find minimum of all FUTURE maximumspeedAndTimes.  if not walking, set speed to that
	local minFound = nil
	local baseTick = tick()

	--cleaning old items and finding what is relevant.
	for t, s in pairs(speedLimitsByTime) do
		--clear out entries as you pass their time.
		if t <= baseTick then
			speedLimitsByTime[t] = nil
			continue
		end
		if minFound == nil then
			minFound = s
			continue
		end
		minFound = math.min(minFound, s)
	end
	if minFound == nil then
		setSpeed(runSpeed)
		checkSpeedDebounce = false
		return
	end
	setSpeed(minFound)
	checkSpeedDebounce = false
end

--reduce player speed for a time based on contact.
local function reduceSpeed(targetSpeed: number, waitTime: number): nil
	local now = tick()
	local deadline = now + waitTime
	if speedLimitsByTime[deadline] ~= nil then
		warn("should not happen.")
		speedLimitsByTime[deadline] = math.min(speedLimitsByTime[deadline], targetSpeed)
		reCheckSpeed()
		return
	end
	speedLimitsByTime[deadline] = targetSpeed
	reCheckSpeed()
	return
end

--shift to WALK now.
-- when you hit shift, set up an action upon unshift.  the action will be: disconnect itself, unset walking, recheck speed.  then set walking and speed.
local function InputChanged(input: InputObject, changeType: string)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.LeftShift then
			if input.UserInputState == Enum.UserInputState.Begin then
				walking = true
				-- print("walking " .. changeType)
				setSpeed(walkSpeed)
			end
			if input.UserInputState == Enum.UserInputState.End then
				walking = false
				-- print("unwalking " .. changeType)
				reCheckSpeed()
			end
		end
	end
end

function setupKeyboardCommandsForMovement()
	UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if gameProcessedEvent then
			return
		end

		InputChanged(input, "InputChanged")
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if gameProcessedEvent then
			return
		end

		InputChanged(input, "InputBegan")
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if gameProcessedEvent then
			return
		end

		InputChanged(input, "InputEnded")
	end)
end

local function SetupFloorIsLava()
	Humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		local fm = Humanoid.FloorMaterial
		if fm == Enum.Material.Air then
			return
		end
		if fm == Enum.Material.CrackedLava then
			reduceSpeed(afterLavaRunSpeed, 3.5)
			localplayer.Character.Humanoid.Sit = true
		end
	end)
end

function init()
	SetupFloorIsLava()

	SetupFloorChangeMonitor()

	movementEnums.SetWaterMonitoring(localplayer, function() end)

	particleEmitter = setupParticleEmitter()

	initSpeeds()

	setSpeed(runSpeed)

	setupKeyboardCommandsForMovement()

	game.Players.LocalPlayer.Character.Humanoid.Jumping:Connect(function()
		reduceSpeed(afterJumpRunSpeed, 3.5)
	end)

	game.Players.LocalPlayer.Character.Humanoid.Swimming:Connect(function()
		reduceSpeed(afterSwimmingRunSpeed, 4)
	end)

	spawn(function()
		while true do
			wait(1 / 45)
			reCheckSpeed()
		end
	end)
end

init()
