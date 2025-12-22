--!strict
-- racing.lua (StarterPlayer/StarterCharacterScripts/client/racing.lua)
-- Handles client-side racing state transitions and logging.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")

local aet = require(game.ReplicatedStorage.avatarEventTypes)
local activeRunSGui = require(game.ReplicatedStorage.gui.activeRunSGui)
local config = require(game.ReplicatedStorage.config)
local runStats = require(game.ReplicatedStorage.gui.activeRunWidgets.runStats)
local terrainTouchMonitor = require(game.ReplicatedStorage.terrainTouchMonitor)
local tt = require(game.ReplicatedStorage.types.gametypes)
local enums = require(game.ReplicatedStorage.util.enums)
local remotes = require(game.ReplicatedStorage.util.remotes)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
-- local dynamicRunning = require(game.StarterPlayer.StarterPlayerScripts.dynamicRunning) -- Decoupled
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local marathonClient = require(game.StarterPlayer.StarterCharacterScripts.client.marathonClient)
local morphs = require(game.StarterPlayer.StarterCharacterScripts.client.morphs)
local fireEvent = avatarEventFiring.FireEvent

type Module = {
	Init: () -> (),
	Reset: (context: string?) -> (),
}

local module = {} :: Module

local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")

-- Module internals
local localPlayer: Player = Players.LocalPlayer
-- local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")
local isRacingBlockedByWarp = false
local isDead = false
_annotate("module load: isDead seeded to false (initial state)")
local currentRunStartTick: number = 0
local currentRunSignId: number = 0
local currentRunSignName: string = ""
local lastRunCompleteTime = 0
local clientTouchDebounce: { [string]: boolean } = {}

-- Notify server of run start for timing security (controlled via config.ENABLE_SERVER_TIMING)
local function notifyServerOfRunStart(signId: number, signName: string)
	if not config.ENABLE_SERVER_TIMING then
		return
	end

	local clientTick = tick()
	local runStartData: tt.runStartDataFromClient = {
		startSignName = signName,
		startSignId = signId,
		networkPingMs = math.floor(localPlayer:GetNetworkPing() * 1000),
		clientTick = clientTick,
	}
	local event: tt.clientToServerRemoteEventOrFunction = {
		eventKind = "runStartNotification",
		data = runStartData,
	}
	task.spawn(function()
		GenericClientUIFunction:InvokeServer(event)
	end)
	_annotate(string.format("notified server of run start: %s (ping=%dms)", signName, runStartData.networkPingMs))
end

local function formatMaybeTime(value: number): string
	if value == 0 then
		return "-"
	end
	return string.format("%0.3f", value)
end

local function formatSignDescriptor(signId: number?, signName: string?): string
	local readableName = (signName and signName ~= "") and signName or "unknown"
	if signId and signId > 0 then
		return string.format("%s#%d", readableName, signId)
	end
	return readableName
end

local function describeRunState(): string
	local signDescriptor = if currentRunSignName == "" then "none" else formatSignDescriptor(currentRunSignId, currentRunSignName)
	local debounceActive = clientTouchDebounce[localPlayer.Name] == true
	return string.format("state { runSign=%s startTick=%s lastComplete=%s isDead=%s blockedByWarp=%s debounce=%s }", signDescriptor, formatMaybeTime(currentRunStartTick), formatMaybeTime(lastRunCompleteTime), tostring(isDead), tostring(isRacingBlockedByWarp), tostring(debounceActive))
end

local function logRunState(context: string)
	_annotate(string.format("%s %s", context, describeRunState()))
end

local function logTouchDecision(signId: number?, signName: string?, decision: string)
	local descriptor = formatSignDescriptor(signId, signName)
	logRunState(string.format("touch[%s] %s", descriptor, decision))
end

local function describeScalar(value: any): string
	if value == nil then
		return "nil"
	end
	local valueType = typeof(value)
	if valueType == "number" then
		return string.format("%0.6f", value)
	elseif valueType == "boolean" then
		return tostring(value)
	elseif valueType == "string" then
		if value == "" then
			return '""'
		end
		return value
	end
	return tostring(value)
end

local function contextIsTimingSensitive(context: string): boolean
	local loweredContext = string.lower(context)
	return string.find(loweredContext, "touch", 1, true) ~= nil or string.find(loweredContext, "retouch", 1, true) ~= nil
end

local function logRedundantStateRequest(fieldName: string, attemptedValue: any, context: string)
	local suffix = if contextIsTimingSensitive(context) then " -- timing-sensitive path" else ""
	_annotate(string.format("redundant state request: %s already %s (%s)%s", fieldName, describeScalar(attemptedValue), context, suffix), nil, false)
end

local function setIsDead(nextValue: boolean, context: string)
	if isDead == nextValue then
		logRedundantStateRequest("isDead", nextValue, context)
		return
	end
	isDead = nextValue
	logRunState(string.format("isDead -> %s (%s)", tostring(nextValue), context))
end

local function setTouchDebounce(nextValue: boolean, context: string)
	local previousValue = clientTouchDebounce[localPlayer.Name]
	if previousValue == nextValue then
		logRedundantStateRequest("touchDebounce", nextValue, context)
		return
	end
	clientTouchDebounce[localPlayer.Name] = nextValue
	logRunState(string.format("touchDebounce -> %s (%s)", tostring(nextValue), context))
end

local function setIsRacingBlockedByWarp(nextValue: boolean, context: string)
	if isRacingBlockedByWarp == nextValue then
		logRedundantStateRequest("isRacingBlockedByWarp", nextValue, context)
		return
	end
	isRacingBlockedByWarp = nextValue
	logRunState(string.format("isRacingBlockedByWarp -> %s (%s)", tostring(nextValue), context))
end

local function setCurrentRunSign(signId: number, signName: string, context: string): boolean
	if currentRunSignId == signId and currentRunSignName == signName then
		logRedundantStateRequest("currentRunSign", formatSignDescriptor(signId, signName), context)
		return false
	end
	currentRunSignId = signId
	currentRunSignName = signName
	return true
end

local function setCurrentRunStartTick(nextValue: number, context: string): boolean
	if currentRunStartTick == nextValue then
		logRedundantStateRequest("currentRunStartTick", nextValue, context)
		return false
	end
	currentRunStartTick = nextValue
	return true
end

local function setLastRunCompleteTime(nextValue: number, context: string): boolean
	if lastRunCompleteTime == nextValue then
		logRedundantStateRequest("lastRunCompleteTime", nextValue, context)
		return false
	end
	lastRunCompleteTime = nextValue
	return true
end

----------- this is for the special runs which have limitations on how many terrains you can see
--  as you run and things like that.----------
---------- we probably should just monitor them ourselves ?--------------

-- stop the process of counting the run.
-- this happens when any kind of illegal avatar things happens mostly like dying or leaving.
-- this modifes local state so further touches won't count as ending the run etc.
-- it also calls the singleton for managing the run UI and tells it to stop.
local function endClientRun(context: string, endTick: number, didCompleteRun: boolean)
	setCurrentRunStartTick(0, string.format("%s (endClientRun startTick reset)", context))
	setCurrentRunSign(0, "", string.format("%s (endClientRun runSign reset)", context))
	-- dynamicRunning.endDynamic()
	activeRunSGui.KillActiveRun()
	setTouchDebounce(false, "endClientRun")
	if didCompleteRun then
		setLastRunCompleteTime(endTick, string.format("%s (endClientRun completed)", context))
	end
	logRunState(string.format("endClientRun complete (%s, completed=%s)", context, tostring(didCompleteRun)))
end

--- no interpretation yet - just that they touched.
local function TouchedSign(signId: number, signName: string, touchTimeTick: number, exactPositionOfHit: Vector3)
	if not signName then
		annotater.Error("signName is nil")
	end
	if not signId then
		annotater.Error("signId is nil")
	end

	local function explain(reason: string)
		logTouchDecision(signId, signName, reason)
	end

	if isRacingBlockedByWarp then
		explain("rejected because racing is warp-blocked before validation")
		return
	end
	if isDead then
		explain("rejected because player flagged dead")
		return
	end
	if clientTouchDebounce[localPlayer.Name] then
		explain("rejected because touch debounce is active")
		return
	end

	if isRacingBlockedByWarp then
		explain("rejected because racing toggled warp block mid-processing")
		return
	end

	local sign = tpUtil.signId2Sign(signId)
	if not sign then
		warn("NO sign.")
		explain("rejected because sign lookup failed")
		return
	end

	------------------LOCK--------
	setTouchDebounce(true, "TouchedSign start:" .. signName)

	local gapSinceLastRun = touchTimeTick - lastRunCompleteTime

	--- this is no longer necessary since in the event monitor side, we don't send out
	-- repeated touch events of any type within an interval of 0.8s after finishing a race.
	if gapSinceLastRun < 0.1 then
		--debounce so they can try this method again.
		setTouchDebounce(false, "gapSinceLastRun too small")
		explain(string.format("rejected because gapSinceLastRun=%.3f < 0.10", gapSinceLastRun))
		warn(string.format("this should never happen. If you see it, please report; gap since last run is: %0.2f", gapSinceLastRun))
		return false
	end

	-----------------NEW RACE or RESTART CURRENT RACE BY TOUCHING SIGN AGAIN-----------------------------

	-- notify marathon ui
	marathonClient.receiveHit(signName, touchTimeTick)

	------- START RUN ------------
	if currentRunSignName == "" then
		setCurrentRunSign(signId, signName, string.format("TouchedSign start:%s assign runSign", signName))
		activeRunSGui.StartActiveRunGui(touchTimeTick, signName, sign.Position)
		local signOverallTextDescription = enums.SpecialSignDescriptions[currentRunSignName]
		if signOverallTextDescription then
			activeRunSGui.UpdateExtraRaceDescription(signOverallTextDescription)
		end

		-- dynamicRunning.startDynamic(localPlayer, signName, touchTimeTick)
		fireEvent(aet.avatarEventTypes.RUN_START, {
			startSignId = signId,
			startSignName = signName,
			exactPositionOfHit = exactPositionOfHit,
			sender = "racing",
		})
		setCurrentRunStartTick(touchTimeTick, string.format("TouchedSign start:%s startTick", signName))
		terrainTouchMonitor.initTracking(signName)
		notifyServerOfRunStart(signId, signName)
		logTouchDecision(signId, signName, "starting new run")

	--------- RETOUCH----------------------------
	elseif currentRunSignName == signName then
		local gap = touchTimeTick - currentRunStartTick
		if gap > 0.0 then
			setCurrentRunStartTick(touchTimeTick, string.format("retouch:%s startTick", signName))
			_annotate(string.format("retouch adjusted run start by %0.4f seconds", gap))
			-- dynamicRunning.resetDynamicTiming(touchTimeTick)

			-- Restart widgets with fresh state (clears charts, maps, stats, description)
			activeRunSGui.RestartRun(currentRunStartTick, signName, sign.Position)

			-- Re-set static description (RestartRun cleared it)
			local signOverallTextDescription = enums.SpecialSignDescriptions[currentRunSignName]
			if signOverallTextDescription then
				activeRunSGui.UpdateExtraRaceDescription(signOverallTextDescription)
			end

			-- Fire retouch event AFTER RestartRun so special signs can set dynamic descriptions
			local details: aet.avatarEventDetails = {
				startSignId = signId,
				startSignName = signName,
				exactPositionOfHit = exactPositionOfHit,
				sender = "racing",
			}
			fireEvent(aet.avatarEventTypes.RETOUCH_SIGN, details)

			notifyServerOfRunStart(signId, signName)
			terrainTouchMonitor.initTracking(signName)
		end
		logTouchDecision(signId, signName, "retouch same sign; updated timing")

	--------END RACE-------------
	else
		if not currentRunSignName then
			annotater.Error("currentRunSignName is nil")
		end

		logTouchDecision(signId, signName, "ending run at new sign")

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

		-- Get jump count from run stats (should always exist during active run)
		local currentStatsValue = runStats.GetCurrentStats()
		if not currentStatsValue then
			annotater.Error("runStats.GetCurrentStats() returned nil during run end - stats should exist")
		end
		local jumpCount: number = if currentStatsValue then currentStatsValue.jumpCount else 0

		--tell the game server it ended so we can relay to store in db server.
		local runEndData: tt.runEndingDataFromClient = {
			startSignName = currentRunSignName,
			endSignName = signName,
			runMilliseconds = runMilliseconds,
			floorSeenCount = floorSeen,
			networkPingMs = math.floor(localPlayer:GetNetworkPing() * 1000),
			jumpCount = jumpCount,
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
					_annotate(string.format("end run with extra time added. original %0.1f, after penalties %0.1f", runMilliseconds, usingMillisecondsIncludingPenalties))
					runEndData.runMilliseconds = usingMillisecondsIncludingPenalties
					endClientRun("end run with extra time added.", touchTimeTick, true)
					GenericClientUIFunction:InvokeServer(event)
				else
					_annotate("dynamic sign, but no penalty.")
					endClientRun("end run with no time added.", touchTimeTick, true)
					GenericClientUIFunction:InvokeServer(event)
				end

				fireEvent(aet.avatarEventTypes.RUN_COMPLETE, details)
			else
				_annotate(string.format("cannot end run without signs permission. %s", activeDynamicSign.GetName()))
			end
		else
			_annotate("normal end run.")
			fireEvent(aet.avatarEventTypes.RUN_COMPLETE, details)
			endClientRun("normal end run.", touchTimeTick, true)
			GenericClientUIFunction:InvokeServer(event)
		end
	end
	setTouchDebounce(false, "TouchedSign finished")
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
	local eventDescription = avatarEventFiring.DescribeEvent(ev)
	if not avatarEventFiring.EventIsATypeWeCareAbout(ev, eventsWeCareAbout) then
		-- _annotate(string.format("ignoring event: %s", eventDescription))
		return
	end

	if ev.eventType == aet.avatarEventTypes.GET_READY_FOR_WARP then
		_annotate(string.format("handling: %s", eventDescription))
		setIsRacingBlockedByWarp(true, "GET_READY_FOR_WARP")
		endClientRun("warping.", ev.timestamp, false)
		fireEvent(aet.avatarEventTypes.RACING_WARPER_READY, { sender = "racing" })
		return
	elseif ev.eventType == aet.avatarEventTypes.WARP_DONE_RESTART_RACING then
		_annotate(string.format("handling: %s", eventDescription))
		-- perhaps at this point there are still floating touch events?
		endClientRun("warping DONE.", ev.timestamp, false)
		setIsRacingBlockedByWarp(false, "WARP_DONE_RESTART_RACING")
		-- we reset this to zero because in this case, we shouldn't reject the restart of the next run.
		-- i.e. normally without warping
		setLastRunCompleteTime(0, "WARP_DONE_RESTART_RACING zero lastComplete")
		logRunState("WARP_DONE_RESTART_RACING reset timing state")
		fireEvent(aet.avatarEventTypes.RACING_RESTARTED, { sender = "racing" })
		return
	end

	if isRacingBlockedByWarp then
		_annotate("racing warping ignored event:" .. aet.avatarEventTypesReverse[ev.eventType])
		return
	end
	if ev.eventType == aet.avatarEventTypes.CHARACTER_ADDED then
		_annotate("CHARACTER_ADDED: resetting racing state after respawn.")
		if currentRunSignName ~= "" then
			endClientRun("CHARACTER_ADDED cleanup", ev.timestamp, false)
		end
		module.Reset("CHARACTER_ADDED event")
		return
	elseif ev.eventType == aet.avatarEventTypes.AVATAR_DIED then
		setIsDead(true, "AVATAR_DIED event")
		_annotate("AVATAR_DIED: ending client run immediately.")
		endClientRun(string.format("player %s so end run.", aet.avatarEventTypesReverse[ev.eventType]), ev.timestamp, false)
	elseif ev.eventType == aet.avatarEventTypes.AVATAR_RESET or ev.eventType == aet.avatarEventTypes.CHARACTER_REMOVING or ev.eventType == aet.avatarEventTypes.RUN_CANCEL then
		if ev.eventType ~= aet.avatarEventTypes.RUN_CANCEL then
			setIsDead(true, aet.avatarEventTypesReverse[ev.eventType])
		end
		_annotate(string.format("%s: ending client run immediately.", aet.avatarEventTypesReverse[ev.eventType]))
		endClientRun(string.format("player %s so end run.", aet.avatarEventTypesReverse[ev.eventType]), ev.timestamp, false)
	elseif ev.eventType == aet.avatarEventTypes.FLOOR_CHANGED then
		terrainTouchMonitor.CountNewFloorMaterial(ev.details.floorMaterial)
		-- Update runStats for widget terrain display
		local material = ev.details.floorMaterial
		if material then
			runStats.UpdateTerrain(material.Name:lower())
		end
	elseif ev.eventType == aet.avatarEventTypes.TOUCH_SIGN then
		if ev.details == nil or not ev.details.touchedSignId then
			annotater.Error("x")
			return
		end
		local signIdValue: number? = ev.details.touchedSignId
		local signNameValue: string? = ev.details.touchedSignName
		local exactPosValue: Vector3? = ev.details.exactPositionOfHit
		if not signIdValue then
			annotater.Error("touchedSignId is nil")
			return
		end
		local signId: number = signIdValue
		local signName: string = if signNameValue then signNameValue else ""
		local exactPos: Vector3 = if exactPosValue then exactPosValue else Vector3.zero
		TouchedSign(signId, signName, ev.timestamp, exactPos)
	else
		_annotate("Unhandled event: " .. eventDescription)
	end
end

module.Reset = function(context: string?)
	local resetContext = context or "module.Reset"
	_annotate(string.format("Reset (%s)", resetContext))
	setCurrentRunStartTick(0, string.format("%s (Reset startTick)", resetContext))
	setCurrentRunSign(0, "", string.format("%s (Reset runSign)", resetContext))
	setLastRunCompleteTime(0, string.format("%s (Reset lastComplete)", resetContext))
	setIsRacingBlockedByWarp(false, resetContext)
	clientTouchDebounce = {}
	setIsDead(false, resetContext)
	logRunState(string.format("Reset (%s) cleared debounce and run data", resetContext))
end

local avatarEventConnection: RBXScriptConnection | nil = nil
local characterAddedConnection: RBXScriptConnection | nil = nil

local function ensureCharacterLifecycleHooks()
	if characterAddedConnection then
		return
	end
	characterAddedConnection = localPlayer.CharacterAdded:Connect(function()
		logRunState("Player.CharacterAdded received; resetting state immediately")
		module.Reset("Player.CharacterAdded")
	end)
end

module.Init = function()
	_annotate("RACING init")

	-- why are these loaded here and not more generally? hmm.
	terrainTouchMonitor.Init()
	-- dynamicRunning.Init() -- Now initializes itself via main.client.lua -> require or implicitly if in SPS

	-------------LISTEN TO EVENTS-------------

	if avatarEventConnection then
		_annotate("disconnecting existing avatarEventConnection")
		avatarEventConnection:Disconnect()
		avatarEventConnection = nil
	else
		_annotate("no existing avatarEventConnection")
	end

	avatarEventConnection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
	_annotate(string.format("binding to %s", AvatarEventBindableEvent:GetFullName()))

	ensureCharacterLifecycleHooks()

	module.Reset("module.Init")

	_annotate("init done")
end

_annotate("end")
return module
