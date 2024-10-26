--!strict

-- A 4.29.2022 redo to trust client
-- completely locally track times and then just hit the endpoint with what they are
-- What is this: the guy who does local tracking of the time for a run.

--2024 this should be more just about RUNs not about character setup.
-- and it can relate to other code via just having local bindable events
-- 2024.08 rename.
-- the function of this is to manage sign touches for the purpose of starting and ending races
-- it also relays signals on to marathon clients.

--2024 rewrite - just use the events system.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local remotes = require(game.ReplicatedStorage.util.remotes)

local marathonClient = require(game.StarterPlayer.StarterCharacterScripts.client.marathonClient)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local dynamicRunning = require(game.StarterPlayer.StarterPlayerScripts.dynamicRunning)
local aet = require(game.ReplicatedStorage.avatarEventTypes)
local enums = require(game.ReplicatedStorage.util.enums)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent
local activeRunSGui = require(game.ReplicatedStorage.gui.activeRunSGui)
local terrainTouchMonitor = require(game.ReplicatedStorage.terrainTouchMonitor)
local tt = require(game.ReplicatedStorage.types.gametypes)
local morphs = require(game.StarterPlayer.StarterCharacterScripts.client.morphs)

---------- CHARACTER -------------
local localPlayer: Player = game:GetService("Players").LocalPlayer
-- local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

----------- EVENTS -------------------
local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")

-------------------------------------- GLOBALS --------------------------------------
local isRacingBlockedByWarp = false

----------- RUNSTATE MONITORING ----------------
local currentRunStartTick: number = 0

local currentRunSignId: number = 0
local currentRunSignName: string = ""

-- the start position of the initial sign in a race - used for distance
local lastRunCompleteTime = 0

---------- DEBOUNCERS ------------
-- so we don't repeatedly call this function in overlapping ways. -----------------------
local clientTouchDebounce: { [string]: boolean } = {}

----------- this is for the special runs which have limitations on how many terrains you can see as you run and things like that.----------
---------- we probably should just monitor them ourselves ?--------------

-- stop the process of counting the run.
-- this happens when any kind of illegal avatar things happens mostly like dying or leaving.
-- this modifes local state so further touches won't count as ending the run etc.
-- it also calls the singleton for managing the run UI and tells it to stop.
local function endClientRun(context: string, endTick: number)
	_annotate("endClientRun, reason:" .. context)
	currentRunStartTick = 0
	currentRunSignName = ""
	currentRunSignId = 0
	dynamicRunning.endDynamic()
	activeRunSGui.KillActiveRun()
	clientTouchDebounce[localPlayer.Name] = false
	lastRunCompleteTime = endTick
end

--- no interpretation yet - just that they touched.
local function TouchedSign(signId: number, signName: string, touchTimeTick: number, exactPositionOfHit: Vector3)
	if not signName then
		annotater.Error("signName is nil")
	end
	if not signId then
		annotater.Error("signId is nil")
	end

	if isRacingBlockedByWarp then
		return
	end
	if clientTouchDebounce[localPlayer.Name] then
		_annotate("blocked by sign touch debouner.")
		return
	end

	if isRacingBlockedByWarp then
		_annotate("isRacingBlockedByWarp")
		return
	end

	local sign = tpUtil.signId2Sign(signId)
	if not sign then
		warn("NO sign.")
		return
	end

	------------------LOCK--------
	clientTouchDebounce[localPlayer.Name] = true

	local gapSinceLastRun = touchTimeTick - lastRunCompleteTime

	--- this is no longer necessary since in the event monitor side, we don't send out
	-- repeated touch events of any type within an interval of 0.8s after finishing a race.
	if gapSinceLastRun < 0.1 then
		--debounce so they can try this method again.
		clientTouchDebounce[localPlayer.Name] = false
		warn(
			string.format(
				"this should never happen. If you see it, please report; gap since last run is: %0.2f",
				gapSinceLastRun
			)
		)
		return false
	end

	-----------------NEW RACE or RESTART CURRENT RACE BY TOUCHING SIGN AGAIN-----------------------------

	-- notify marathon ui
	marathonClient.receiveHit(signName, touchTimeTick)

	------- START RUN ------------
	if currentRunSignName == "" then
		_annotate(string.format("started run from %s", signName))
		currentRunSignName = signName
		currentRunSignId = signId
		activeRunSGui.StartActiveRunGui(touchTimeTick, signName, sign.Position)
		local signOverallTextDescription = enums.SpecialSignDescriptions[currentRunSignName]
		if signOverallTextDescription then
			activeRunSGui.UpdateExtraRaceDescription(signOverallTextDescription)
		end

		dynamicRunning.startDynamic(localPlayer, signName, touchTimeTick)
		fireEvent(aet.avatarEventTypes.RUN_START, {
			startSignId = signId,
			startSignName = signName,
			exactPositionOfHit = exactPositionOfHit,
			sender = "racing",
		})
		currentRunStartTick = touchTimeTick
		terrainTouchMonitor.initTracking(signName)
		_annotate(string.format("started run from %s", currentRunSignName))

	--------- RETOUCH----------------------------
	elseif currentRunSignName == signName then
		_annotate(string.format("retouch start. %s", signName))
		local gap = touchTimeTick - currentRunStartTick
		if gap > 0.0 then
			currentRunStartTick = touchTimeTick
			_annotate(string.format("updated start of run by: %0.4f", gap))
			dynamicRunning.resetDynamicTiming(touchTimeTick)
			local details: aet.avatarEventDetails = {
				startSignId = signId,
				startSignName = signName,
				exactPositionOfHit = exactPositionOfHit,
				sender = "racing",
			}
			fireEvent(aet.avatarEventTypes.RETOUCH_SIGN, details)
			activeRunSGui.UpdateStartTime(currentRunStartTick)
		end
		_annotate(string.format("touched sign again: %s", signName))

	--------END RACE-------------
	else
		if not currentRunSignName then
			annotater.Error("currentRunSignName is nil")
		end

		_annotate(string.format("run END init..%s", signName))

		--locally calculated actual racing time.
		local runMilliseconds: number = math.floor(1000 * (touchTimeTick - currentRunStartTick))
		local details: aet.avatarEventDetails = {
			endSignId = signId,
			endSignName = signName,
			startSignId = currentRunSignId,
			startSignName = currentRunSignName,
			exactPositionOfHit = exactPositionOfHit,
			sender = "racing",
		}

		local floorSeen: number = terrainTouchMonitor.GetSeenTerrainTypesCountThisRun()

		--tell the game server it ended so we can relay to store in db server.
		local runEndData: tt.runEndingDataFromClient = {
			startSignName = currentRunSignName,
			endSignName = signName,
			runMilliseconds = runMilliseconds,
			floorSeenCount = floorSeen,
		}
		local event: tt.clientToServerRemoteEventOrFunction = {
			eventKind = "runEnding",
			data = runEndData,
		}

		-- various local scripts will respond - non-exhaustively: particles will show, morphs will reset, movement reset(?) etc.
		local activeDynamicSign = morphs.GetActiveRunSignModule()
		if activeDynamicSign then
			local canEndRunData = activeDynamicSign.CanRunEnd()
			_annotate("canEndRunData:", canEndRunData)
			if canEndRunData.canRunEndNow then
				if canEndRunData.extraTimeS then
					local usingMillisecondsIncludingPenalties = runMilliseconds + canEndRunData.extraTimeS * 1000
					_annotate(
						string.format(
							"end run with extra time added. original %0.1f, after penalties %0.1f",
							runMilliseconds,
							usingMillisecondsIncludingPenalties
						)
					)
					runEndData.runMilliseconds = usingMillisecondsIncludingPenalties
					endClientRun("end run with extra time added.", touchTimeTick)
					GenericClientUIFunction:InvokeServer(event)
				else
					_annotate("dynamic sign, but no penalty.")
					endClientRun("end run with no time added.", touchTimeTick)
					GenericClientUIFunction:InvokeServer(event)
				end

				fireEvent(aet.avatarEventTypes.RUN_COMPLETE, details)
			else
				_annotate(string.format("cannot end run without signs permission. %s", activeDynamicSign.GetName()))
			end
		else
			_annotate("normal end run.")
			fireEvent(aet.avatarEventTypes.RUN_COMPLETE, details)
			endClientRun("normal end run.", touchTimeTick)
			GenericClientUIFunction:InvokeServer(event)
		end
	end
	clientTouchDebounce[localPlayer.Name] = false
end

-------------------------------- EVENT FILTERING ------------------------------

-- 2024: we monitor all incoming events and store ones which are relevant to movement per se.
-- basic policy: if they touch a floor, change the movementt rules to that type.
-- also store the event if it's important to us, so we can recalc speed.
local eventsWeCareAbout: { number } = {
	aet.avatarEventTypes.AVATAR_RESET,
	aet.avatarEventTypes.RUN_CANCEL, ------ other people killing our runs.
	aet.avatarEventTypes.TOUCH_SIGN,
	aet.avatarEventTypes.AVATAR_DIED,
	aet.avatarEventTypes.CHARACTER_REMOVING,
	aet.avatarEventTypes.CHARACTER_ADDED,
	aet.avatarEventTypes.FLOOR_CHANGED,
	aet.avatarEventTypes.GET_READY_FOR_WARP,
	aet.avatarEventTypes.WARP_DONE_RESTART_RACING,
}

local function handleAvatarEvent(ev: aet.avatarEvent)
	if not avatarEventFiring.EventIsATypeWeCareAbout(ev, eventsWeCareAbout) then
		return
	end

	if ev.eventType == aet.avatarEventTypes.GET_READY_FOR_WARP then
		_annotate(string.format("handling: %s", avatarEventFiring.DescribeEvent(ev)))
		isRacingBlockedByWarp = true
		endClientRun("warping.", ev.timestamp)
		fireEvent(aet.avatarEventTypes.RACING_WARPER_READY, { sender = "racing" })
		_annotate("GET_READY_FOR_WARP DONE")
		return
	elseif ev.eventType == aet.avatarEventTypes.WARP_DONE_RESTART_RACING then
		_annotate(string.format("handling: %s", avatarEventFiring.DescribeEvent(ev)))
		-- perhaps at this point there are still floating touch events?
		endClientRun("warping DONE.", ev.timestamp)
		isRacingBlockedByWarp = false
		-- we reset this to zero because in this case, we shouldn't reject the restart of the next run.
		-- i.e. normally without warping
		lastRunCompleteTime = 0
		fireEvent(aet.avatarEventTypes.RACING_RESTARTED, { sender = "racing" })
		_annotate("WARP_DONE_RESTART_RACING DONE")
		return
	end

	if isRacingBlockedByWarp then
		_annotate("racing warping ignored event:" .. aet.avatarEventTypesReverse[ev.eventType])
		return
	end
	if ev.eventType == aet.avatarEventTypes.CHARACTER_ADDED then
		local _ = 4
	elseif
		ev.eventType == aet.avatarEventTypes.AVATAR_DIED
		or ev.eventType == aet.avatarEventTypes.AVATAR_RESET
		or ev.eventType == aet.avatarEventTypes.CHARACTER_REMOVING
		or ev.eventType == aet.avatarEventTypes.RUN_CANCEL
	then
		endClientRun(string.format("player %s so end run.", aet.avatarEventTypesReverse[ev.eventType]), ev.timestamp)
	elseif ev.eventType == aet.avatarEventTypes.FLOOR_CHANGED then
		terrainTouchMonitor.CountNewFloorMaterial(ev.details.floorMaterial)
	elseif ev.eventType == aet.avatarEventTypes.TOUCH_SIGN then
		if ev.details == nil or not ev.details.touchedSignId then
			annotater.Error("x")
		end
		TouchedSign(ev.details.touchedSignId, ev.details.touchedSignName, ev.timestamp, ev.details.exactPositionOfHit)
	else
		_annotate("Unhandled event: " .. avatarEventFiring.DescribeEvent(ev))
	end
end

local avatarEventConnection: RBXScriptConnection | nil = nil

module.Init = function()
	_annotate("init")
	-- character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	-- humanoid = character:WaitForChild("Humanoid") :: Humanoid
	currentRunStartTick = 0
	currentRunSignName = ""
	-- the start position of the initial sign in a race - used for distance
	lastRunCompleteTime = 0

	isRacingBlockedByWarp = false
	clientTouchDebounce = {}

	-- why are these loaded here and not more generally? hmm.
	terrainTouchMonitor.Init()
	dynamicRunning.Init()

	-------------LISTEN TO EVENTS-------------

	if avatarEventConnection then
		avatarEventConnection:Disconnect()
		avatarEventConnection = nil
	end
	avatarEventConnection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)

	_annotate("init done")
end

_annotate("end")
return module
