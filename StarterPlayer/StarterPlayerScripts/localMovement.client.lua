--!strict

--eval 9.25.22
--10.13 hypergravity.

local movementEnums = require(game.StarterPlayer.StarterCharacterScripts.movementEnums)
local signMovementEnums = require(game.ReplicatedStorage.enums.signMovementEnums)

local colors = require(game.ReplicatedStorage.util.colors)

local PlayersService = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local remotes = require(game.ReplicatedStorage.util.remotes)
local particles = require(game.StarterPlayer.StarterPlayerScripts.particles)

local localPlayer = PlayersService.LocalPlayer

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
-- doAnnotation = true
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
local seenTerrainFloorCounts: { [string]: number } = {}
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
	local last = orderedSeenFloorTypes[#orderedSeenFloorTypes]
	if last == nil then
		seenTerrainFloorCounts[fm.Name] = 1
	end
	if last ~= nil and fm.Name ~= last then
		if not seenTerrainFloorCounts[fm.Name] then
			seenTerrainFloorCounts[fm.Name] = 1
		else
			seenTerrainFloorCounts[fm.Name] = seenTerrainFloorCounts[fm.Name] + 1
		end
	end
	if not seenTerrainFloorTypes[fm.Name] and not nonMaterialEnumTypes[fm.Value] then
		seenTerrainFloorTypes[fm.Name] = true
		seenFloorCount += 1
		annotate(fm.Name)
		annotate(seenTerrainFloorTypes)
		annotate(seenFloorCount)
		annotate(seenTerrainFloorCounts)
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
	annotate("restore normal movement.")
	effectiveRunSpeed = baseRunSpeed
	effectiveWalkSpeed = baseWalkSpeed
	effectiveAfterJumpRunSpeed = baseAfterJumpRunSpeed
	effectiveAfterSwimmingRunSpeed = baseAfterSwimmingRunSpeed
	effectiveAfterLavaRunSpeed = baseAfterLavaRunSpeed
	effectiveJumpPower = baseJumpPower
	seenTerrainFloorTypes = {}
	seenTerrainFloorCounts = {}
	orderedSeenFloorTypes = {}
	seenFloorCount = 0
	shouldKillFloorMonitor = true
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	--important to spam this
	local humanoid = character:WaitForChild("Humanoid")
	HandleNewFloorMaterial(humanoid.FloorMaterial, true)
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

local function setupMold()
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local bc: BodyColors = character:FindFirstChild("BodyColors")
	if bc == nil then
		bc = Instance.new("BodyColors")
		bc.Parent = character
	end

	bc.HeadColor3 = colors.white
	bc.LeftArmColor3 = colors.white
	bc.RightArmColor3 = colors.white
	bc.LeftLegColor3 = colors.white
	bc.RightLegColor3 = colors.white
	bc.TorsoColor3 = colors.white

	shouldKillFloorMonitor = false
	spawn(function()
		while true do
			if shouldKillFloorMonitor then
				break
			end
			wait(0.1)
			for k, num in pairs(seenTerrainFloorCounts) do
				if num > 1 then
					runKiller:Fire("don't touch terrain twice")
					break
				end
			end
		end
	end)
end

--for receiving special sign touches which change with movement.
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
	elseif msg.action == signMovementEnums.movementModes.COLDMOLD then
		restoreNormalMovement()
		effectiveAfterSwimmingRunSpeed = 94
		effectiveAfterLavaRunSpeed = 70
		effectiveRunSpeed = 45
		setupMold()
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

local function setSpeed(speed: number)
	if speed == nil then
		warn("bad speed.")
		return
	end
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	if speed ~= humanoid.WalkSpeed then
		local increase = speed > humanoid.WalkSpeed
		humanoid.WalkSpeed = speed
		particles.EmitParticle(increase)
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
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	if humanoid.JumpPower ~= effectiveJumpPower then
		humanoid.JumpPower = effectiveJumpPower
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
local function reduceSpeed(func: () -> number, waitTime: number): nil
	local now = tick()
	local targetSpeed = func()
	local deadline = now + waitTime
	if speedLimitsByTime[deadline] ~= nil then
		warn("should not happen.")
		speedLimitsByTime[deadline] = math.min(speedLimitsByTime[deadline], targetSpeed)
		recheckMovementProperties()
		return
	end
	speedLimitsByTime[deadline] = func()
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

--note this does NOT fire when you hit a sign!  doh!
local function SetupFloorChangeMonitor()
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid: Humanoid = character:WaitForChild("Humanoid")
	humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		HandleNewFloorMaterial(humanoid.FloorMaterial, false)
	end)
end

local function SetupFloorIsLava()
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid: Humanoid = character:WaitForChild("Humanoid")
	humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		local fm = humanoid.FloorMaterial
		annotate("changed to: " .. tostring(fm))
		if fm == Enum.Material.Air then
			return
		end
		if fm == Enum.Material.CrackedLava then
			reduceSpeed(function()
				return effectiveAfterLavaRunSpeed
			end, 3.5)
			humanoid.Sit = true
			humanoid.JumpPower = 10
		else
			humanoid.JumpPower = 55
		end
	end)
end

function init()
	localPlayer.CharacterAdded:Connect(SetupFloorIsLava)
	localPlayer.CharacterAdded:Connect(SetupFloorChangeMonitor)
	movementEnums.SetWaterMonitoring(localPlayer)
	localPlayer.CharacterAdded:Connect(restoreNormalMovement)

	particles.SetupParticleEmitter(localPlayer)
	setupKeyboardCommandsForMovement()

	localPlayer.CharacterAdded:Connect(function(character)
		localPlayer.Character:WaitForChild("Humanoid").Jumping:Connect(function()
			reduceSpeed(function()
				return effectiveAfterJumpRunSpeed
			end, 3.5)
		end)
	end)

	localPlayer.CharacterAdded:Connect(function(character)
		localPlayer.Character:WaitForChild("Humanoid").Swimming:Connect(function()
			reduceSpeed(function()
				return effectiveAfterSwimmingRunSpeed
			end, 4)
		end)
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
