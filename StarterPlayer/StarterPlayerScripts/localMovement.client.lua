--!strict

--eval 9.25.22
--10.13 hypergravity.

local movementEnums = require(game.StarterPlayer.StarterCharacterScripts.movementEnums)
local signMovementEnums = require(game.ReplicatedStorage.enums.signMovementEnums)

local PlayersService = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local remotes = require(game.ReplicatedStorage.util.remotes)
local particles = require(game.StarterPlayer.StarterPlayerScripts.particles)

local localPlayer = PlayersService.LocalPlayer

local player = game.Players.LocalPlayer
local Character = player.Character or player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

local vscdebug = require(game.ReplicatedStorage.vscdebug)
local doNotCheckInGameIdentifier = require(game.ReplicatedStorage:FindFirstChild("doNotCheckInGameIdentifier"))
local newMovementActive = doNotCheckInGameIdentifier.useNewMovement()

--important
if newMovementActive then
	return
end
local movementManipulationBindableEvent = remotes.getBindableEvent("MovementManipulationBindableEvent")

print("legacy movement.")

---------ANNOTATION----------------
local doAnnotation = false
	or localPlayer.Name == "TerrainParkour"
	or localPlayer.Name == "Player2"
	or localPlayer.Name == "Player1"
doAnnotation = false
-- doAnnotation = false
local annotationStart = tick()
local function annotate(s: string | any)
	if doAnnotation then
		if typeof(s) == "string" then
			print("localMovement.: " .. string.format("%.0f", tick() - annotationStart) .. " : " .. s)
		else
			print("localMovement.object. " .. string.format("%.0f", tick() - annotationStart) .. " : ")
			print(s)
		end
	end
end

---------global state vars.--------------
local walking = false
local baseRunSpeed = 68
local baseWalkSpeed = 16
local baseAfterJumpRunSpeed = 63
local baseAfterSwimmingRunSpeed = 35
local baseAfterLavaRunSpeed = 32
local baseJumpPower = 55

local effectiveRunSpeed = 68
local effectiveWalkSpeed = 16
local effectiveAfterJumpRunSpeed = 63
local effectiveAfterSwimmingRunSpeed = 35
local effectiveAfterLavaRunSpeed = 32
local effectiveJumpPower = 55

local seenTerrainFloorTypes: { [string]: boolean } = {}
local seenFloorCount = 0
local orderedSeenFloorTypes = {}
local runKiller = remotes.getBindableEvent("KillClientRunBindableEvent")
local shouldKillFloorMonitor = false

--excluded materials from counting as terrain.
local nonMaterialEnumTypes = {}
nonMaterialEnumTypes[Enum.Material.Granite.Value] = true
nonMaterialEnumTypes[Enum.Material.Plastic.Value] = true

local updateTerrainSeenBindableEvent = remotes.getBindableEvent("UpdateTerrainSeenBindableEvent")

local function HandleNewFloorMaterial(fm, special: boolean)
	if fm == Enum.Material.Air then
		return
	end

	if not seenTerrainFloorTypes[fm.Name] and not nonMaterialEnumTypes[fm.Value] then
		seenTerrainFloorTypes[fm.Name] = true
		seenFloorCount += 1
		annotate(fm.Name)
		annotate(seenTerrainFloorTypes)
		annotate(seenFloorCount)
		table.insert(orderedSeenFloorTypes, fm.Name)

		if special then
			annotate("force handle on hit." .. fm.Name)
		end
		updateTerrainSeenBindableEvent:Fire(orderedSeenFloorTypes)
	end
	workspace.Terrain.CustomPhysicalProperties = movementEnums.GetPropertiesForFloor(fm)
end

-- 2022.10.12 converting this to be modifiable
local function restoreNormalMovement()
	effectiveRunSpeed = baseRunSpeed
	effectiveWalkSpeed = baseWalkSpeed
	effectiveAfterJumpRunSpeed = baseAfterJumpRunSpeed
	effectiveAfterSwimmingRunSpeed = baseAfterSwimmingRunSpeed
	effectiveAfterLavaRunSpeed = baseAfterLavaRunSpeed
	effectiveJumpPower = baseJumpPower
	seenTerrainFloorTypes = {}
	orderedSeenFloorTypes = {}
	seenFloorCount = 0
	shouldKillFloorMonitor = true
	HandleNewFloorMaterial(Humanoid.FloorMaterial, true)
end

local function setupTerrainMonitor(limit: number)
	shouldKillFloorMonitor = false
	spawn(function()
		while true do
			if shouldKillFloorMonitor then
				break
			end

			wait(0.1)
			if seenFloorCount > limit then
				local t = ""
				for k, _ in pairs(orderedSeenFloorTypes) do
					t = t .. "," .. k
				end
				runKiller:Fire("superceded terrain limit by touching " .. t)
				break
			end
		end
	end)
end

local function setupNoGrassMonitor()
	shouldKillFloorMonitor = false
	spawn(function()
		while true do
			if shouldKillFloorMonitor then
				break
			end
			wait(0.1)
			for k, _ in pairs(seenTerrainFloorTypes) do
				if k == Enum.Material.Grass.Name or k == Enum.Material.LeafyGrass.Name then
					runKiller:Fire("don't touch grass")
					break
				end
			end
		end
	end)
end

local function receivedSpeedManipulation(msg: signMovementEnums.movementModeMessage)
	if msg.action == signMovementEnums.movementModes.RESTORE then
		restoreNormalMovement()
	elseif msg.action == signMovementEnums.movementModes.NOJUMP then
		restoreNormalMovement()
		effectiveJumpPower = 0
	elseif msg.action == signMovementEnums.movementModes.FASTER then
		restoreNormalMovement()
		effectiveRunSpeed = 91
	elseif msg.action == signMovementEnums.movementModes.THREETERRAIN then
		restoreNormalMovement()
		setupTerrainMonitor(3)
	elseif msg.action == signMovementEnums.movementModes.FOURTERRAIN then
		restoreNormalMovement()
		setupTerrainMonitor(4)
	elseif msg.action == signMovementEnums.movementModes.HIGHJUMP then
		restoreNormalMovement()
		effectiveJumpPower = 94
		effectiveRunSpeed = 56
		--mua ha ha
	elseif msg.action == signMovementEnums.movementModes.NOGRASS then
		restoreNormalMovement()
		setupNoGrassMonitor()
	else
		warn("bad msg.")
		print(msg)
	end
end

--note this does NOT fire when you hit a sign!  doh!
local function SetupFloorChangeMonitor()
	Humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		HandleNewFloorMaterial(Humanoid.FloorMaterial, false)
	end)
end

local function setSpeed(speed: number)
	if speed == nil then
		warn("bad speed.")
		return
	end
	if speed ~= game.Players.LocalPlayer.Character.Humanoid.WalkSpeed then
		local increase = speed > localPlayer.Character.Humanoid.WalkSpeed
		game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = speed
		particles.EmitParticle(increase, localPlayer)
	end
end

--map of timeExpires:speedlimit til that time
local speedLimitsByTime: { [number]: number } = {}

local checkSpeedDebounce = false
--continuously run and attempt to raise player speed again.
local function recheckMovementProperties()
	if checkSpeedDebounce then
		return
	end

	checkSpeedDebounce = true

	if game.Players.LocalPlayer.Character.Humanoid.JumpPower ~= effectiveJumpPower then
		game.Players.LocalPlayer.Character.Humanoid.JumpPower = effectiveJumpPower
	end
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
		setSpeed(effectiveRunSpeed)
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
		setSpeed(effectiveRunSpeed)
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
		recheckMovementProperties()
		return
	end
	speedLimitsByTime[deadline] = targetSpeed
	recheckMovementProperties()
	return
end

--shift to WALK now.
-- when you hit shift, set up an action upon unshift.  the action will be: disconnect itself, unset walking, recheck speed.  then set walking and speed.
local function InputChanged(input: InputObject, gameProcessedEvent: boolean)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if gameProcessedEvent then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.LeftShift then
			if input.UserInputState == Enum.UserInputState.Begin then
				walking = true
				setSpeed(effectiveWalkSpeed)
			end
			if input.UserInputState == Enum.UserInputState.End then
				walking = false
				recheckMovementProperties()
			end
		end
	end
end

function setupKeyboardCommandsForMovement()
	UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		InputChanged(input, gameProcessedEvent)
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		InputChanged(input, gameProcessedEvent)
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		InputChanged(input, gameProcessedEvent)
	end)
end

local function SetupFloorIsLava()
	Humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		local fm = Humanoid.FloorMaterial
		if fm == Enum.Material.Air then
			return
		end
		if fm == Enum.Material.CrackedLava then
			reduceSpeed(effectiveAfterLavaRunSpeed, 3.5)
			localPlayer.Character.Humanoid.Sit = true
			game.Players.LocalPlayer.Character.Humanoid.JumpPower = 10
		else
			game.Players.LocalPlayer.Character.Humanoid.JumpPower = 55
		end
	end)
end

function init()
	SetupFloorIsLava()

	SetupFloorChangeMonitor()

	movementEnums.SetWaterMonitoring(localPlayer, function() end)

	particles.SetupParticleEmitter()

	restoreNormalMovement()

	setSpeed(effectiveRunSpeed)

	setupKeyboardCommandsForMovement()

	game.Players.LocalPlayer.Character.Humanoid.Jumping:Connect(function()
		reduceSpeed(effectiveAfterJumpRunSpeed, 3.5)
	end)

	game.Players.LocalPlayer.Character.Humanoid.Swimming:Connect(function()
		reduceSpeed(effectiveAfterSwimmingRunSpeed, 4)
	end)

	movementManipulationBindableEvent.Event:Connect(receivedSpeedManipulation)

	spawn(function()
		while true do
			wait(1 / 60)
			recheckMovementProperties()
		end
	end)
end

init()
