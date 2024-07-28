--!strict

-- listens to avatar events and adjusts movement speed accordingly.
-- you always speed up according to terrain.
-- the only special rules are, when you touch a sign at all, your local history is cleared.
-- if it's a start: you get the traits of the sign. if end, you lose them.
-- and if it's a retouch you keep traits BUT reset time.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)
local remotes = require(game.ReplicatedStorage.util.remotes)

local mt = require(game.ReplicatedStorage.avatarEventTypes)

local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent

local Players = game:GetService("Players")

--------------- GLOBAL PLAYER --------------
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
--------- GLOBAL STATE VARS --------------
local isMovementBlockedByWarp = false

-- the game name of the applied physics movement type now.
local activeCurrentWorldPhysicsName = "default"

local lastTouchedFloor: Enum.Material? = nil

----------------- MOVEMENT HISTORY -----------------
-- a list of movement history events, in a sane order.
local movementEventHistory: { mt.avatarEvent } = {}
local activeRunSignName = ""

------------------------ UTILS -----------------------

local adjustPlayerMovementGui = function(speed, jumpPower)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local speedSgui: ScreenGui = playerGui:FindFirstChild("SpeedGui") :: ScreenGui
	if not speedSgui then
		speedSgui = Instance.new("ScreenGui") :: ScreenGui
		if speedSgui == nil then
			_annotate("xwef")
			return
		end
		speedSgui.Parent = playerGui
		speedSgui.Name = "SpeedGui"
		speedSgui.Enabled = true
	end

	local speedFrame = Instance.new("Frame")
	speedFrame.Parent = speedSgui
	local findScreenGuiName = "SpeedFrame"
	speedFrame.Name = findScreenGuiName
	speedFrame.Size = UDim2.new(0.06, 0, 0.06, 0)
	speedFrame.Position = UDim2.new(0.90, 0, 0.93, 0)

	local vlayout = Instance.new("UIListLayout")
	vlayout.Parent = speedFrame
	vlayout.FillDirection = Enum.FillDirection.Vertical
	vlayout.VerticalAlignment = Enum.VerticalAlignment.Center
	vlayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local speedText = string.format("%0.3f", speed)
	local speedLabel = Instance.new("TextLabel")
	speedLabel.Parent = speedFrame
	speedLabel.Text = speedText
	speedLabel.TextScaled = true
	speedLabel.Size = UDim2.new(1, 0, 0.5, 0)

	local jumpText = string.format("%0.3f", jumpPower)
	local jumpLabel = Instance.new("TextLabel")
	jumpLabel.Parent = speedFrame
	jumpLabel.Text = jumpText
	jumpLabel.TextScaled = true
	jumpLabel.Size = UDim2.new(1, 0, 0.5, 0)
end

local InternalSetJumpPower = function(jumpPower: number)
	if jumpPower == humanoid.JumpPower then
		return
	end
	local oldJumpPower = humanoid.JumpPower
	local gap = math.abs(jumpPower - oldJumpPower)
	if gap < 0.01 then
		return
	end
	humanoid.JumpPower = jumpPower
	fireEvent(mt.avatarEventTypes.DO_JUMPPOWER_CHANGE, {
		oldJumpPower = oldJumpPower,
		newJumpPower = jumpPower,
	})
	-- adjustPlayerMovementGui(humanoid.WalkSpeed, humanoid.JumpPower)
end

-- NOTE the normal run speed is technically called humanoid.WalkSpeed.
local InternalSetSpeed = function(speed: number)
	if speed == humanoid.WalkSpeed then
		return
	end
	local oldSpeed = humanoid.WalkSpeed
	local gap = math.abs(speed - oldSpeed)
	if gap < 0.01 then
		return
	end
	humanoid.WalkSpeed = speed

	-- Correcting the type of the details parameter to mt.avatarEventDetails
	fireEvent(mt.avatarEventTypes.DO_SPEED_CHANGE, {
		oldSpeed = oldSpeed,
		newSpeed = speed,
	})
	-- adjustPlayerMovementGui(humanoid.WalkSpeed, humanoid.JumpPower)
end

local function ApplyNewPhysicsFloor(name: string, props: PhysicalProperties)
	if activeCurrentWorldPhysicsName ~= name then
		workspace.Terrain.CustomPhysicalProperties = props
		activeCurrentWorldPhysicsName = name
		_annotate("applying physics for:" .. name)
	end
end

------------------- FLOOR ----------------
local ApplyFloorPhysics = function(ev: mt.avatarEvent)
	if not ev.details or not ev.details.floorMaterial then
		_annotate("applied physics on missing data.")
		return
	end
	local eventFloor: Enum.Material? = ev.details.floorMaterial

	if eventFloor == nil then
		return
	end
	if eventFloor == Enum.Material.Air then
		return
	end
	if eventFloor == lastTouchedFloor then
		return
	end

	local desiredPhysicsDetails = movementEnums.GetPropertiesForFloor(eventFloor)
	local desiredPhysicsName = desiredPhysicsDetails.name
	if activeRunSignName ~= "Salekhard" then
		ApplyNewPhysicsFloor(desiredPhysicsName, desiredPhysicsDetails.prop)
	end

	lastTouchedFloor = eventFloor
end

----------------------- SPEED ADJUSTMENTS - CONTINUOUS FOR ALL -----------------------
-- this enables us to do things even outside of a run: there may be locations which you can only get to
-- if you run up to them for a long time (in or outside of a run)

-- based on the history we have now, adjust the player's speed. --
-- we monitor all avatar events we care about, and add them to a movement queue just as they are.
-- then every nth of a second we recalculate the current speed based on them.

-- regarding runs: it should only take inputs on the globals set by run monitors.
-- but otherwise it's its own thing.
-- also, it has a lock now, because we call it directly so often whenever a presumably meaningful signal comes in.
local debounceAdjustSpeed = false
local adjustSpeed = function()
	if debounceAdjustSpeed then
		_annotate("locked out of adjustSpeed.")
		return
	end
	debounceAdjustSpeed = true

	if not humanoid then
		_annotate("not humanoid")
		debounceAdjustSpeed = false
		return
	end

	-- if they've been swimming in the past 4s, set swimming.
	local swamInLast4Seconds: boolean = false

	-- if they've been touching lava in the past 4s, set lava.
	local lavaInLast4Seconds: boolean = false

	-- if you JUST jumped this is 4s and it degrades linearly so if you jumped 3s ago, this is 1s.  ALSO multiple historical jumps all count.
	local secondsOfJumpInWindow = 0

	local adjustSpeedStartTick = tick()

	-- how long we've been running (or jumping? on this terrain.)
	local startTimeOnThisTerrain = 0

	--are they continuing to move at end of processing all events?
	local playerIsMoving = false
	local globalIsWalking = false

	local runJumpPowerMultiplier = 1.0
	local fasterSignSpeedMultiplier = 1.0

	-- as we are reviewing history, we track the contemporaneous active terrain.
	local activeTerrain: Enum.Material? = nil

	-- this only covers things that happen after a sign is touched.
	for _, ev in pairs(movementEventHistory) do
		if isMovementBlockedByWarp then
			_annotate("broke out of adjust speed due to warp.")
			debounceAdjustSpeed = false
			return
		end
		local eventAge = adjustSpeedStartTick - ev.timestamp

		-- we DO record AIR.  So if a user does: grass, air, grass again, the 2nd grass should not reset the time on the terrain
		-- this enables users to keep their terrain-time-run, even while jumping. They still suffer jumping penalties.
		if ev.eventType == mt.avatarEventTypes.FLOOR_CHANGED then
			if ev.details == nil then
				error("bad event in floor changed.")
			end

			--- detect a change in floor material, and reset time on terrain if so ---
			if movementEnums.EnumIsTerrain(ev.details.floorMaterial) then
				-- if we wanted to treat the two grass types as identical, this would be where we would do that.
				-- or maybe, different but at least not resetting.
				if ev.details.floorMaterial ~= activeTerrain then
					startTimeOnThisTerrain = eventAge
					activeTerrain = ev.details.floorMaterial
				end
			end

			---- also notice if they've touched lava recently ---
			if eventAge < 4 and ev.details.floorMaterial == Enum.Material.CrackedLava then
				lavaInLast4Seconds = true

				-- this is necessary because lava penalty is from the last time they touched lava
				-- whereas the prior check just triggers when they initially touch it (as a change)
				startTimeOnThisTerrain = eventAge
			end

		-- if they begin to walk or run during the time, we don't actually care.
		elseif ev.eventType == mt.avatarEventTypes.KEYBOARD_WALK then
			globalIsWalking = true
		elseif ev.eventType == mt.avatarEventTypes.KEYBOARD_RUN then
			globalIsWalking = false
		-- if they stopped moving
		elseif ev.eventType == mt.avatarEventTypes.CHANGE_DIRECTION then
			if ev.details == nil or ev.details.newMoveDirection == nil then
				error("bad cd")
			end
			if ev.details.newMoveDirection == Vector3.new(0, 0, 0) then
				playerIsMoving = false
				--similarly, if they stop, reset time COUNTING FROM WHEN THEY STARTED MOVING AGAIN!
				startTimeOnThisTerrain = eventAge
			else
				if not playerIsMoving then
					-- if a player isn't moving, but just started moving, then restart the counter
					-- of the time we allocate them to have been moving on this terrain.
					startTimeOnThisTerrain = eventAge
					playerIsMoving = true
				end
			end
		-- if they jumped in the last 3 seconds.
		elseif
			ev.eventType == mt.avatarEventTypes.STATE_CHANGED
			and eventAge < 3
			and ev.details
			and ev.details.newState == Enum.HumanoidStateType.Jumping
		then
			secondsOfJumpInWindow = secondsOfJumpInWindow + 3 - eventAge
		elseif ev.eventType == mt.avatarEventTypes.STATE_CHANGED then
			if eventAge < 4 and ev.details and ev.details.newState == Enum.HumanoidStateType.Swimming then
				swamInLast4Seconds = true
				startTimeOnThisTerrain = eventAge
			end
		elseif ev.eventType == mt.avatarEventTypes.CHARACTER_ADDED then
			startTimeOnThisTerrain = eventAge
		elseif ev.eventType == mt.avatarEventTypes.RUN_START then
			startTimeOnThisTerrain = eventAge
		elseif ev.eventType == mt.avatarEventTypes.RETOUCH_SIGN or ev.eventType == mt.avatarEventTypes.TOUCH_SIGN then
			startTimeOnThisTerrain = eventAge
		else
			_annotate("unhandled event type in adjustSpeed: " .. mt.avatarEventTypesReverse[ev.eventType])
		end
	end

	----------------- APPLY DATA -----------------
	if isMovementBlockedByWarp then
		_annotate("broke out of adjust speed due to warp2.")
		debounceAdjustSpeed = false
		return
	end
	------------- RESET TERRAIN SPEEDUP IF YOU STOP -------------------------
	if not playerIsMoving then
		startTimeOnThisTerrain = 0
	end

	------------- start speeding up immediately, tried 0.6 before and it felt like a bug.
	local timeOnTerrainTilSpeedup = 0.0 -------- <<< that is, as soon as you enter a terrain, start speeding up.
	local effectiveTimeOnCurrentTerrain = math.max(0, startTimeOnThisTerrain - timeOnTerrainTilSpeedup)

	------------- VALUES TO CALCULATE BASED ON HISTORY
	local jumpSpeedMultiplier = 1

	---------------------- SPEED CALCULATIONS --------------------------

	local speedMultiplerFromRunLength = 1
	local speedMultiplierFromSameTerrain = 1
	local timeAfterWhichSpeedupIsntLinear = 11

	------------- speedup goes nonlinear after 11s. This isn't ideal, it'd be better to have it continuously increasing but at a slower and slower rate.
	if effectiveTimeOnCurrentTerrain < timeAfterWhichSpeedupIsntLinear then
		speedMultiplierFromSameTerrain = 1 + effectiveTimeOnCurrentTerrain / 120
	else
		speedMultiplierFromSameTerrain = 1
			+ timeAfterWhichSpeedupIsntLinear / 120
			+ (math.log(effectiveTimeOnCurrentTerrain) - math.log(timeAfterWhichSpeedupIsntLinear - 7)) / 80
	end

	----------------- jump power ----------------
	--------------- CHANGES FROM BEING ON A RUN FROM A SPECIAL SIGN ----------------------
	if activeRunSignName == "Bolt" then
		fasterSignSpeedMultiplier = 91 / 68
	elseif activeRunSignName == "Fosbury" then
		runJumpPowerMultiplier = runJumpPowerMultiplier * 1.4
	elseif activeRunSignName == "Salekhard" then
		runJumpPowerMultiplier = runJumpPowerMultiplier * 43 / 55
	end
	if secondsOfJumpInWindow > 0 then
		if activeRunSignName == "Fosbury" then
			jumpSpeedMultiplier = 56 / 68
		else
			local jumpSpeedDebuffPercentage = 1.5 * secondsOfJumpInWindow
			jumpSpeedMultiplier = 1 - jumpSpeedDebuffPercentage / 100
		end
	end

	------------ swimming ------------------
	local actualSwimSpeedMultiplier = 1
	if swamInLast4Seconds then
		if activeRunSignName == "cOld mOld on a sLate pLate" then
			actualSwimSpeedMultiplier = 70 / 68
		else
			actualSwimSpeedMultiplier = 0.45
		end
	end

	------------- lava --------------
	local actualLavaSpeedMultiplier = 1
	local floorJumpPowerMultiplier = 1
	local lastFloorJumpPowerMultiplier = movementEnums.GetJumpPowerByFloorMultipler(lastTouchedFloor)
	if lavaInLast4Seconds then
		if activeRunSignName == "cOld mOld on a sLate pLate" then
			actualLavaSpeedMultiplier = 71 / 68
		else
			actualLavaSpeedMultiplier = 0.5
			humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
			floorJumpPowerMultiplier = 0.2
		end
	end

	local coldMoldSpeedEffectMultiplier = 1.0
	if activeRunSignName == "cOld mOld on a sLate pLate" then
		coldMoldSpeedEffectMultiplier = 45 / 68
	end

	----------- JUMP POWER -----------------

	local newJumpPower = movementEnums.constants.globalDefaultJumpPower
		* floorJumpPowerMultiplier
		* lastFloorJumpPowerMultiplier
		* runJumpPowerMultiplier

	InternalSetJumpPower(newJumpPower)

	--------------------------- NO SPEEDUPS DURING WALKING -----------------------
	if globalIsWalking then
		InternalSetSpeed(movementEnums.constants.globalDefaultWalkSpeed)
		debounceAdjustSpeed = false
		return
	end

	-------------------------- SPEED CALCULATION ----------------------
	local effectiveSpeed = movementEnums.constants.globalDefaultRunSpeed
		* speedMultiplerFromRunLength
		* speedMultiplierFromSameTerrain
		* jumpSpeedMultiplier
		* actualSwimSpeedMultiplier
		* actualLavaSpeedMultiplier
		* fasterSignSpeedMultiplier
		* coldMoldSpeedEffectMultiplier

	InternalSetSpeed(effectiveSpeed)
	debounceAdjustSpeed = false
end
-------------------------------- EVENT FILTERING ------------------------------

-- 2024: we monitor all incoming events and store ones which are relevant to movement per se.
-- basic policy: if they touch a floor, change the movementt rules to that type.
-- also store the event if it's important to us, so we can recalc speed.
local eventsWeCareAbout = {
	mt.avatarEventTypes.CHARACTER_ADDED,
	mt.avatarEventTypes.DIED,
	mt.avatarEventTypes.CHARACTER_REMOVING,
	mt.avatarEventTypes.CHARACTER_ADDED,

	mt.avatarEventTypes.FLOOR_CHANGED,
	mt.avatarEventTypes.KEYBOARD_RUN,
	mt.avatarEventTypes.KEYBOARD_WALK,
	mt.avatarEventTypes.STATE_CHANGED,
	mt.avatarEventTypes.CHANGE_DIRECTION,

	mt.avatarEventTypes.RUN_START,
	mt.avatarEventTypes.RUN_COMPLETE,
	mt.avatarEventTypes.RUN_KILL,
	mt.avatarEventTypes.RETOUCH_SIGN,
	-- mt.avatarEventTypes.TOUCH_SIGN,
	mt.avatarEventTypes.GET_READY_FOR_WARP,
	mt.avatarEventTypes.WARP_DONE,
}

local eventIsATypeWeCareAbout = function(ev: mt.avatarEvent): boolean
	for _, value in pairs(eventsWeCareAbout) do
		if value == ev.eventType then
			return true
		end
	end
	return false
end

local setRunEffectedSign = function(name: string)
	if name then
		_annotate("movement: set active sign to: " .. name)
	else
		_annotate("movement: unset active sign.")
	end
	activeRunSignName = name
	_annotate("set affected sign to: " .. tostring(name))
end

local receiveAvatarEvent = function(ev: mt.avatarEvent)
	_annotate("movement received: " .. mt.avatarEventTypesReverse[ev.eventType])
	if not eventIsATypeWeCareAbout(ev) then
		return
	end
	if ev.eventType == mt.avatarEventTypes.GET_READY_FOR_WARP then
		isMovementBlockedByWarp = true
		movementEventHistory = {}
		ApplyNewPhysicsFloor("default", movementEnums.constants.DefaultPhysicalProperties)
		setRunEffectedSign("")
		InternalSetSpeed(movementEnums.constants.globalDefaultRunSpeed)
		InternalSetJumpPower(movementEnums.constants.globalDefaultJumpPower)
		movementEventHistory = {}
		fireEvent(mt.avatarEventTypes.MOVEMENT_WARPER_READY, {})
		return
	elseif ev.eventType == mt.avatarEventTypes.WARP_DONE then
		movementEventHistory = {}
		ApplyNewPhysicsFloor("default", movementEnums.constants.DefaultPhysicalProperties)
		setRunEffectedSign("")
		InternalSetSpeed(movementEnums.constants.globalDefaultRunSpeed)
		InternalSetJumpPower(movementEnums.constants.globalDefaultJumpPower)
		movementEventHistory = {}
		isMovementBlockedByWarp = false
		return
	end

	if isMovementBlockedByWarp then
		_annotate("movement warping ignored event:" .. mt.avatarEventTypesReverse[ev.eventType])
		return
	end
	if
		ev.eventType ~= mt.avatarEventTypes.CHANGE_DIRECTION
		and ev.eventType ~= mt.avatarEventTypes.FLOOR_CHANGED
		and ev.eventType ~= mt.avatarEventTypes.STATE_CHANGED
	then
		_annotate(
			string.format(
				"\t\tmovement: received event: %s\tdelay=%0.4f",
				mt.avatarEventTypesReverse[ev.eventType],
				tick() - ev.timestamp
			)
		)
	end
	table.insert(movementEventHistory, ev)

	if ev.eventType == mt.avatarEventTypes.RUN_START then
		--- in a sense, we almost want to teleport you to the sign and reset your time from that point.
		if activeRunSignName ~= "" then
			_annotate("run started while already on a run. hmm")
		end

		--- nuke past history and start from here. -----------
		if not ev.details or not ev.details.relatedSignName then
			error("race started w/out data.")
		end
		activeRunSignName = ev.details.relatedSignName
		movementEventHistory = {}
		table.insert(movementEventHistory, ev)

		if ev.details and ev.details.relatedSignName then
			setRunEffectedSign(ev.details.relatedSignName)
		else
			_annotate("race started w/out data.")
		end
		if activeRunSignName == "Salekhard" then
			ApplyNewPhysicsFloor("ice", movementEnums.IceProps)
		end

	-- the list of history objects starts with a retouch or a touch always.
	-- why is start race different? well, races may have characteristic avatar forms which we don't want to mess with.
	-- so just leave that there.
	elseif ev.eventType == mt.avatarEventTypes.RETOUCH_SIGN then
		------ nuke history, and add a START event from here. ----------
		if activeRunSignName == "" then
			_annotate("retouch while not on a run huh")
		end
		movementEventHistory = {}
	elseif ev.eventType == mt.avatarEventTypes.RUN_KILL or ev.eventType == mt.avatarEventTypes.RUN_COMPLETE then
		if activeRunSignName == "" then
			_annotate("weird, ended run while not on one. hmmm")
			_annotate(ev.details.reason)
			-- actually this happens.
		end

		--- clear history and remove knowledge that we're on a run from a certain sign.
		setRunEffectedSign("")
		movementEventHistory = {}
		local desiredPhysicsDetails = movementEnums.GetPropertiesForFloor(humanoid.FloorMaterial)
		local desiredPhysicsName = desiredPhysicsDetails.name
		ApplyNewPhysicsFloor(desiredPhysicsName, desiredPhysicsDetails.prop)
	elseif
		ev.eventType == mt.avatarEventTypes.CHARACTER_ADDED
		or ev.eventType == mt.avatarEventTypes.CHANGE_DIRECTION
		or ev.eventType == mt.avatarEventTypes.STATE_CHANGED
		or ev.eventType == mt.avatarEventTypes.KEYBOARD_RUN
		or ev.eventType == mt.avatarEventTypes.KEYBOARD_WALK
	then
		-- do nothing here, just store the event
		-- in some sense, after keyboard stuff we want to clear history.
		-- but that would also clear historical lava touches for example, so we don't.
	elseif ev.eventType == mt.avatarEventTypes.FLOOR_CHANGED then
		ApplyFloorPhysics(ev)
	elseif ev.eventType == mt.avatarEventTypes.CHARACTER_REMOVING then
		setRunEffectedSign("")
		movementEventHistory = {}
	elseif ev.eventType == mt.avatarEventTypes.DIED then
		setRunEffectedSign("")
		movementEventHistory = {}
	else
		_annotate("unhandled movement event:" .. mt.avatarEventTypesReverse[ev.eventType])
	end

	-- we actually always want to adjust speed since it makes sense. you should still speedup,
	adjustSpeed()
end

---------------------- START CONTINUOUS ADJUSTMENT ------------
task.spawn(function()
	while true do
		adjustSpeed()
		wait(1 / 60)
	end
end)

--------------------- LISTEN TO EVENTS ---------------------

local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
AvatarEventBindableEvent.Event:Connect(receiveAvatarEvent)
InternalSetSpeed(movementEnums.constants.globalDefaultRunSpeed)
ApplyNewPhysicsFloor("default", movementEnums.constants.DefaultPhysicalProperties)

_annotate("end")
return {}
