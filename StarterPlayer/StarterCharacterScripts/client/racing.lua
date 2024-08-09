--!strict

-- 4.29.2022 redo to trust client
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
local mt = require(game.ReplicatedStorage.avatarEventTypes)
local enums = require(game.ReplicatedStorage.util.enums)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent
local runProgressSgui = require(game.ReplicatedStorage.gui.runProgressSgui)
local terrainTouchMonitor = require(game.ReplicatedStorage.terrainTouchMonitor)

---------- CHARACTER -------------
local localPlayer: Player = game.Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- EVENTS -------------------
local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
local TellServerRunEndedRemoteEvent = remotes.getRemoteEvent("TellServerRunEndedRemoteEvent")

-------------------------------------- GLOBALS --------------------------------------
local isRacingBlockedByWarp = false

----------- RUNSTATE MONITORING ----------------
local currentRunStartTick: number = 0
local currentRunSignName: string = ""
-- the start position of the initial sign in a race - used for distance
local lastRunCompleteTime = 0

---------- DEBOUNCERS ------------
-- so we don't repeatedly call this function in overlapping ways. -----------------------
local clientTouchDebounce: { [string]: boolean } = {}

---------------- LEGALITY STATE MONITORING ---------------------------
local isAvatarLegalToTouchSigns = true

----------- this is for the special runs which have limitations on how many terrains you can see as you run and things like that.----------
---------- we probably should just monitor them ourselves ?--------------

-- stop the process of counting the run. this happens when any kind of illegal avatar things happens mostly like dying or leaving.
local function killClientRun(context: string)
	_annotate("killClientRun." .. context)
	currentRunStartTick = 0
	currentRunSignName = ""
	dynamicRunning.endDynamic()
	runProgressSgui.Kill()
	clientTouchDebounce[localPlayer.Name] = false
end

--- no interpretation yet - just that they touched.
local function TouchedSign(signId: number, touchTimeTick: number)
	if clientTouchDebounce[localPlayer.Name] then
		_annotate("blocked by sign touch debouner.")
		return
	end
	if isRacingBlockedByWarp then
		_annotate("isRacingBlockedByWarp inside touchsign.")
		clientTouchDebounce[localPlayer.Name] = false
		return
	end
	clientTouchDebounce[localPlayer.Name] = true

	local gapSinceLastRun = touchTimeTick - lastRunCompleteTime

	--- this is no longer necessary since in the event monitor side, we don't send out
	-- repeated touch events of any type within an interval of 0.8s after finishing a race.
	if gapSinceLastRun < 0.1 then
		--debounce so they can try this method again.
		clientTouchDebounce[localPlayer.Name] = false
		return false
	end
	--hit is valid.
	local signName: string = tpUtil.signId2signName(signId)
	local sign: Part? = tpUtil.signId2Sign(signId)
	if sign == nil then
		warn("no sign.")
	end
	if not isAvatarLegalToTouchSigns then
		_annotate("ignoring touch while not free to touch signs.")
		clientTouchDebounce[localPlayer.Name] = false
		return
	end

	-- notify marathon ui
	marathonClient.receiveHit(signName, touchTimeTick)

	-------- okay so depending what's happening, different things may occur here. ----------------

	-----------------NEW RACE or RESTART CURRENT RACE BY TOUCHING SIGN AGAIN-----------------------------
	--NOTE we do not FIND signs from the client.-------
	if isRacingBlockedByWarp then
		_annotate("isRacingBlockedByWarp")
		clientTouchDebounce[localPlayer.Name] = false
		return
	end

	if currentRunSignName == "" then
		------- START RUN ------------
		_annotate(string.format("started run START" .. signName))
		currentRunSignName = signName
		runProgressSgui.CreateRunProgressSgui(playerGui, touchTimeTick, signName, sign.Position)
		local signOverallTextDescription = enums.SpecialSignDescriptions[currentRunSignName]
		if signOverallTextDescription then
			runProgressSgui.UpdateExtraRaceDescription(signOverallTextDescription)
		end

		dynamicRunning.startDynamic(localPlayer, signName, touchTimeTick)
		fireEvent(mt.avatarEventTypes.RUN_START, { relatedSignId = signId, relatedSignName = signName })
		currentRunStartTick = touchTimeTick
		terrainTouchMonitor.initTracking(signName)
		_annotate(string.format("started run from" .. currentRunSignName))
	elseif currentRunSignName == signName then
		--------- RETOUCH----------------------------
		_annotate(string.format("retouch start." .. signName))
		local gap = touchTimeTick - currentRunStartTick
		if gap > 0.0 then
			currentRunStartTick = touchTimeTick
			_annotate(string.format("updated start of run by: %0.4f", gap))
			dynamicRunning.resetDynamicTiming(touchTimeTick)
			fireEvent(mt.avatarEventTypes.RETOUCH_SIGN, { relatedSignId = signId, relatedSignName = signName })
			runProgressSgui.UpdateStartTime(currentRunStartTick)
		end
		_annotate(string.format("touched sign again: %s", signName))
	else
		--------END RACE-------------
		_annotate(string.format("run END init.." .. signName))
		--locally calculated actual racing time.
		local runMilliseconds: number = math.floor(1000 * (touchTimeTick - currentRunStartTick))
		local details: mt.avatarEventDetails = {
			relatedSignId = tpUtil.signName2SignId(signName),
			relatedSignName = signName,
		}
		fireEvent(mt.avatarEventTypes.RUN_COMPLETE, details)
		local floorSeen: number = terrainTouchMonitor.GetSeenTerrainTypesThisRun()
		if not currentRunSignName then
			error("currentRunSignName is nil")
		end
		if not signName then
			error("signName is nil")
		end
		_annotate(string.format("end run from %s to %s in %dms", currentRunSignName, signName, runMilliseconds))
		TellServerRunEndedRemoteEvent:FireServer(currentRunSignName, signName, runMilliseconds, floorSeen)
		killClientRun("normal end run.")
		lastRunCompleteTime = tick()
	end
	clientTouchDebounce[localPlayer.Name] = false
end

-------------------------------- EVENT FILTERING ------------------------------

-- 2024: we monitor all incoming events and store ones which are relevant to movement per se.
-- basic policy: if they touch a floor, change the movementt rules to that type.
-- also store the event if it's important to us, so we can recalc speed.
local eventsWeCareAbout: { number } = {

	mt.avatarEventTypes.AVATAR_RESET,
	-- mt.avatarEventTypes.RUN_COMPLETE, ---we send this to other people so we don't care about it.
	mt.avatarEventTypes.RUN_KILL, ------ other people killing our runs.
	-- mt.avatarEventTypes.RETOUCH_SIGN,
	mt.avatarEventTypes.TOUCH_SIGN,
	mt.avatarEventTypes.AVATAR_DIED,
	mt.avatarEventTypes.CHARACTER_REMOVING,
	mt.avatarEventTypes.CHARACTER_ADDED,
	mt.avatarEventTypes.FLOOR_CHANGED,
	mt.avatarEventTypes.GET_READY_FOR_WARP,
	mt.avatarEventTypes.WARP_DONE_RESTART_RACING,
}

local eventIsATypeWeCareAbout = function(ev: mt.avatarEvent): boolean
	for _, value in pairs(eventsWeCareAbout) do
		if value == ev.eventType then
			return true
		end
	end
	return false
end

local function adjustPlayerFreedomToDoRuns(val: boolean, reason: string)
	isAvatarLegalToTouchSigns = val
	_annotate("Set clientIsFreeToTouchSigns to " .. tostring(val) .. " because " .. reason)
end

local function handleAvatarEvent(ev: mt.avatarEvent)
	if not eventIsATypeWeCareAbout(ev) then
		return
	end
	_annotate(string.format("handleAvatarEvent: %s", avatarEventFiring.DescribeEvent(ev.eventType, ev.details)))
	if ev.eventType == mt.avatarEventTypes.GET_READY_FOR_WARP then
		_annotate("GET_READY_FOR_WARP")
		isRacingBlockedByWarp = true
		killClientRun("warping.")
		fireEvent(mt.avatarEventTypes.RACING_WARPER_READY, {})
		_annotate("GET_READY_FOR_WARP DONE")
		return
	elseif ev.eventType == mt.avatarEventTypes.WARP_DONE_RESTART_RACING then
		_annotate("WARP_DONE_RESTART_RACING")
		-- perhaps at this point there are still floating touch events?
		killClientRun("warping DONE.")
		isRacingBlockedByWarp = false
		fireEvent(mt.avatarEventTypes.RACING_RESTARTED, {})
		_annotate("WARP_DONE_RESTART_RACING DONE")
		return
	end

	if isRacingBlockedByWarp then
		_annotate("racing warping ignored event:" .. mt.avatarEventTypesReverse[ev.eventType])
		return
	end
	if ev.eventType == mt.avatarEventTypes.CHARACTER_ADDED then
		--ideally we'd have some sync of everyone being done loading, then this would send.
		adjustPlayerFreedomToDoRuns(true, "character added")
	elseif
		ev.eventType == mt.avatarEventTypes.AVATAR_DIED
		or ev.eventType == mt.avatarEventTypes.AVATAR_RESET
		or ev.eventType == mt.avatarEventTypes.CHARACTER_REMOVING
		or ev.eventType == mt.avatarEventTypes.RUN_KILL
	then
		killClientRun(string.format("player %s so end run.", mt.avatarEventTypesReverse[ev.eventType]))
		adjustPlayerFreedomToDoRuns(true, mt.avatarEventTypesReverse[ev.eventType])
	elseif ev.eventType == mt.avatarEventTypes.FLOOR_CHANGED then
		terrainTouchMonitor.CountNewFloorMaterial(ev.details.floorMaterial)
	elseif ev.eventType == mt.avatarEventTypes.TOUCH_SIGN then
		if ev.details == nil or not ev.details.relatedSignId then
			error("x")
		end
		TouchedSign(ev.details.relatedSignId, ev.timestamp)
	else
		_annotate("Unhandled event: " .. avatarEventFiring.DescribeEvent(ev.eventType, ev.details))
	end
end

module.Init = function()
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	currentRunStartTick = 0
	currentRunSignName = ""
	-- the start position of the initial sign in a race - used for distance
	lastRunCompleteTime = 0

	isRacingBlockedByWarp = false
	clientTouchDebounce = {}
	isAvatarLegalToTouchSigns = true
	terrainTouchMonitor.Init()
	dynamicRunning.Init()
end

-------------LISTEN TO EVENTS-------------
AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)

_annotate("end")
return module
