--!strict

-- A listens to avatar events and adjusts movement speed accordingly.
-- you always speed up according to terrain.
-- the only special rules are, when you touch a sign at all, your local history is cleared.
-- if it's a start: you get the traits of the sign. if end, you lose them.
-- and if it's a retouch you keep traits BUT reset time.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)

local aet = require(game.ReplicatedStorage.avatarEventTypes)

local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent
local userData = require(game.StarterPlayer.StarterPlayerScripts.userData)
local speedGui = require(game.StarterPlayer.StarterPlayerScripts.guis.speedGui)

local Players = game:GetService("Players")

--------------- GLOBAL PLAYER --------------
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

--------- GLOBAL STATE VARS --------------
local isMovementBlockedByWarp = false

-- the game name of the applied physics movement type now.
local activeCurrentWorldPhysicsName = "default"
local lastNotifiedSpeed: number = 0
local minimumSpeedAdjustment = 0.2
-- we also at least always update speed every 2 seconds so you don't sit there stuck at -0.1% forever after stopping.
local lastUpdateSpeedTime = tick()
local maximumAllowedSpeedUpdateGap = 0.2

----------------- MOVEMENT HISTORY -----------------
-- a list of movement history events, in a true time order.
local movementEventHistory: { aet.avatarEvent } = {}
local activeRunSignName: string = ""
local lastTouchedFloor: Enum.Material? = nil

------------------------ UTILS -----------------------

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
	fireEvent(aet.avatarEventTypes.DO_JUMPPOWER_CHANGE, {
		oldJumpPower = oldJumpPower,
		newJumpPower = jumpPower,
		sender = "movement",
	})
end

-- NOTE the normal run speed is technically called humanoid.WalkSpeed.
local InternalSetSpeed = function(speed: number)
	--if nothing will change, do nothing.
	if speed == humanoid.WalkSpeed then
		return
	end

	local intendedSpeedChangeTotalSinceLastActualChange = math.abs(speed - lastNotifiedSpeed)
	-- we notify everyone (e.g. particles) that the speed has increased only this much.
	-- it's something like a gear system, actually.
	local now = tick()
	local timeGapSinceLastSpeedUpdate = now - lastUpdateSpeedTime
	if
		intendedSpeedChangeTotalSinceLastActualChange < minimumSpeedAdjustment
		and timeGapSinceLastSpeedUpdate < maximumAllowedSpeedUpdateGap
	then
		-- we have not changed enough to immediately actually change, and we are within the time limit,
		-- so just skip actually doing this speed update.
		return
	end

	-- okay we are going to actually update the player's speed.

	lastUpdateSpeedTime = now
	humanoid.WalkSpeed = speed
	-- Correcting the type of the details parameter to mt.avatarEventDetails
	-- _annotate(string.format("notified new speed: %0.3f", speed))
	fireEvent(aet.avatarEventTypes.DO_SPEED_CHANGE, {
		oldSpeed = lastNotifiedSpeed,
		newSpeed = speed,
		sender = "movement",
	})
	_annotate(string.format("Updating for speed: %0.1f=>%0.1f", lastNotifiedSpeed, speed))
	lastNotifiedSpeed = speed
	speedGui.AdjustSpeedGui(speed, humanoid.JumpPower)
end

local function ApplyNewPhysicsFloor(name: string, props: PhysicalProperties)
	if activeCurrentWorldPhysicsName ~= name then
		workspace.Terrain.CustomPhysicalProperties = props
		activeCurrentWorldPhysicsName = name
		_annotate("applying physics for:" .. name)
	end
end

------------------- FLOOR ----------------
local ApplyFloorPhysics = function(ev: aet.avatarEvent)
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
	if activeRunSignName == "Salekhard" then
		-- do nothing.
	else
		ApplyNewPhysicsFloor(desiredPhysicsName, desiredPhysicsDetails.prop)
		_annotate(string.format("applying physics for: %s", desiredPhysicsName))
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

local specialMovementAnnotate = false

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
	local adjustSpeedStartTick = tick()

	-- if they've CHANGED to swimming in the past 4s, OR ARE STILL SWIMMING, set swimming.
	local swamInLast4Seconds: boolean = false

	-- if they've been touching lava in the past 4s, set lava.
	local lavaInLast4Seconds: boolean = false

	-- if you JUST jumped this is 4s and it degrades linearly so if you jumped 3s ago, this is 1s.
	-- ALSO multiple historical jumps all count.
	local secondsOfJumpInWindow = 0

	-- how long we've been running (or jumping? on this terrain.)
	-- 2024.08.09 to fix a bug, I'm changing this from defaulting to zero,
	-- to defaulting to the time of the first event.
	-- that's because in cases likee retouch_sign, we nuke history, forgetting the player is moving.
	-- and so they show up as not moving throughout the race, and then we nuke it. that's quite bad.
	-- in general I need to stop treating the movement states as actually valid. That's the real problem.
	local howLongHasUserBeenOnThisTerrainS = 0

	--are they continuing to move at end of processing all events?
	local playerIsMoving = true --DOH just set this to true to start. To fix 2024.08.08 failure to accelerate.
	local globalIsWalking = false

	local runJumpPowerMultiplier = 1.0
	local fasterSignSpeedMultiplier = 1.0

	-- as we are reviewing history, we track the contemporaneous active terrain.
	local activeTerrain: Enum.Material? = nil

	--if the user is in a run, and just stands on a sign while otherwise valid, we shouldn't speed them up.
	-- OTOH if they continue running, they should get the benefit of having skipped momentarily onto this sign but still
	-- be considered to not have violated terrain consistency.
	local isTouchingNonTerrainRightNow = true
	if specialMovementAnnotate then
		_annotate("=-=-=-=-=-reconsidering SPEED-===-=-=-=-=-=-=-=-=-=-=-")
	end
	-- this only covers things that happen after a sign is touched.
	-- hmm okay SURELY the minimum start time on this terrain should be... the first event which occurred?
	-- because somehow people are reaching the end of the run with no speedup.
	_annotate("----------NEW ROUND-----------")
	for _, movementHistoryEvent: aet.avatarEvent in pairs(movementEventHistory) do
		if isMovementBlockedByWarp then
			_annotate("broke out of adjust speed due to warp.")
			debounceAdjustSpeed = false
			return
		end
		local eventAge = adjustSpeedStartTick - movementHistoryEvent.timestamp

		-- we DO record AIR.  So if a user does: grass, air, grass again, the 2nd grass should not reset the time on the terrain
		-- this enables users to keep their terrain-time-run, even while jumping. They still suffer jumping penalties.
		if movementHistoryEvent.eventType == aet.avatarEventTypes.FLOOR_CHANGED then
			--- detect a change in floor material, and reset time on terrain if so ---
			if movementEnums.EnumIsTerrain(movementHistoryEvent.details.floorMaterial) then
				-- if we wanted to treat the two grass types as identical, this would be where we would do that.
				-- or maybe, different but at least not resetting.
				if movementHistoryEvent.details.floorMaterial ~= activeTerrain then
					local useOldTerrainName = ""
					if activeTerrain then
						useOldTerrainName = activeTerrain.Name
					end

					_annotate(
						string.format(
							"Changed terrain types from %s=>%s.  \r\n\tOld time on material: %0.1f, \r\n\tthis eventAge, %0.1f, \r\n\tso updated howLongHasUserBeenOnThisTerrainS to just: %0.1f",
							useOldTerrainName,
							movementHistoryEvent.details.floorMaterial.Name,
							howLongHasUserBeenOnThisTerrainS,
							eventAge,
							math.max(howLongHasUserBeenOnThisTerrainS - 3, eventAge)
						)
					)

					-- basically we are always dealing with "how long (longer is better) has this same-terrain state been in effect?
					-- previously we would zero it out. But now we just do math.max (old time on -3, new eventAge).
					-- so if they jsut switched and that was the last action, then they either get 0 credit or old time -3.
					howLongHasUserBeenOnThisTerrainS = math.max(howLongHasUserBeenOnThisTerrainS - 3, eventAge)
					if specialMovementAnnotate then
						_annotate("accepted new floor actually: " .. movementHistoryEvent.details.floorMaterial.Name)
					end
					-- we reset the start time. subsequently this will have the effect of meaning the
					-- recalculation of their "gain speed" time is affected (negatively, for shorter gain-times.)
					activeTerrain = movementHistoryEvent.details.floorMaterial
					howLongHasUserBeenOnThisTerrainS = eventAge
				end
				isTouchingNonTerrainRightNow = false
			else
				-- basically if the very last thing they do is actively touch a sign, they will not speed up.
				-- _annotate("is touching nonterrain?)")
				-- isTouchingNonTerrainRightNow = true
				-- actually just disable this. I'll allow speedup on signs. But I will not allow pausing on a sign, stopping there, and gaining speedup.
			end

			-- also notice if they've touched lava recently ---
			if eventAge < 4 and movementHistoryEvent.details.floorMaterial == Enum.Material.CrackedLava then
				lavaInLast4Seconds = true

				-- this is necessary because lava penalty is from the last time they touched lava
				-- whereas the prior check just triggers when they initially touch it (as a change)

				-- TODO check if you touch lava for 4+ seconds do you reset and not feel penalties? just like the swim bug.
				_annotate("lava override resetting startTimeOnThisTerrain to " .. eventAge)
				howLongHasUserBeenOnThisTerrainS = eventAge
			end

		-- if they begin to walk or run during the time, we don't actually care.
		elseif movementHistoryEvent.eventType == aet.avatarEventTypes.KEYBOARD_WALK then
			globalIsWalking = true
		elseif movementHistoryEvent.eventType == aet.avatarEventTypes.KEYBOARD_RUN then
			globalIsWalking = false
		-- if they stopped moving
		elseif movementHistoryEvent.eventType == aet.avatarEventTypes.AVATAR_STARTED_MOVING then
			if not playerIsMoving then
				playerIsMoving = true
				howLongHasUserBeenOnThisTerrainS = eventAge
			end
		elseif movementHistoryEvent.eventType == aet.avatarEventTypes.AVATAR_STOPPED_MOVING then
			playerIsMoving = false
			howLongHasUserBeenOnThisTerrainS = eventAge
		elseif
			movementHistoryEvent.eventType == aet.avatarEventTypes.STATE_CHANGED
			and eventAge < 3
			and movementHistoryEvent.details
			and movementHistoryEvent.details.newState == Enum.HumanoidStateType.Jumping
		then
			_annotate(string.format("seconds of jump in window: %0.0f", secondsOfJumpInWindow))
			-- remember we only count jumps within the last 3 seconds. So, multiple of them can count.
			-- but not many.
			secondsOfJumpInWindow = secondsOfJumpInWindow + 3 - eventAge
		elseif movementHistoryEvent.eventType == aet.avatarEventTypes.STATE_CHANGED then
			if
				eventAge < 4
				and movementHistoryEvent.details
				and movementHistoryEvent.details.newState == Enum.HumanoidStateType.Swimming
			then
				swamInLast4Seconds = true
				howLongHasUserBeenOnThisTerrainS = eventAge
			end
		elseif movementHistoryEvent.eventType == aet.avatarEventTypes.CHARACTER_ADDED then
			howLongHasUserBeenOnThisTerrainS = eventAge
			-- elseif movementHistoryEvent.eventType == mt.avatarEventTypes.AVATAR_CHANGED_DIRECTION then
			-- do nothing. Although if we really want to do something interesting, we could use this information.
		elseif movementHistoryEvent.eventType == aet.avatarEventTypes.RUN_START then
			howLongHasUserBeenOnThisTerrainS = eventAge
		elseif movementHistoryEvent.eventType == aet.avatarEventTypes.RETOUCH_SIGN then
			howLongHasUserBeenOnThisTerrainS = eventAge
		else
			warn("unhandled event type in adjustSpeed: " .. aet.avatarEventTypesReverse[movementHistoryEvent.eventType])
		end
	end

	----------------- APPLY DATA -----------------

	------------- RESET TERRAIN SPEEDUP IF YOU STOP -------------------------
	if not playerIsMoving then
		if specialMovementAnnotate then
			_annotate("player is not moving so setting starttime to zero!!!")
		end
		howLongHasUserBeenOnThisTerrainS = 0
	end
	if isTouchingNonTerrainRightNow then
		if specialMovementAnnotate then
			_annotate("player is not touching terrain right ")
		end
		-- but we won't punish them if they jump off to continue norma.
		howLongHasUserBeenOnThisTerrainS = 0
	end

	if howLongHasUserBeenOnThisTerrainS == 0 then
		if specialMovementAnnotate then
			_annotate("startTimeOnThisTerrain ===> somehow " .. howLongHasUserBeenOnThisTerrainS)
		end
		-- this likely was a bug due to mistakenly not sending some initiating event that allows us to count at least the very beginning of the race as the minimum terrain time?
	end

	------------- start speeding up immediately, tried 0.6 before and it felt like a bug.
	local timeOnTerrainTilSpeedup = 0.0 -------- <<< that is, as soon as you enter a terrain, start speeding up.
	local effectiveTimeOnCurrentTerrain = math.max(0, howLongHasUserBeenOnThisTerrainS - timeOnTerrainTilSpeedup)

	------------- VALUES TO CALCULATE BASED ON HISTORY
	local jumpSpeedMultiplier = 1
	local currentRunJumpPowerMultiplier = 1

	---------------------- SPEED CALCULATIONS --------------------------

	local speedMultiplerFromRunLength = 1
	local speedMultiplierFromSameTerrain = 1

	local useProvisionalNewSpeed = false
	if useProvisionalNewSpeed then
		---------------PREVIOUS WORLD------------ (AKA movementV2)------------
		--[[local firstLinearSection = 11
        local firstLinearSectionDivider = 120
        
        if effectiveTimeOnCurrentTerrain < firstLinearSection then
            speedMultiplierFromSameTerrain = 1 + effectiveTimeOnCurrentTerrain / 120
        else
            speedMultiplierFromSameTerrain = 1
                + firstLinearSection / 120
                + (math.log(effectiveTimeOnCurrentTerrain) - math.log(firstLinearSection - 7)) / 80
        end
        ]]

		--------------NEW WORLD ----------------- AKA gotta beat the glitchers -------------------------
		local firstLinearSectionEnd = 1.5
		local firstLinearSectionDivider = 90

		local secondLinearSectionEnd = 4
		local secondLinearSectionDivider = 95

		local thirdLinearSectionEnd = 7
		local thirdLinearSectionDivider = 110

		local fourthLinearSectionEnd = 11
		local fourthLinearSectionDivider = 120

		local fifthLinearSectionEnd = 15
		local fifthLinearSectionDivider = 150

		---- SO in effect, you are linear for the first 5 sections. The first 4 are categorically speeding you up faster than the previous movementV2 rules.
		---- The 5th section is linear, but at an even slower rate for N more seconds and then we fall back to the same very bad logarithmic rule.
		-- now, all this is moderated by how we now calculate speedups MUCH less smoothly. We literally used to calculate it every 1/60th. But now the lastNotifiedSpeed area
		-- is VERY powerful since it pretty much ignores the "calculated" appropriate speed for the player, and does not apply it, UNTIL a threshold is passed. This seems like it will make
		-- their speed gain rates look more stair-stepped. Right now the trigger goes continuously for the first part of a long same-terrain run, but from then its visibly emitting green particles
		-- not sure if that will be useful at elite level. Definitely it will be noticeable.

		local timeInSection1 = math.max(0, math.min(firstLinearSectionEnd, effectiveTimeOnCurrentTerrain))
		local timeInSection2 = math.max(0, effectiveTimeOnCurrentTerrain - secondLinearSectionEnd)
		local timeInSection3 = math.max(0, effectiveTimeOnCurrentTerrain - thirdLinearSectionEnd)
		local timeInSection4 = math.max(0, effectiveTimeOnCurrentTerrain - fourthLinearSectionEnd)
		local timeInSection5 = math.max(0, effectiveTimeOnCurrentTerrain - fifthLinearSectionEnd)
		local timeInFinalSection = math.max(0, effectiveTimeOnCurrentTerrain - fifthLinearSectionDivider)
		local totalGain = timeInSection1 / firstLinearSectionDivider
			+ timeInSection2 / secondLinearSectionDivider
			+ timeInSection3 / thirdLinearSectionDivider
			+ timeInSection4 / fourthLinearSectionDivider
			+ timeInSection5 / fifthLinearSectionDivider

		-- _annotate("totalGain is: " .. totalGain)
		-- _annotate("totalGain is:")
	else
		------------- speedup goes nonlinear after 11s. This isn't ideal, it'd be better to have it continuously increasing but at a slower and slower rate.
		-- aka the old world, still enabled.-------------
		local firstLinearSectionEnd = 11
		local firstLinearSectionDivider = 120

		if effectiveTimeOnCurrentTerrain < firstLinearSectionEnd then
			speedMultiplierFromSameTerrain += effectiveTimeOnCurrentTerrain / firstLinearSectionDivider
		else
			speedMultiplierFromSameTerrain += firstLinearSectionEnd / firstLinearSectionDivider + (math.log(
				effectiveTimeOnCurrentTerrain
			) - math.log(firstLinearSectionEnd - 7)) / 79
		end
		if specialMovementAnnotate then
			_annotate(string.format("speed multiplier: %0.2f", speedMultiplierFromSameTerrain))
		end
	end

	----------------- jump power ----------------
	--------------- CHANGES FROM BEING ON A RUN FROM A SPECIAL SIGN ----------------------
	if activeRunSignName == "Bolt" then
		fasterSignSpeedMultiplier = 91 / 68
	elseif activeRunSignName == "Prefontaine" then
		fasterSignSpeedMultiplier = 2.4
		runJumpPowerMultiplier = runJumpPowerMultiplier * 1.3
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
		elseif activeRunSignName == "Lavaslug" then
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
	if activeRunSignName == "Hypergravity" or activeRunSignName == "Zoom" or activeRunSignName == "Lavaslug" then
		currentRunJumpPowerMultiplier = 0
	end

	local newJumpPower = movementEnums.constants.globalDefaultJumpPower
		* floorJumpPowerMultiplier
		* lastFloorJumpPowerMultiplier
		* runJumpPowerMultiplier
		* currentRunJumpPowerMultiplier

	if isMovementBlockedByWarp then
		debounceAdjustSpeed = false
		return
	end
	InternalSetJumpPower(newJumpPower)

	--------------------------- NO SPEEDUPS DURING WALKING -----------------------
	if isMovementBlockedByWarp then
		debounceAdjustSpeed = false
		return
	end
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

	-- the theory for these guys is that if a kill has come in, at least don't apply a change to the actual avatar.
	if isMovementBlockedByWarp then
		debounceAdjustSpeed = false
		return
	end

	if activeRunSignName == "Lavaslug" then
		effectiveSpeed = 16
	end

	InternalSetSpeed(effectiveSpeed)
	debounceAdjustSpeed = false
end

local setRunEffectedSign = function(name: string)
	if name then
		_annotate("Set active sign to: " .. name)
	else
		_annotate("Unset active sign.")
	end
	activeRunSignName = name
end

-------------------------------- EVENT FILTERING ------------------------------

-- 2024: we monitor all incoming events and store ones which are relevant to movement per se.
-- basic policy: if they touch a floor, change the movementt rules to that type.
-- also store the event if it's important to us, so we can recalc speed.
local eventsWeCareAbout = {
	aet.avatarEventTypes.CHARACTER_ADDED,
	aet.avatarEventTypes.AVATAR_DIED,
	aet.avatarEventTypes.CHARACTER_REMOVING,

	aet.avatarEventTypes.FLOOR_CHANGED,
	aet.avatarEventTypes.KEYBOARD_RUN,
	aet.avatarEventTypes.KEYBOARD_WALK,
	aet.avatarEventTypes.STATE_CHANGED,
	-- mt.avatarEventTypes.AVATAR_CHANGED_DIRECTION, -- let's ignore this. it really happens a lot.
	aet.avatarEventTypes.AVATAR_STARTED_MOVING,
	aet.avatarEventTypes.AVATAR_STOPPED_MOVING,

	aet.avatarEventTypes.RUN_START,
	aet.avatarEventTypes.RUN_COMPLETE,
	aet.avatarEventTypes.RUN_CANCEL,
	aet.avatarEventTypes.RETOUCH_SIGN,
	-- mt.avatarEventTypes.TOUCH_SIGN,
	-- I *believe* this is right not to include TOUCH_SIGN here.
	-- The process for management of movement during a run is: the user does something to start a run and we correctly
	-- evaluate it.  then if they retouch we just clear history again.
	aet.avatarEventTypes.GET_READY_FOR_WARP,
	aet.avatarEventTypes.WARP_DONE_RESTART_MOVEMENT,
}

local handleAvatarEvent = function(ev: aet.avatarEvent)
	if not avatarEventFiring.EventIsATypeWeCareAbout(ev, eventsWeCareAbout) then
		return
	end
	_annotate(string.format("handling: %s", avatarEventFiring.DescribeEvent(ev)))
	if ev.eventType == aet.avatarEventTypes.GET_READY_FOR_WARP then
		isMovementBlockedByWarp = true
		movementEventHistory = {}
		ApplyNewPhysicsFloor("default", movementEnums.constants.DefaultPhysicalProperties)
		setRunEffectedSign("")
		InternalSetSpeed(movementEnums.constants.globalDefaultRunSpeed)
		InternalSetJumpPower(movementEnums.constants.globalDefaultJumpPower)
		movementEventHistory = {}
		fireEvent(aet.avatarEventTypes.MOVEMENT_WARPER_READY, { sender = "movement" })
		_annotate("done with GET_READY_FOR_WARP")
		return
	elseif ev.eventType == aet.avatarEventTypes.WARP_DONE_RESTART_MOVEMENT then
		movementEventHistory = {}
		ApplyNewPhysicsFloor("default", movementEnums.constants.DefaultPhysicalProperties)
		setRunEffectedSign("")
		InternalSetSpeed(movementEnums.constants.globalDefaultRunSpeed)
		InternalSetJumpPower(movementEnums.constants.globalDefaultJumpPower)
		movementEventHistory = {}
		isMovementBlockedByWarp = false
		fireEvent(aet.avatarEventTypes.MOVEMENT_RESTARTED, { sender = "movement" })
		_annotate("done with WARP_DONE_RESTART_MOVEMENT")
		return
	end

	-- everything above here CAN be done even in a warp-related state. But the events below cannot.
	if isMovementBlockedByWarp then
		_annotate("ignored event due to being locked by warping:" .. aet.avatarEventTypesReverse[ev.eventType])
		return
	end
	table.insert(movementEventHistory, ev)

	if ev.eventType == aet.avatarEventTypes.RUN_START then
		--- in a sense, we almost want to teleport you to the sign and reset your time from that point.
		if activeRunSignName ~= "" then
			_annotate("run started while already on a run. hmm")
		end

		--- nuke past history and start from here. -----------
		if not ev.details or not ev.details.startSignName then
			annotater.Error("race started w/out data.")
		end
		setRunEffectedSign(ev.details.startSignName)
		movementEventHistory = {}
		table.insert(movementEventHistory, ev)

		if ev.details and ev.details.startSignName then
			setRunEffectedSign(ev.details.startSignName)
		else
			_annotate("race started w/out data.")
		end
		if activeRunSignName == "Salekhard" then
			ApplyNewPhysicsFloor("ice", movementEnums.IceProps)
		end

	-- the list of history objects starts with a retouch or a touch always.
	-- why is start race different? well, races may have characteristic avatar forms which we don't want to mess with.
	-- so just leave that there.
	elseif ev.eventType == aet.avatarEventTypes.RETOUCH_SIGN then
		------ nuke history, and add a START event from here. ----------
		if activeRunSignName == "" then
			warn("retouch while not on a run huh")
			_annotate("retouch while not on a run huh")
		end
		movementEventHistory = {}
		--fix this up so at least the run history makes some kind of sense.
		table.insert(movementEventHistory, ev)
		--patch it up with current touching floor, too.
		-- Add a fake event for the current floor
		-- we fill in all the full fake details too.
		local p, l, s = avatarEventFiring.GetPlayerPosition()
		local details: aet.avatarEventDetails = {
			floorMaterial = humanoid.FloorMaterial,
			position = p,
			lookVector = l,
			walkSpeed = s,
			sender = "movement",
		}

		local currentFloorEvent: aet.avatarEvent = {
			eventType = aet.avatarEventTypes.FLOOR_CHANGED,
			timestamp = ev.timestamp + 0.0000001,
			details = details,
			id = ev.id,
		}

		table.insert(movementEventHistory, currentFloorEvent)
		_annotate(string.format("Added fake floor event for current floor: %s", tostring(humanoid.FloorMaterial)))

		-- also I think we should add a fake started moving event here, if they are moving at all. so that if they hit a sign, then stop, then
		-- retouch or touch, they have their initial state.
		-- this only matters if they completely don't move after that either; once they do a real movement this will be irrelevant since
		local mov = humanoid.MoveDirection
		if mov == Vector3.new(0, 0, 0) then
			_annotate("fired fake STOP moving event after retouch.")
			fireEvent(aet.avatarEventTypes.AVATAR_STOPPED_MOVING, { sender = "movement" })
		else
			_annotate("fired fake START moving event after retouch when allegedly they were moving.")
			fireEvent(aet.avatarEventTypes.AVATAR_STARTED_MOVING, { sender = "movement" })
		end
	elseif ev.eventType == aet.avatarEventTypes.RUN_CANCEL or ev.eventType == aet.avatarEventTypes.RUN_COMPLETE then
		if activeRunSignName == "" then
			_annotate("weird, ended run while not on one. hmmm")
			_annotate(ev.details.reason)
		end
		if ev.eventType == aet.avatarEventTypes.RUN_COMPLETE then
			-- this is sufficient to locate the original run, because 1. we know when it actually arrived 2. we know the start and end time.
			-- but in reality we just load the latest of these runs.
			local movementEventCopy = table.clone(movementEventHistory)
			task.spawn(function()
				task.wait(0.3)
				-- we wait, so that it's more likely that the server has got the data already.
				userData.SendRunData(
					"run_complete",
					ev.details.startSignName,
					ev.details.endSignName,
					workspace.Terrain.CustomPhysicalProperties,
					movementEventCopy
				)
				-- TODO definitely don't accept failure here. backoff/send later.
			end)
		end
		--- clear history and remove knowledge that we're on a run from a certain sign.

		movementEventHistory = {}
		local desiredPhysicsDetails = movementEnums.GetPropertiesForFloor(humanoid.FloorMaterial)
		local desiredPhysicsName = desiredPhysicsDetails.name
		ApplyNewPhysicsFloor(desiredPhysicsName, desiredPhysicsDetails.prop)
		setRunEffectedSign("")
	elseif
		ev.eventType == aet.avatarEventTypes.CHARACTER_ADDED
		or ev.eventType == aet.avatarEventTypes.STATE_CHANGED
		or ev.eventType == aet.avatarEventTypes.KEYBOARD_RUN
		or ev.eventType == aet.avatarEventTypes.KEYBOARD_WALK
		or ev.eventType == aet.avatarEventTypes.AVATAR_STARTED_MOVING --just toss it into history
		or ev.eventType == aet.avatarEventTypes.AVATAR_STOPPED_MOVING
	then
		-- do nothing here, just store the event
		-- in some sense, after keyboard stuff we want to clear history.
		-- but that would also clear historical lava touches for example, so we don't.
	elseif ev.eventType == aet.avatarEventTypes.FLOOR_CHANGED then
		ApplyFloorPhysics(ev)
	elseif
		ev.eventType == aet.avatarEventTypes.CHARACTER_REMOVING or ev.eventType == aet.avatarEventTypes.AVATAR_DIED
	then
		setRunEffectedSign("")
		_annotate("character removed or avatar died, so killing movementEventHistory.")
		movementEventHistory = {}
	else
		warn("Unhandled movement event: " .. avatarEventFiring.DescribeEvent(ev))
	end

	-- we actually always want to adjust speed since it makes sense. you should still speedup,
	adjustSpeed()
end

---------------------- START CONTINUOUS ADJUSTMENT ------------

local avatarEventConnection = nil
module.Init = function()
	_annotate("start of movement.init.")
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	isMovementBlockedByWarp = false
	activeCurrentWorldPhysicsName = "default"
	lastTouchedFloor = nil
	movementEventHistory = {}
	activeRunSignName = ""
	debounceAdjustSpeed = false
	speedGui.CreateSpeedGui()
	local lastDataSendTick = tick()
	task.spawn(function()
		while true do
			adjustSpeed()
			task.wait(1 / 60)
			local now = tick()
			-- if activeRunSignName and activeRunSignName ~= "" and now - lastDataSendTick > 3 then
			-- 	userData.SendRunData("run_in_progress", activeRunSignName, "", movementEventHistory)
			-- 	lastDataSendTick = now
			-- end
		end
	end)

	--------------------- LISTEN TO EVENTS ---------------------

	_annotate("adjusted initial speed in movement.")
	InternalSetSpeed(movementEnums.constants.globalDefaultRunSpeed)
	ApplyNewPhysicsFloor("default", movementEnums.constants.DefaultPhysicalProperties)
	local remotes = require(game.ReplicatedStorage.util.remotes)

	local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")

	if avatarEventConnection then
		avatarEventConnection:Disconnect()
		avatarEventConnection = nil
	end
	avatarEventConnection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
	_annotate("End of movement.Init.")
end

_annotate("end")
return module
