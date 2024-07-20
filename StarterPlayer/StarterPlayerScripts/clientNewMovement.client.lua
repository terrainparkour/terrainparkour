--!strict

-- rewrite 2023.03.09 to fix bugs and implement percentage speedup movement well.
-- 2024.08 wow, the players have found this script. awesome.

local textUtil = require(game.ReplicatedStorage.util.textUtil)
local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)
local signMovementEnums = require(game.ReplicatedStorage.enums.signMovementEnums)
local warper = require(game.StarterPlayer.StarterPlayerScripts.util.warperClient)
local pulse = require(game.StarterPlayer.StarterPlayerScripts.pulse)
local movementUtil = require(game.StarterPlayer.StarterPlayerScripts.util.movementUtil)
local remotes = require(game.ReplicatedStorage.util.remotes)
--setups for super heavy, superjump, etc signs.
local specialSignMonitors = require(game.ReplicatedStorage.specialSignMonitors)
local LocalPlayer = game.Players.LocalPlayer
local PlayersService = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local particles = require(game.StarterPlayer.StarterPlayerScripts.particles)

local localPlayer = PlayersService.LocalPlayer

local vscdebug = require(game.ReplicatedStorage.vscdebug)

print("movement v3.")

---------ANNOTATION----------------
local doAnnotation = false
	or localPlayer.Name == "TerrainParkour"
	or localPlayer.Name == "Player2"
	or localPlayer.Name == "Player1"
doAnnotation = true
doAnnotation = false
local annotationStart = tick()
local annotate = function(s: string | any)
	if doAnnotation then
		if typeof(s) == "string" then
			print("localMovement3.: " .. string.format("%.1f", tick() - annotationStart) .. " : " .. s)
		else
			print("localMovement3.object. " .. string.format("%.1f", tick() - annotationStart) .. " : ")
			print(s)
		end
	end
end

----------events-------------

--INPUT from localTimer with either
-- 	1) RESET when the user kills a run or
--  2) the name of a speceial sign
local movementManipulationBindableEvent = remotes.getBindableEvent("MovementManipulationBindableEvent")

---------global state vars.--------------
local allIsSlippery = false

--there can and probably will be multipler per frame. hopefully they occur at different full times, though.
local movementHistoryQueue: { [number]: number } = {}
annotate("lastTouched set to nil.")
local lastTouchedTerrainFloor: Enum.Material? = nil

local globalIsWalking = false
local globalDefaultRunSpeed = 68
local globalDefaultWalkSpeed = 16
local globalDefaultJumpPower = 55

----------------UTILS---------------
--BARE set speed no meta or growth
--NOTE the normal run speed is technically called humanoid.WalkSpeed.
local InternalSetSpeed = function(speed: number)
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	if speed ~= humanoid.WalkSpeed then
		local increase = speed > humanoid.WalkSpeed
		humanoid.WalkSpeed = speed
		--TODO extract particle code.
		particles.EmitParticle(increase)
	end
end

-------------------------RESET MANAGEMENT FUNCTIONS-------------------------

--when a user touches a sign, completely reset this.
local ResetMovementHistoryQueue = function()
	movementHistoryQueue = {}
end

----------------------MAIN-------------------

--by default, player is not moving.
local addMovementEventTrackMovingStatus = false

local addMovementEvent = function(tick: number, event: number)
	if movementHistoryQueue[tick] ~= nil then
		warn("double EVENT WARNING")
	end
	if doAnnotation then
		local got = false
		for a, b in pairs(movementEnums.MOVEMENT_HISTORY_ENUM) do
			if event == b then
				got = true
				break
			end
		end
		if not got then
			annotate("invalid event")
		end
	end

	--because of the dumb way swmming works, continuously sending events,
	--we need to only add one on here when it's truly the last item.
	if event == movementEnums.MOVEMENT_HISTORY_ENUM.SWIMMING then
		local lastTickSeen = nil
		local lastTickEnum = nil
		for a, b in pairs(movementHistoryQueue) do
			if lastTickSeen == nil or a > lastTickSeen then
				lastTickEnum = b
				lastTickSeen = a
			end
		end
		if lastTickEnum == movementEnums.MOVEMENT_HISTORY_ENUM.SWIMMING then
			-- annotate("skipping adding repeated final swmming event.")
			return
		end
	end

	--movement works similarly. we'll spam moving events.
	if event == movementEnums.MOVEMENT_HISTORY_ENUM.START_MOVING then
		--if they're already moving, skip this event.
		if addMovementEventTrackMovingStatus == true then
			return
		end
		addMovementEventTrackMovingStatus = true
	end

	if event == movementEnums.MOVEMENT_HISTORY_ENUM.STOP_MOVING then
		--bump
		addMovementEventTrackMovingStatus = false
	end

	movementHistoryQueue[tick] = event
end

--a floor definitely changed.
local HandleFloorChanged = function(floorMaterial: Enum.Material, reason: string)
	if floorMaterial ~= lastTouchedTerrainFloor then
		annotate("HandleFloorChanged, reason=" .. reason)

		--set properties
		workspace.Terrain.CustomPhysicalProperties = movementEnums.GetPropertiesForFloor(floorMaterial)

		--tell floorcounters.
		specialSignMonitors.CountNewFloorMaterial(floorMaterial)

		--also add an event for this change.
		if floorMaterial == Enum.Material.Plastic then
			addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.PLASTIC)
		elseif floorMaterial == Enum.Material.Granite then
			addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.SIGN)
		else
			local movementEnumValue = movementEnums.TerrainEnum2MovementEnum[floorMaterial]
			if movementEnumValue == nil then
				warn("something else?")
				vscdebug.debug()
			else
				addMovementEvent(tick(), movementEnumValue)
			end
		end
		annotate("lastTouched set to " .. floorMaterial.Name)
		lastTouchedTerrainFloor = floorMaterial
	else
		warn(
			"never should happen, we got a floor changed event, but there was no lastTouchedTerrainFloor."
				.. floorMaterial.Name
				.. "reason:"
				.. reason
				.. "also, the lastFloorCHanged was: "
				.. tostring(lastTouchedTerrainFloor)
		)
	end
end

--when a special movement sign race is stopped, call this.
--NOTE: this also modifies lots of globals related to movement!
local FullyResetAllMovementProperties = function(reason: string)
	print(reason)
	vscdebug.debug()
	local character = localPlayer.Character
	annotate("rescale to 1.0")
	local sc = character:GetScale()
	annotate("current scale: " .. tostring(sc))
	character:ScaleTo(1)

	movementUtil.SetCharacterTransparency(localPlayer, 0)

	annotate("FullyResetAllMovementProperties:" .. reason)
	addMovementEventTrackMovingStatus = false

	annotate("lastTouched set to nil in fullyReset.")
	lastTouchedTerrainFloor = nil

	--reset all movement history
	ResetMovementHistoryQueue()
	addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.RESET)

	--reset for floor counting.
	specialSignMonitors.ResetFloorCounts()

	--------reset things based on current material----------

	--since you have no further guarantee this will be called again besides the moment the cancel is called
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

	--important to spam this and reset their current floor.
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	specialSignMonitors.CountNewFloorMaterial(humanoid.FloorMaterial)

	--clean up ragdoll etc states.
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
		warn("reset state yet char is in ragdoll.")
		--this happens because there is some lag in setting state
		--this can happen after warping
		--we should ban runs from this point, but don't currently.
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	annotate("Humanoid state is: " .. tostring(humanoid:GetState()))
	HandleFloorChanged(humanoid.FloorMaterial, "in FullyResetAllMovementProperties")
	allIsSlippery = false

	if humanoid.MoveDirection.Magnitude > 0 then
		addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.START_MOVING)
	else
		addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.STOP_MOVING)
	end
end

--either: restore everything to normal (when dying, restarting, cancelling, etc)
--OR set special movement mode due to touching a special sign.
-- explanation: the user can do events on the server or wherever
-- which imply that they should move or change.  things like that can currently
-- only be implemented on the client.  so the way we do it is we just
-- send events over to the client which it honestly applies.
-- obviously, a false client would not be subject to these limits.
-- (and actually it appears we just log the event into the move history,
-- and the recent move history is continuously computed. )
local lastExternalMovementControlActionReceived = movementEnums.MOVEMENT_HISTORY_ENUM.UNUSED
local externallyControlUserMovementMode = function(msg: signMovementEnums.movementModeMessage)
	-- annotate("received external restore message." .. tostring(msg.action))
	local t = tick()
	if
		msg.action == signMovementEnums.movementModes.RESTORE
		and lastExternalMovementControlActionReceived == signMovementEnums.movementModes.RESTORE
	then
		--we just skip repeated resets cause it's annoying.
		print("SKIP", msg.reason, msg)
		--really, this might be too aggressive and may open the door to too many non-restores.
		--really, well, i suppose it's that if there are other methods of modifying avatar traits, then this might inadvertently
		--omit the re-doing of restorating even when it was called for!
		return
	end
	lastExternalMovementControlActionReceived = msg.action

	-- todo 2024: it's slightly weird how for the movement direct changes like jumppower etc, I do not apply them
	-- here, but instead wait for the movementevents to be processed.
	-- but for the sign goal etc things, i do just directly apply them.
	-- is there a valid design reason for this distinction? it seems weird.
	if msg.action == signMovementEnums.movementModes.RESTORE then
		FullyResetAllMovementProperties("touchedSpecialSign: action=" .. msg.action .. ", reason=" .. msg.reason)
		return
	elseif msg.action == signMovementEnums.movementModes.NOJUMP then
		addMovementEvent(t, movementEnums.MOVEMENT_HISTORY_ENUM.NO_JUMP)
	elseif msg.action == signMovementEnums.movementModes.FASTER then
		addMovementEvent(t, movementEnums.MOVEMENT_HISTORY_ENUM.FASTER)
	elseif msg.action == signMovementEnums.movementModes.THREETERRAIN then
		addMovementEvent(t, movementEnums.MOVEMENT_HISTORY_ENUM.THREE_TERRAIN)
		specialSignMonitors.setupFloorTerrainMonitor(3)
	elseif msg.action == signMovementEnums.movementModes.FOURTERRAIN then
		addMovementEvent(t, movementEnums.MOVEMENT_HISTORY_ENUM.FOUR_TERRAIN)
		specialSignMonitors.setupFloorTerrainMonitor(4)
	elseif msg.action == signMovementEnums.movementModes.HIGHJUMP then
		addMovementEvent(t, movementEnums.MOVEMENT_HISTORY_ENUM.HIGH_JUMP)
	elseif msg.action == signMovementEnums.movementModes.NOGRASS then
		addMovementEvent(t, movementEnums.MOVEMENT_HISTORY_ENUM.NO_GRASS)
		specialSignMonitors.setupNoGrassMonitor()
	elseif msg.action == signMovementEnums.movementModes.COLD_MOLD then
		addMovementEvent(t, movementEnums.MOVEMENT_HISTORY_ENUM.COLD_MOLD)
		specialSignMonitors.setupMold()
	elseif msg.action == signMovementEnums.movementModes.SLIPPERY then
		addMovementEvent(t, movementEnums.MOVEMENT_HISTORY_ENUM.SLIPPERY)
		allIsSlippery = true
	elseif msg.action == signMovementEnums.movementModes.PULSED then
		addMovementEvent(t, movementEnums.MOVEMENT_HISTORY_ENUM.PULSED)
		pulse.DoLaunchForPulse(localPlayer.Character, localPlayer)
	elseif msg.action == signMovementEnums.movementModes.SHRINK then
		addMovementEvent(t, movementEnums.MOVEMENT_HISTORY_ENUM.SHRINK)
		local character = localPlayer.Character
		character:ScaleTo(0.5)
	elseif msg.action == signMovementEnums.movementModes.ENLARGE then
		addMovementEvent(t, movementEnums.MOVEMENT_HISTORY_ENUM.ENLARGE)
		local character = localPlayer.Character
		character:ScaleTo(2)
	elseif msg.action == signMovementEnums.movementModes.GHOST then
		addMovementEvent(t, movementEnums.MOVEMENT_HISTORY_ENUM.GHOST)
		movementUtil.SetCharacterTransparency(LocalPlayer, 0.9)
	end
end

--look at the floor, swimming, etc, and if there are events, then add them to the movement history queue.
--this should read everything, EXCEPT for jumping, swimming
--although, why don't I collect floor change events here actually? hmm
local CollectAndStoreMovementRelatedInfo = function(character)
	--NOTE ON SWIMMING AND JUMPING: these are handled directly from signal catchers,
	-- which add events DIRECTLY

	-- also raycast for water. this has never been tested very thoroughly
	-- but towards the end of 2022 this improved water detection quite
	-- a bit by forcing the player ot swimming state more when on thin water, for example.
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: Part
	spawn(function()
		local ii = 3.2
		local result: RaycastResult = nil

		while ii < 4.8 do
			if not rootPart then
				break
			end
			local pos = rootPart.Position
			if not pos then
				break
			end
			result = workspace:Raycast(
				rootPart.Position,
				Vector3.new(0, -1 * ii, 0), -- you might need to make this longer/shorter
				raycastParams
			)

			--despite the warning, nil raycast happens all the time.  Doh.
			--and raycasting appears not to work at all anyway.
			if result ~= nil then
				if result.Material == Enum.Material.Water then
					-- annotate("WATER.SWIM.FROMRAYCAST")
					addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.SWIMMING)
					break
				end
			end
			ii += 0.1
		end
	end)
end

--a note: while movement changes DO apply when a user is not in a run,
-- they have nearly no real effect since the user speed will be reset at the start of a run.
--yet, I typically only display movement speeds WHILE on an active run. Does this make sense?
--Should I pull run information into another UI?  Maybe a corner speed ui?
local CalculateAndApplyMovement = function(humanoid: Humanoid)
	-----------VALUES WE NEED TO FIGURE OUT FROM ITERATING------------
	local timeOnCurrentTerrainS: number

	--if you JUST jumped this is 4s and it degrades linearly so if you jumped 3s ago, this is 1s.  ALSO multiple historical jumps all count.
	local secondsOfJumpInWindow = 0
	local swamInLast4Seconds: boolean = false
	local lavaInLast4Seconds: boolean = false
	local runLengthInS = 0

	local now = tick()
	local show_history = true
	show_history = false

	--index, time
	local sortedHistoryEventTimes = {}
	for a, b in pairs(movementHistoryQueue) do
		table.insert(sortedHistoryEventTimes, a)
	end
	table.sort(sortedHistoryEventTimes)

	--what is this?
	local terrainGap = 0

	--accumulator over the player's movement history.
	--if they are not nominally moving, we want to floor their run time & time on terrain
	local playerIsAllegedlyMoving = false

	local eventCount = 0
	local jumpPowerMultiplier = 1.0
	local fasterSignSpeedMultiplier = 1.0
	local isAffectedByCold_Mold = false
	local isAffectedByHighJump = false
	local isAffectedBySlippery = false
	local crashLanded = false
	local crashLanded2 = false
	local lastNonAirMaterialEnumValue: number = nil
	--there MUST be a single RESET event to start every run.
	for _, tickEventHappened in pairs(sortedHistoryEventTimes) do
		eventCount += 1
		local historicalEvent = movementHistoryQueue[tickEventHappened]
		local eventAgeS = now - tickEventHappened
		local name = movementEnums.REVERSED_MOVEMENT_HISTORY_ENUM[historicalEvent]
		if show_history then
			--only show last 30 events.
			if #sortedHistoryEventTimes - eventCount < 25 then
				annotate(string.format("%d. %0.3f ago - %s", eventCount, eventAgeS, name))
			end
		end
		if historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.RESET then
			runLengthInS = eventAgeS
		end

		--we DO record AIR.  So if a user does: grass, air, grass again, the 2nd grass should not reset the time on the terrain
		--this enables users to keep their terrain-time-run, even while jumping. They still suffer jumping penalties.
		if movementEnums.EnumIsTerrain(historicalEvent) then
			if historicalEvent ~= lastNonAirMaterialEnumValue then
				terrainGap = eventAgeS
				lastNonAirMaterialEnumValue = historicalEvent
			end
		end
		--if they are on terrain for 10s, but 4s into it they (were walking, and then start running), reset terrain time from the moment they run.
		--if no run appears, then obviously they are either still walking, or never walked+run combo.
		--ALSO banning this so that shiftlock doesn't ruin things.
		-- if historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.RUN then
		-- 	-- terrainGap = eventAgeS
		-- end
		if historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.START_MOVING then
			playerIsAllegedlyMoving = true
			--similarly, if they stop, reset time COUNTING FROM WHEN THEY STARTED MOVING AGAIN!
			terrainGap = eventAgeS
		end
		--if a player is say at +3.4% from on terrian, and jumps, immedialy kill that (AND do the jump penalty). When they hit the ground nothing new will happen and they'll continue killing the jump pen.
		-- if historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.NOT_JUMPING then
		-- 	-- note: do NOT reset time when jumping - just give jump penalty, but when the jump shadow is done the normal speedup continues.
		-- 	-- terrainGap = eventAgeS
		-- end
		if historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.STOP_MOVING then
			--if we stopped previously, but ARE NOW moving then the max run length is this time.
			--and if we ended up stopping moving, then these will be set to zero again later.
			--so, for example we set terrainGap to either 1) the time the player hit a new terrain 2) the time they stopped (killing histoyry), or 0 (if at end of run they were stopped)
			--i.e. even if they stopped 4s ago, this section will set runlength to "4s" and the final stoppage will reset it to 0.
			terrainGap = eventAgeS
			runLengthInS = eventAgeS
			playerIsAllegedlyMoving = false
		end
		if eventAgeS < 3 and historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.JUMPING then
			secondsOfJumpInWindow = secondsOfJumpInWindow + 3 - eventAgeS
		end

		if eventAgeS < 4 and historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.CRACKED_LAVA then
			lavaInLast4Seconds = true
			terrainGap = eventAgeS
		end
		if eventAgeS < 4 and historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.SWIMMING then
			swamInLast4Seconds = true
			terrainGap = eventAgeS
		end
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Swimming then
			swamInLast4Seconds = true
			terrainGap = eventAgeS
		end
		if eventAgeS < 1 and historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.CRASH_LAND then
			crashLanded = true
		end
		if eventAgeS < 2 and historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.CRASH_LAND2 then
			crashLanded2 = true
		end

		--special signs.
		if historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.NO_JUMP then
			jumpPowerMultiplier = 0
		end
		if historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.FASTER then
			fasterSignSpeedMultiplier = 91 / 68
		end
		if historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.COLD_MOLD then
			-- isAffectedByColdMold = true
			isAffectedByCold_Mold = true
		end
		if historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.HIGH_JUMP then
			isAffectedByHighJump = true
		end
		if historicalEvent == movementEnums.MOVEMENT_HISTORY_ENUM.SLIPPERY then
			isAffectedBySlippery = true
		end
	end

	if show_history then
		annotate(string.format("time in this terrain: %0.1f", terrainGap))
		annotate("events: " .. tostring(eventCount))
	end

	--------------SLIPPERINESS------------------
	if allIsSlippery then
		workspace.Terrain.CustomPhysicalProperties = movementEnums.GetIceProperties()
	end

	---------------------------WALKING BAIL-----------------------
	if globalIsWalking then
		InternalSetSpeed(globalDefaultWalkSpeed)
		return
	end

	--reset the effective run start time and on-terrain time.
	if not playerIsAllegedlyMoving then
		-- annotate("Player not moving.")
		terrainGap = 0
		runLengthInS = 0
	end

	timeOnCurrentTerrainS = terrainGap

	--we iterate over all recent events in order, determining the relevant base numbers
	--base run speed
	--base jump height
	--AND accumulating debuffs (from jumping, hitting ground, time on terrain)

	--CONSTANTS
	--start speeding up immediately, tried 0.6 before and it felt like a bug.
	local timeOnTerrainTilSpeedup = 0.0
	local effectiveTimeOnCurrentTerrain = math.max(0, timeOnCurrentTerrainS - timeOnTerrainTilSpeedup)

	local listOfReasonsForSpeed: { string } = {}
	--VALUES TO CALCULATE BASED ON HISTORY
	local baseSpeedOnCurrentTerrain = globalDefaultRunSpeed
	local floorJumpPowerMultiplier = movementEnums.GetJumpPowerByFloorMultipler(humanoid.FloorMaterial)

	----------------------CALCULATIONS--------------------------

	------------DISABLED: Global run length speed up ----- too confusing & unnatural------------
	local speedMultiplerFromRunLength = 1
	if false then
		--note that this will continuously increase if the player just sits around...
		--should we just not have speedups / changes at all when a player is exploring? Hmm.

		if runLengthInS < 20 then
			--from 1.0 to 1.02
			speedMultiplerFromRunLength = 1 + (runLengthInS / 1000)
		else
			speedMultiplerFromRunLength = 1.02 + (math.log(runLengthInS) - math.log(20)) / 100
		end

		if speedMultiplerFromRunLength > 1 then
			table.insert(
				listOfReasonsForSpeed,
				string.format("speedup by %0.2f%% due to run length", 100 * (speedMultiplerFromRunLength - 1))
			)
		end
	end

	----------Perhaps this doesn't need to be very strong, given a global speed increase over life of run, too?-------------
	local speedMultiplierFromSameTerrain = 1
	local timeAfterWhichSpeedupIsntLinear = 11
	if effectiveTimeOnCurrentTerrain < timeAfterWhichSpeedupIsntLinear then
		speedMultiplierFromSameTerrain = 1 + effectiveTimeOnCurrentTerrain / 120
	else
		speedMultiplierFromSameTerrain = 1
			+ timeAfterWhichSpeedupIsntLinear / 120
			+ (math.log(effectiveTimeOnCurrentTerrain) - math.log(timeAfterWhichSpeedupIsntLinear - 7)) / 80
	end

	if speedMultiplierFromSameTerrain > 1 then
		table.insert(
			listOfReasonsForSpeed,
			string.format(
				"speedup by %0.2f%% due to %0.1fs on same terrain",
				100 * (speedMultiplierFromSameTerrain - 1),
				effectiveTimeOnCurrentTerrain
			)
		)
	end

	-------------crash landings----------------

	local crashLandMultiplier = 1

	--disabled for now, too annoyingly hard to manage as a player.
	if false then
		if crashLanded then
			crashLandMultiplier = 0.95
		end
		if crashLanded2 then
			crashLandMultiplier = 0.92
		end
	end

	local jumpSpeedMultiplier = 1
	if isAffectedByHighJump then
		jumpPowerMultiplier = jumpPowerMultiplier * 1.4
	end
	if secondsOfJumpInWindow > 0 then
		if isAffectedByHighJump then
			jumpSpeedMultiplier = 56 / 68
		else
			local jumpSpeedDebuffPercentage = 1.5 * secondsOfJumpInWindow
			jumpSpeedMultiplier = 1 - jumpSpeedDebuffPercentage / 100
		end
	end

	if jumpSpeedMultiplier ~= 1 then
		table.insert(listOfReasonsForSpeed, string.format("Jump multiplier: %0.2f%%.", jumpSpeedMultiplier / 100 - 1))
	end

	local actualSwimSpeedMultiplier = 1
	if swamInLast4Seconds then
		table.insert(listOfReasonsForSpeed, "Touched water recently.")
		if isAffectedByCold_Mold then
			actualSwimSpeedMultiplier = 70 / 68
		else
			actualSwimSpeedMultiplier = 0.45
		end
	end

	local speedMultiplierFromSlipperyAfterJump = 1
	if isAffectedBySlippery then
		jumpPowerMultiplier = jumpPowerMultiplier * 43 / 55
		-- if secondsOfJumpInWindow > 0 then
		-- 	speedMultiplierFromSlipperyAfterJump = 46 / 68
		--  table.insert(listOfReasonsForSpeed, "run slowed down from slippery touch.")
		-- end
	end

	local actualLavaSpeedMultiplier = 1

	if lavaInLast4Seconds then
		table.insert(listOfReasonsForSpeed, "Touched lava recently.")
		if isAffectedByCold_Mold then
			actualLavaSpeedMultiplier = 71 / 68
		else
			actualLavaSpeedMultiplier = 0.5
			humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
			annotate("MADE RAGDOLL.")
			floorJumpPowerMultiplier = 0.2
		end
	end

	local coldMoldSpeedEffectMultiplier = 1.0
	if isAffectedByCold_Mold then
		coldMoldSpeedEffectMultiplier = 45 / 68
	end

	--------------------------SPEED CALCULATION----------------------
	local effectiveSpeed = baseSpeedOnCurrentTerrain
		* speedMultiplerFromRunLength
		* crashLandMultiplier
		* speedMultiplierFromSameTerrain
		* speedMultiplierFromSlipperyAfterJump
		* jumpSpeedMultiplier
		* actualSwimSpeedMultiplier
		* actualLavaSpeedMultiplier
		* fasterSignSpeedMultiplier
		* coldMoldSpeedEffectMultiplier
	--optionally: should I just max this effect?
	if #listOfReasonsForSpeed > 0 and false then
		annotate(
			string.format(
				"effective speed: %0.1f due to: %s",
				effectiveSpeed,
				"\n\t" .. textUtil.stringJoin("\n\t", listOfReasonsForSpeed)
			)
		)
	end

	InternalSetSpeed(effectiveSpeed)

	-----------JUMP POWER CALCULATION-----------------
	humanoid.JumpPower = globalDefaultJumpPower * floorJumpPowerMultiplier * jumpPowerMultiplier
end

local recheckMovementPropertiesDebounce = false

--------------THIS SHOULD BE RUN EVERY 1/60th of a second---------------------------------------------------------------
-----------------IT Tracks all changes, and recalculates player speed based on entire history.------------
------------NOBODY ELSE SHOULD CALL THis.  JUST modify globals and let this pick up the new change.-===================
local MovementLoop = function()
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	-- print(string.format("Speed: %0.1f", character.PrimaryPart.Velocity.Magnitude))
	if recheckMovementPropertiesDebounce then
		warn("bailing recheckMovementPropertiesDebounce - should never happen.")
	end
	recheckMovementPropertiesDebounce = true

	CollectAndStoreMovementRelatedInfo(character)
	CalculateAndApplyMovement(humanoid)
	recheckMovementPropertiesDebounce = false
end

--shift to WALK now.
-- when you hit shift, set up an action upon unshift.  the action will be: disconnect itself, unset walking, recheck speed.  then set walking and speed.
local InputChanged = function(input: InputObject, gameProcessedEvent: boolean, kind: string)
	annotate("Input changed, kind: " .. tostring(kind))
	if gameProcessedEvent then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if input.UserInputState == Enum.UserInputState.Begin then
			globalIsWalking = true
			addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.WALK)
		end
		if input.UserInputState == Enum.UserInputState.End then
			addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.RUN)
			globalIsWalking = false
		end
	end
end

function init()
	--this has taken over much of the information collection stages since doing it during "pull data" doesn't work very well.

	localPlayer.CharacterAdded:Connect(function()
		FullyResetAllMovementProperties("reset on character added.")
		local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid

		

		humanoid.Jumping:Connect(function(isActive)
			if isActive then
				addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.JUMPING)
			else --system said "they're not jumping anymore"
				addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.NOT_JUMPING)
			end
		end)
		humanoid.Swimming:Connect(function(speed)
			annotate("got swimming+speed:" .. tostring(speed))
			addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.SWIMMING)
		end)
		humanoid.GettingUp:Connect(function(isActive)
			if isActive then
				addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.GETTING_UP)
			else
				addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.GETTING_UP_INACTIVE)
			end
		end)

		humanoid.FallingDown:Connect(function(isActive)
			if isActive then
				addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.FALLING_DOWN)
			else
				addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.FALLING_DOWN_INACTIVE)
			end
		end)

		---SIGNAL TRACKING SETUP.--------
		humanoid.Ragdoll:Connect(function(isActive)
			if isActive then
				addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.RAGDOLL)
			else
				addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.RAGDOLL_INACTIVE)
			end
		end)

		humanoid.StateChanged:Connect(function(old, new)
			if new == Enum.HumanoidStateType.Landed then
				annotate("Landed.")
				if character.PrimaryPart.AssemblyLinearVelocity.Magnitude >= 220 then
					--TODO play oof
					addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.CRASH_LAND2)
				elseif character.PrimaryPart.AssemblyLinearVelocity.Magnitude > 150 then
					addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.CRASH_LAND)
				end
			end
		end)

		humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
			HandleFloorChanged(humanoid.FloorMaterial, "ChangedSignal")
		end)

		humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
			if humanoid.MoveDirection.Magnitude > 0 then
				addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.START_MOVING)
			else
				addMovementEvent(tick(), movementEnums.MOVEMENT_HISTORY_ENUM.STOP_MOVING)
			end
		end)

		-------when player warps we need to reset their physical state -----------
		local warpStartingBindableEvent = remotes.getBindableEvent("warpStartingBindableEvent")
		warpStartingBindableEvent.Event:Connect(function(ms: number)
			--when war happens we need to reset their physical state totally.
			FullyResetAllMovementProperties("received warp event.")
		end)
	end)

	particles.SetupParticleEmitter(localPlayer)

	--------------------LISTEN TO ALL BEGIN/END/CHANGES-------------------
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		InputChanged(input, gameProcessedEvent, "began input")
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		InputChanged(input, gameProcessedEvent, "changed input")
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		InputChanged(input, gameProcessedEvent, "end input")
	end)

	movementManipulationBindableEvent.Event:Connect(externallyControlUserMovementMode)

	spawn(function()
		while true do
			wait(1 / 30)
			MovementLoop()
		end
	end)
end

init()
