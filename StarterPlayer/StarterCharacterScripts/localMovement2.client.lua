--!strict

--eval 9.25.22

local movementEnums = require(game.StarterPlayer.StarterCharacterScripts.movementEnums)
local speedEvents = require(game.StarterPlayer.StarterCharacterScripts.speedEvents)
local particles = require(game.ReplicatedStorage.particles)
local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local PlayersService = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local localplayer = PlayersService.LocalPlayer

local player = game.Players.LocalPlayer
local Character = player.Character or player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

local doNotCheckInGameIdentifier = require(game.ReplicatedStorage:FindFirstChild("doNotCheckInGameIdentifier"))
local newMovementActive = doNotCheckInGameIdentifier.useNewMovement()

--important, cancelling this whole script 2022.09 still in dev from 2022.05/06
if not newMovementActive then
	return
end

print("new movement.")
local walking = false

local globalRunSpeedMax = 68
local lastSpeedCheck = tick()
local checkSpeedDebounce = false

--concepts:
--user has a maxspeed
--continuously accelerate towards it
--i.e. maxspeed 100, speed now 50, capture 1% of gap(max-speed) per frame.
-- maxspeed can change
-- jumping and water decreases maxspeed
-- falling decreases maxspeed
-- green particles mean speeding up
-- blue particles mean wet.
-- and if you hit the ground hard speed is down
-- what about if you turn?
-- what determines speed? dynamically calculated with a running value
-- what determines maxspeed? history of "events" which fall out of time
--Q: what matters? if I jump do I just bang down maxspeed? or just speed?
--Q: do I need gears?
--Q: gears are the infinite version of this.

--a type which stores user intended speeds
--toss a bunch of events into here via multiple methods.
--then process it every frame to recalculate movement speed.

local function setupSpd(): TextLabel
	local spd = Instance.new("ScreenGui")
	spd.Parent = localplayer.PlayerGui
	spd.Name = "PlayerSpeedScreenGui"
	local fr = Instance.new("Frame", spd)
	fr.Size = UDim2.new(0.2, 0, 0.05, 0)
	fr.Name = "SpeedFrame"
	fr.Position = UDim2.new(0.43, 0, 0.65, 0)
	fr.BackgroundTransparency = 1
	local spdTl: TextLabel = guiUtil.getTl("Spd", UDim2.new(1, 0, 1, 0), 2, fr, colors.defaultGrey, 1)
	spdTl.Font = Enum.Font.GothamBlack
	spdTl.BackgroundTransparency = 1
	local p: TextLabel = spdTl.Parent
	p.BackgroundTransparency = 1
	spdTl.TextColor3 = colors.meColor
	spdTl.TextXAlignment = Enum.TextXAlignment.Left
	return spdTl
end

local spdTl = setupSpd()

local lastFloor = nil
local lastNonAirFloor = nil

--for tracking punishments for changing floors
local changedFloor = false
--send movement speed events for the terrain the user touches.
--AND set global for last floor
--AND set universal fake physical properties for just this local player to say
local function SetupFloorChangeMonitor()
	Humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		local st = tick()
		local fm = Humanoid.FloorMaterial
		print("floor is: " .. tostring(fm))
		if fm == nil then
			return
		end
		if lastFloor ~= fm then
			if fm == Enum.Material.Granite or fm == Enum.Material.Plastic or fm == Enum.Material.Air then
				--do nothing.
			else
				lastFloor = fm
				changedFloor = true
				print("hcanged floor to" .. tostring(fm))
			end
		end
		--logging floor changes.
		local senumnum = nil
		if fm == Enum.Material.CrackedLava then
			senumnum = movementEnums.SpeedEventName2Id.LAVA
			localplayer.Character.Humanoid.Sit = true
		elseif fm == Enum.Material.Air then
			senumnum = movementEnums.SpeedEventName2Id.GETAIR
		end
		if senumnum ~= nil then
			speedEvents.addEvent({ type = senumnum, timems = st })
		end

		if fm == Enum.Material.Air then
			return
		end
		lastNonAirFloor = fm
		workspace.Terrain.CustomPhysicalProperties = movementEnums.GetPropertiesForFloor(fm)
		local el = movementEnums.floor2movementData[fm.Value]
		if el ~= nil then
			game.Players.LocalPlayer.Character.Humanoid.JumpPower = el.jumppower
			print(game.Players.LocalPlayer.Character.Humanoid.JumpPower)
		end
	end)
end

--set player active speed
local lastReportSpeed = 0
local Figure = script.Parent
local head: Part = Figure:WaitForChild("Head") :: Part

local function setSpeed(spd: number, acc: { string }): nil
	if spd ~= game.Players.LocalPlayer.Character.Humanoid.WalkSpeed then
		local increase = spd - game.Players.LocalPlayer.Character.Humanoid.WalkSpeed
		game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = spd
		particles.EmitParticle(localplayer, increase)

		local joined = textUtil.stringJoin(",", acc)
		if #acc then
			joined = " (" .. joined .. ")"
		end
		print(
			string.format(
				"adjust sped by %0.1f to: %0.1f - emit %0.1f%s",
				game.Players.LocalPlayer.Character.Humanoid.WalkSpeed - lastReportSpeed,
				game.Players.LocalPlayer.Character.Humanoid.WalkSpeed,
				increase,
				joined
			)
		)
		lastReportSpeed = game.Players.LocalPlayer.Character.Humanoid.WalkSpeed
		local hVel = head.AssemblyLinearVelocity + Vector3.new(0, -head.AssemblyLinearVelocity.Y, 0)
		local mag = hVel.Magnitude
		spdTl.Text = string.format("%0.1fd/s\n%0.1f max", mag, game.Players.LocalPlayer.Character.Humanoid.WalkSpeed)
	end
end

local lastPos = Vector3.new(0, 0, 0)

--continuously run and attempt to raise player speed again.
local function reCheckSpeed(): nil
	local now = tick()
	local gap = now - lastSpeedCheck
	if checkSpeedDebounce then
		return
	end
	checkSpeedDebounce = true
	if walking then
		checkSpeedDebounce = false
		return
	end

	--just debounce water events one time.
	local waterdebounce = false
	local signtouchdebounce = false

	-- if user is continuously moving, increase their speed.
	--TODO: fix this  so that you accelerate quickly at first, then slower.
	--TODO: badges for high speeds.

	local adder = 0
	local pos = localplayer.Character.HumanoidRootPart.Position
	local rise = pos.Y - lastPos.Y

	local acc: { string } = {}

	--natural speedup.
	if tpUtil.getDist(pos, lastPos) > 0.2 then
		if lastFloor == nil then
			adder = 0
		elseif lastFloor == Enum.Material.Air then
			adder = -3 * gap
		else
			local md = movementEnums.floor2movementData[lastFloor.Value]
			if md == nil then
				warn("missing :" .. tostring(lastFloor))
			else
				--const 2 here, adjustable.
				adder = 2 * md.acceleration * gap
			end
		end
	else
		adder = -20 * gap
	end

	lastPos = pos
	local runSpeedMax = math.max(globalRunSpeedMax + adder, 45)

	if changedFloor then
		changedFloor = false
		runSpeedMax = runSpeedMax * 0.99
		table.insert(acc, "floor change penalty to " .. lastFloor.Value)
	end
	local ii = 0

	local anyjump = false
	local anyfall = false
	while speedEvents.events ~= nil and #speedEvents.events > 0 do
		local ev = speedEvents.events[1]
		ii += 1
		-- print("loop " .. tostring(ii) .. "  handling event: " .. movementEnums.Id2SpeedEventName[ev.type])
		table.remove(speedEvents.events, 1)
		--global speed increases by N every M seconds, bumped down by user actions.

		--if user is climbing without jumping, also punish them

		if ev.type == movementEnums.SpeedEventName2Id.JUMP then
			anyjump = true
			table.insert(acc, movementEnums.Id2SpeedEventName[ev.type])
			runSpeedMax += 0
		elseif ev.type == movementEnums.SpeedEventName2Id.GETAIR then
			anyfall = true
			table.insert(acc, movementEnums.Id2SpeedEventName[ev.type])
			runSpeedMax -= 3
		elseif ev.type == movementEnums.SpeedEventName2Id.LAVA then
			table.insert(acc, movementEnums.Id2SpeedEventName[ev.type])
			runSpeedMax -= 6
		elseif ev.type == movementEnums.SpeedEventName2Id.SMASH then
			table.insert(acc, movementEnums.Id2SpeedEventName[ev.type])
			runSpeedMax -= 6
		elseif ev.type == movementEnums.SpeedEventName2Id.WATER then
			if not waterdebounce then
				runSpeedMax -= 6
				waterdebounce = true
				table.insert(acc, movementEnums.Id2SpeedEventName[ev.type])
			end
		elseif ev.type == movementEnums.SpeedEventName2Id.TOUCHSIGN then
			if not signtouchdebounce then
				--magic touch to reset.
				globalRunSpeedMax = 68
				runSpeedMax = 68
				setSpeed(68, { "touchsign." })
				signtouchdebounce = true
			end
		elseif ev.type == movementEnums.SpeedEventName2Id.FALLDOWN then
			globalRunSpeedMax = 40
			runSpeedMax = 40
			setSpeed(40, { "falldown" })
		else
			warn("Unhandled event.")
		end
	end

	if rise > 0 then
		if not anyjump and not anyfall then
			local penalty = rise * gap * 1.0
			runSpeedMax -= penalty
			table.insert(acc, string.format("rise penalty %0.1f", penalty))
		end
	elseif rise < 0 then
		local gain = -1 * rise * gap * 1.5
		runSpeedMax += gain
		table.insert(acc, string.format("fall benefit %0.1f", gain))
	end

	globalRunSpeedMax = runSpeedMax
	setSpeed(runSpeedMax, acc)
	checkSpeedDebounce = false
	lastSpeedCheck = now
end

local function SetupFloorIsLava(cb) end

function setupKeyboardCommandsForMovement()
	local function handle(input: InputObject, gameProcessedEvent: boolean)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if gameProcessedEvent then
			return
		end
		local kc = input.KeyCode
		local kind = ""
		if input.UserInputState == Enum.UserInputState.Begin then
			kind = "begin"
		elseif input.UserInputState == Enum.UserInputState.Change then
			kind = "change"
		elseif input.UserInputState == Enum.UserInputState.End then
			kind = "end"
		else
			warn("bad state." .. tostring(input.UserInputState))
		end

		if kind == "begin" then
			if kc == Enum.KeyCode.LeftShift then
				walking = true
				setSpeed(16, { "walk" })
			end
		elseif kind == "end" then
			if kc == Enum.KeyCode.LeftShift then
				walking = false
			end
		end
	end
	UserInputService.InputChanged:Connect(handle)
	UserInputService.InputBegan:Connect(handle)
	UserInputService.InputEnded:Connect(handle)
end

local function setupSpeedCheckingAdjustmentLoop()
	spawn(function()
		while true do
			wait()
			reCheckSpeed()
		end
	end)
end

function init()
	SetupFloorIsLava(function()
		speedEvents.addEvent({ type = movementEnums.SpeedEventName2Id.LAVA, timems = tick() })
	end)

	SetupFloorChangeMonitor()

	movementEnums.SetWaterMonitoring(localplayer, function()
		speedEvents.addEvent({ type = movementEnums.SpeedEventName2Id.WATER, timems = tick() })
	end)

	game.Players.LocalPlayer.Character.Humanoid.Swimming:Connect(function()
		speedEvents.addEvent({ type = movementEnums.SpeedEventName2Id.WATER, timems = tick() })
	end)

	game.Players.LocalPlayer.Character.Humanoid.Jumping:Connect(function()
		speedEvents.addEvent({ type = movementEnums.SpeedEventName2Id.JUMP, timems = tick() })
	end)

	Humanoid.FallingDown:Connect(function()
		speedEvents.addEvent({ type = movementEnums.SpeedEventName2Id.FALLDOWN, timems = tick() })
	end)
	setupKeyboardCommandsForMovement()

	setupSpeedCheckingAdjustmentLoop()
end

init()
