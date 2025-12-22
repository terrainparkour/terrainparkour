--!strict

-- new structure:
-- when the user sends a warp request, we tell everyone about it.
-- they all send back any required blocks and just stay in that broken state (race stopped, character reset momentum, etc.) til freed.
-- we wait for all those messages to get back to us. once that's done we do the warp.
-- then we send the other guys that warping is okay.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)
local tt = require(game.ReplicatedStorage.types.gametypes)

local aet = require(game.ReplicatedStorage.avatarEventTypes)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)

---------- CHARACTER -------------
local localPlayer: Player = game:GetService("Players").LocalPlayer
-- local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

local ClientRequestsWarpToRequestFunction = remotes.getRemoteFunction("ClientRequestsWarpToRequestFunction")
local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
local ServerRequestClientToWarpLockEvent: RemoteEvent = remotes.getRemoteEvent("ServerRequestClientToWarpLockEvent")

local module = {}

------------------ GLOBAL STATE VARS------------------
local doingAWarp = false
local movementIsReady = false
local racingIsReady = false
local morphingIsReady = false
local marathonIsReady = false
local globalAllowWarpBySetting = true

-- when we get a warp request we set these to remember where to go.
local currentWarpRequest: tt.serverWarpRequest | nil = nil

--------------- DEBOUNCERS ---------------
local debounceHandleAvatarEvent = false

-------------- FUNCTIONS ------------------

local function describeWarpRequest(request: tt.serverWarpRequest?): string
	if request == nil then
		return "request is nil."
	end

	local sourceName: string = ""
	if request.kind == "sign" and request.signId then
		sourceName = tpUtil.signId2signName(request.signId)
	elseif request.kind == "player" and request.targetUserId then
		sourceName = string.format("player:%d", request.targetUserId)
	end

	local destName: string = ""
	if request.highlightSignId then
		destName = tpUtil.signId2signName(request.highlightSignId)
	end

	local usePos: string = ""
	if request.position then
		usePos = string.format("(%s, %s, %s)", tostring(request.position.X), tostring(request.position.Y), tostring(request.position.Z))
	end

	local destText = ""
	if destName ~= "" then
		destText = string.format(" destName=%s", destName)
	end
	local positionText = ""
	if usePos ~= "" then
		positionText = string.format(" position=%s", usePos)
	end

	local res: string = string.format(" kind: %s. sourceName=%s%s%s", request.kind, sourceName, destText, positionText)
	return res
end

local function describeWarpState(): string
	local requestDesc = describeWarpRequest(currentWarpRequest)
	return string.format(
		"state { doingAWarp=%s movementReady=%s racingReady=%s morphingReady=%s marathonReady=%s request=%s }",
		tostring(doingAWarp),
		tostring(movementIsReady),
		tostring(racingIsReady),
		tostring(morphingIsReady),
		tostring(marathonIsReady),
		requestDesc
	)
end

local function logWarpState(context: string)
	_annotate(string.format("%s %s", context, describeWarpState()))
end

local function logRedundantStateRequest(fieldName: string, attemptedValue: any, context: string)
	_annotate(string.format("redundant state request: %s already %s (%s)", fieldName, tostring(attemptedValue), context), nil, false)
end

local function setDoingAWarp(nextValue: boolean, context: string)
	if doingAWarp == nextValue then
		logRedundantStateRequest("doingAWarp", nextValue, context)
		return
	end
	doingAWarp = nextValue
	logWarpState(string.format("doingAWarp -> %s (%s)", tostring(nextValue), context))
end

local function setMovementIsReady(nextValue: boolean, context: string)
	if movementIsReady == nextValue then
		logRedundantStateRequest("movementIsReady", nextValue, context)
		return
	end
	movementIsReady = nextValue
	logWarpState(string.format("movementIsReady -> %s (%s)", tostring(nextValue), context))
end

local function setRacingIsReady(nextValue: boolean, context: string)
	if racingIsReady == nextValue then
		logRedundantStateRequest("racingIsReady", nextValue, context)
		return
	end
	racingIsReady = nextValue
	logWarpState(string.format("racingIsReady -> %s (%s)", tostring(nextValue), context))
end

local function setMorphingIsReady(nextValue: boolean, context: string)
	if morphingIsReady == nextValue then
		logRedundantStateRequest("morphingIsReady", nextValue, context)
		return
	end
	morphingIsReady = nextValue
	logWarpState(string.format("morphingIsReady -> %s (%s)", tostring(nextValue), context))
end

local function setMarathonIsReady(nextValue: boolean, context: string)
	if marathonIsReady == nextValue then
		logRedundantStateRequest("marathonIsReady", nextValue, context)
		return
	end
	marathonIsReady = nextValue
	logWarpState(string.format("marathonIsReady -> %s (%s)", tostring(nextValue), context))
end

local function setCurrentWarpRequest(nextValue: tt.serverWarpRequest?, context: string)
	if currentWarpRequest == nextValue then
		logRedundantStateRequest("currentWarpRequest", describeWarpRequest(nextValue), context)
		return
	end
	currentWarpRequest = nextValue
	logWarpState(string.format("currentWarpRequest -> %s (%s)", describeWarpRequest(nextValue), context))
end

local function TeardownWarpSetup()
	_annotate("teardown warp setup")
	setMovementIsReady(false, "TeardownWarpSetup")
	setRacingIsReady(false, "TeardownWarpSetup")
	setMorphingIsReady(false, "TeardownWarpSetup")
	setMarathonIsReady(false, "TeardownWarpSetup")
	setDoingAWarp(false, "TeardownWarpSetup")
	setCurrentWarpRequest(nil, "TeardownWarpSetup")
	_annotate("teardown warp setup done")
end

-- the client has locked down all local scripts which need to get into a certain state before the server
-- can warp the player. That is, races are cancelled, etc.
-- then we do the warp.

module.WarpToSignId = function(warpToSignId: number, highlightSignId: number?)
	if not globalAllowWarpBySetting then
		_annotate("not allowing warp by setting: WarpToSignId")
		return
	end
	_annotate("warp to sign" .. tostring(warpToSignId) .. " highlight " .. tostring(highlightSignId))
	if doingAWarp then
		local desc = describeWarpRequest(currentWarpRequest)
		_annotate(string.format("already doing a warp, it is: %s", desc))
		return
	end
	if currentWarpRequest ~= nil then
		_annotate("WarpToSignId: set new warp request when one was already set.")
		return
	end
	local newRequest: tt.serverWarpRequest = { kind = "sign", signId = warpToSignId, highlightSignId = highlightSignId }
	setDoingAWarp(true, "WarpToSignId")
	setCurrentWarpRequest(newRequest, "WarpToSignId")
	_annotate("WarpToSignIdreceived request:" .. describeWarpRequest(currentWarpRequest) .. " locking char")
	-- sometimes these get mixed up and you warp to the wrong location.
	fireEvent(aet.avatarEventTypes.GET_READY_FOR_WARP, { sender = "warper" })
	--listener will eventually hear everyone get ready and be locked, do the warp, reset the status.
end

module.WarpToPlayer = function(targetUserId: number)
	if not globalAllowWarpBySetting then
		_annotate("not allowing warp by setting: WarpToPlayer")
		return
	end
	_annotate(string.format("warp to player userId=%d", targetUserId))
	if doingAWarp then
		local desc = describeWarpRequest(currentWarpRequest)
		_annotate(string.format("already doing a warp (WarpToPlayer), it is: %s", desc))
		return
	end
	if currentWarpRequest ~= nil then
		_annotate("WarpToPlayer: set new warp request when one was already set.")
		return
	end
	local newRequest: tt.serverWarpRequest = { kind = "player", targetUserId = targetUserId }
	setDoingAWarp(true, "WarpToPlayer")
	setCurrentWarpRequest(newRequest, "WarpToPlayer")
	_annotate("WarpToPlayer received request:" .. describeWarpRequest(currentWarpRequest) .. " locking char")
	fireEvent(aet.avatarEventTypes.GET_READY_FOR_WARP, { sender = "warper" })
end

--
local eventsWeCareAbout = {
	aet.avatarEventTypes.MOVEMENT_WARPER_READY,
	aet.avatarEventTypes.RACING_WARPER_READY,
	aet.avatarEventTypes.MORPHING_WARPER_READY,
	aet.avatarEventTypes.MARATHON_WARPER_READY,
	aet.avatarEventTypes.MORPHING_RESTARTED,
	aet.avatarEventTypes.MOVEMENT_RESTARTED,
	aet.avatarEventTypes.RACING_RESTARTED,
	aet.avatarEventTypes.MARATHON_RESTARTED,
}

-- when asked to warp we get everybody ready.
-- when the last ready person tells me they are good to go, we do the warp and clear everything.
local function handleAvatarEvent(ev: aet.avatarEvent)
	if not avatarEventFiring.EventIsATypeWeCareAbout(ev, eventsWeCareAbout) then
		return
	end
	while debounceHandleAvatarEvent do
		_annotate("waiting in handleAvatarEvent.")
		task.wait(0.1)
	end
	debounceHandleAvatarEvent = true
	_annotate(string.format("handling: %s", avatarEventFiring.DescribeEvent(ev)))
	if ev.eventType == aet.avatarEventTypes.MOVEMENT_WARPER_READY then
		_annotate("received movement ok")
		setMovementIsReady(true, "MOVEMENT_WARPER_READY event")
	elseif ev.eventType == aet.avatarEventTypes.RACING_WARPER_READY then
		_annotate("received racing ok")
		setRacingIsReady(true, "RACING_WARPER_READY event")
	elseif ev.eventType == aet.avatarEventTypes.MORPHING_WARPER_READY then
		setMorphingIsReady(true, "MORPHING_WARPER_READY event")
	elseif ev.eventType == aet.avatarEventTypes.MARATHON_WARPER_READY then
		setMarathonIsReady(true, "MARATHON_WARPER_READY event")
	elseif ev.eventType == aet.avatarEventTypes.MORPHING_RESTARTED then
		_annotate("received morphing restarted")
		fireEvent(aet.avatarEventTypes.WARP_DONE_RESTART_MOVEMENT, { sender = "warper" })

		debounceHandleAvatarEvent = false
		return
	elseif ev.eventType == aet.avatarEventTypes.MOVEMENT_RESTARTED then
		_annotate("received movement restarted")
		fireEvent(aet.avatarEventTypes.WARP_DONE_RESTART_RACING, { sender = "warper" })

		debounceHandleAvatarEvent = false
		return
	elseif ev.eventType == aet.avatarEventTypes.RACING_RESTARTED then
		_annotate("received racing restarted")
		fireEvent(aet.avatarEventTypes.WARP_DONE_RESTART_MARATHONS, { sender = "warper" })
		debounceHandleAvatarEvent = false
		return
	elseif ev.eventType == aet.avatarEventTypes.MARATHON_RESTARTED then
		_annotate("received marathon restarted")
		TeardownWarpSetup()

		debounceHandleAvatarEvent = false
		return
	else
		warn("unhandled preliminary section event. " .. avatarEventFiring.DescribeEvent(ev))
	end
	if movementIsReady and racingIsReady and morphingIsReady and marathonIsReady then
		-- this is actually the local warping.
		_annotate("ready to warp")

		if currentWarpRequest == nil then
			_annotate("currentWarpRequest is nil")
			debounceHandleAvatarEvent = false
			return
		end

		if not movementIsReady or not racingIsReady or not morphingIsReady or not marathonIsReady then
			debounceHandleAvatarEvent = false
			annotater.Error("somebody was not ready?")
			return
		end
		if not doingAWarp then
			debounceHandleAvatarEvent = false
			annotater.Error("somehow was not doing a warp?")
		end

		-- note that this is a function so that we won't proceed until the warping is done on the server.
		local requestDesc = describeWarpRequest(currentWarpRequest)
		_annotate(string.format("invoking server warp: %s", requestDesc))
		local res: tt.warpResult? = ClientRequestsWarpToRequestFunction:InvokeServer(currentWarpRequest)
		if not res or not res.didWarp then
			local reason = res and res.reason or "no response from server"
			_annotate(string.format("warp failed: %s (request was: %s)", reason, requestDesc))
			-- Only log as error if it's not a benign failure (like character died)
			if reason:find("character") or reason:find("Humanoid") or reason:find("died") then
				_annotate(string.format("warp cancelled due to character state: %s", reason))
			else
				annotater.Error(string.format("warp failed: %s", reason))
			end
			debounceHandleAvatarEvent = false
			TeardownWarpSetup()
			return
		end
		_annotate(string.format("warp succeeded: %s", res.reason))
		-- the only returns when they are **actually done**
		-- res is about whether we moved, for example, some signs can't be warped to easily.

		_annotate("warp request done")
		textHighlighting.KillAllExistingHighlights()
		if currentWarpRequest and currentWarpRequest.highlightSignId then
			_annotate("highlighting " .. tostring(currentWarpRequest.highlightSignId))
			textHighlighting.DoHighlightSingleSignId(currentWarpRequest.highlightSignId, "warper.")
			textHighlighting.RotateCameraToFaceSignId(currentWarpRequest.highlightSignId)
		else
			_annotate("not highlighting")
		end

		--start a series of events where we force the local scripts to restart themselves in the same order.
		_annotate("kicking off cascade of restarting all client scripts after warping.")
		--unset all of these so that
		setRacingIsReady(false, "warp complete, resetting for restart cascade")
		setMarathonIsReady(false, "warp complete, resetting for restart cascade")
		setMorphingIsReady(false, "warp complete, resetting for restart cascade")
		setMovementIsReady(false, "warp complete, resetting for restart cascade")
		fireEvent(aet.avatarEventTypes.WARP_DONE_RESTART_MORPHS, { sender = "warper" })
	else
		_annotate(
			string.format(
				"isMovementReady=%s, isRacingReady=%s, isMorphingReady=%s, isMarathonReady=%s",
				tostring(movementIsReady),
				tostring(racingIsReady),
				tostring(morphingIsReady),
				tostring(marathonIsReady)
			)
		)
	end
	debounceHandleAvatarEvent = false
end

local function handleServerRequestWarpLockEvent(request: tt.serverWarpRequest)
	_annotate(describeWarpRequest(request))
	if not globalAllowWarpBySetting then
		_annotate("not allowing warp by setting")
		return
	end
	if currentWarpRequest ~= nil then
		_annotate("handleServerRequestWarpLockEvent: setting new warp request but one was already set.")
		return
	end
	_annotate("setting currentWarpRequest to: ", request)
	setCurrentWarpRequest(request, "handleServerRequestWarpLockEvent")
	setDoingAWarp(true, "handleServerRequestWarpLockEvent")

	-- why are we firing this again? it was already fired when the user initially did WarpToSignId
	-- ah because sometimes the server is the one initiating it, e.g. when they do "/rr".

	fireEvent(aet.avatarEventTypes.GET_READY_FOR_WARP, { sender = "warper" })
end

local function handleUserSettingChanged(item: tt.userSettingValue)
	if item.name == settingEnums.settingDefinitions.ALLOW_WARP.name then
		globalAllowWarpBySetting = item.booleanValue or false
	end
	return
end

module.Reset = function(context: string?)
	local resetContext = context or "module.Reset"
	_annotate(string.format("Reset (%s)", resetContext))
	setDoingAWarp(false, string.format("%s (Reset doingAWarp)", resetContext))
	setMovementIsReady(false, string.format("%s (Reset movementIsReady)", resetContext))
	setRacingIsReady(false, string.format("%s (Reset racingIsReady)", resetContext))
	setMorphingIsReady(false, string.format("%s (Reset morphingIsReady)", resetContext))
	setMarathonIsReady(false, string.format("%s (Reset marathonIsReady)", resetContext))
	setCurrentWarpRequest(nil, string.format("%s (Reset currentWarpRequest)", resetContext))
	debounceHandleAvatarEvent = false
	logWarpState(string.format("Reset (%s) complete", resetContext))
end

local avatarEventConnection: RBXScriptConnection | nil = nil
local characterAddedConnection: RBXScriptConnection | nil = nil

local function ensureCharacterLifecycleHooks()
	if characterAddedConnection then
		return
	end
	characterAddedConnection = localPlayer.CharacterAdded:Connect(function()
		logWarpState("Player.CharacterAdded received; resetting state immediately")
		module.Reset("Player.CharacterAdded")
	end)
end

module.Init = function()
	_annotate("WARPER init")

	if avatarEventConnection then
		_annotate("disconnecting existing avatarEventConnection")
		avatarEventConnection:Disconnect()
		avatarEventConnection = nil
	else
		_annotate("no existing avatarEventConnection")
	end

	avatarEventConnection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
	ServerRequestClientToWarpLockEvent.OnClientEvent:Connect(function(request: tt.serverWarpRequest)
		handleServerRequestWarpLockEvent(request)
	end)

	settings.RegisterFunctionToListenForSettingName(handleUserSettingChanged, settingEnums.settingDefinitions.ALLOW_WARP.name, "warper")

	ensureCharacterLifecycleHooks()

	module.Reset("module.Init")

	_annotate("init done")
end

_annotate("end")
return module
