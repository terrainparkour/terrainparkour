--!strict

-- new structure:
-- when the user sends a warp request, we tell everyone about it.
-- they all send back any required blocks and just stay in that broken state (race stopped, character reset momentum, etc.) til freed.
-- we wait for all those messages to get back to us. once that's done we do the warp.
-- then we send the other guys that warping is okay.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)

local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)
local tt = require(game.ReplicatedStorage.types.gametypes)

local mt = require(game.ReplicatedStorage.avatarEventTypes)

---------- CHARACTER -------------
local localPlayer: Player = game.Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

local ClientRequestsWarpToRequestFunction = remotes.getRemoteFunction("ClientRequestsWarpToRequestFunction")
local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
-- local HighlightSignIdEvent: RemoteEvent = remotes.getRemoteEvent("HighlightSignIdEvent")
local ServerRequestClientToWarpLockEvent: RemoteEvent = remotes.getRemoteEvent("ServerRequestClientToWarpLockEvent")

local module = {}

------------------ GLOBAL STATE VARS------------------
local doingAWarp = false
local movementIsReady = false
local racingIsReady = false
local morphingIsReady = false
local marathonIsReady = false

-- when we get a warp request we set these to remember where to go.
local currentWarpRequest: tt.serverWarpRequest | nil = nil

--------------- DEBOUNCERS ---------------
local debounceHandleAvatarEvent = false

-------------- FUNCTIONS ------------------

--
local function TeardownWarpSetup()
	_annotate("teardown warp setup")
	movementIsReady = false
	racingIsReady = false
	morphingIsReady = false
	marathonIsReady = false
	doingAWarp = false
	if currentWarpRequest == nil then
		warn("currentWarpRequest is nil")
	end
	currentWarpRequest = nil
end

-- the client has locked down all local scripts which need to get into a certain state before the server
-- can warp the player. That is, races are cancelled, etc.
-- then we do the warp.

module.WarpToSignId = function(warpToSignId: number, highlightSignId: number?)
	_annotate("warp to sign" .. tostring(warpToSignId) .. " highlight " .. tostring(highlightSignId))
	if doingAWarp then
		warn("already doing a warp")
		return
	end
	doingAWarp = true
	if currentWarpRequest ~= nil then
		warn("set new warp request when one was alread set.")
		return
	end
	currentWarpRequest = { kind = "sign", signId = warpToSignId, highlightSignId = highlightSignId }

	-- sometimes these get mixed up and you warp to the wrong location.
	_annotate("locking everyone for warp")
	fireEvent(mt.avatarEventTypes.GET_READY_FOR_WARP, {})
	--listener will eventually hear everyone get ready and be locked, do the warp, reset the status.
end

-- when asked to warp we get everybody ready.
-- when the last ready person tells me they are good to go, we do the warp and clear everything.
local function handleAvatarEvent(ev: mt.avatarEvent)
	while debounceHandleAvatarEvent do
		_annotate("waiting in handleAvatarEvent.")
		task.wait(0.1)
	end
	debounceHandleAvatarEvent = true
	_annotate(string.format("handleAvatarEvent: %s", avatarEventFiring.DescribeEvent(ev.eventType, ev.details)))
	if ev.eventType == mt.avatarEventTypes.MOVEMENT_WARPER_READY then
		_annotate("received movement ok")
		movementIsReady = true
	elseif ev.eventType == mt.avatarEventTypes.RACING_WARPER_READY then
		_annotate("received racing ok")
		racingIsReady = true
	elseif ev.eventType == mt.avatarEventTypes.MORPHING_WARPER_READY then
		morphingIsReady = true
	elseif ev.eventType == mt.avatarEventTypes.MARATHON_WARPER_READY then
		marathonIsReady = true
	elseif ev.eventType == mt.avatarEventTypes.MORPHING_RESTARTED then
		_annotate("received morphing restarted")
		fireEvent(mt.avatarEventTypes.WARP_DONE_RESTART_MOVEMENT, {})

		debounceHandleAvatarEvent = false
		return
	elseif ev.eventType == mt.avatarEventTypes.MOVEMENT_RESTARTED then
		_annotate("received movement restarted")
		fireEvent(mt.avatarEventTypes.WARP_DONE_RESTART_RACING, {})

		debounceHandleAvatarEvent = false
		return
	elseif ev.eventType == mt.avatarEventTypes.RACING_RESTARTED then
		_annotate("received racing restarted")
		fireEvent(mt.avatarEventTypes.WARP_DONE_RESTART_MARATHONS, {})

		debounceHandleAvatarEvent = false
		return
	elseif ev.eventType == mt.avatarEventTypes.MARATHON_RESTARTED then
		_annotate("received marathon restarted")
		TeardownWarpSetup()

		debounceHandleAvatarEvent = false
		return
	end
	if movementIsReady and racingIsReady and morphingIsReady and marathonIsReady then
		-- this is actually the local warping.
		_annotate("ready to warp")

		if currentWarpRequest == nil then
			_annotate("currentWarpRequest is nil")
			debounceHandleAvatarEvent = false
			return
		end

		local currentText = ""
		if currentWarpRequest then
			currentText = string.format(
				"kind: %s signId: %s highlightSignId: %s position: %s",
				currentWarpRequest.kind,
				tostring(currentWarpRequest.signId),
				tostring(currentWarpRequest.highlightSignId),
				tostring(currentWarpRequest.position)
			)
			_annotate(
				string.format(
					"have server do warp, current warp request details are: currentWarpRequest=%s doingAWarp=%s movementIsReady=%s racingIsReady=%s morphingIsReady=%s marathonIsReady=%s",
					currentText,
					tostring(doingAWarp),
					tostring(movementIsReady),
					tostring(racingIsReady),
					tostring(morphingIsReady),
					tostring(marathonIsReady)
				)
			)
		end

		if not movementIsReady or not racingIsReady or not morphingIsReady or not marathonIsReady then
			debounceHandleAvatarEvent = false
			error("somebody was not ready?")
			return
		end
		if not doingAWarp then
			debounceHandleAvatarEvent = false
			error("somehow was not doing a warp?")
		end

		-- note that this is a function so that we won't proceed until the warping is done on the server.
		local res = ClientRequestsWarpToRequestFunction:InvokeServer(currentWarpRequest)
		_annotate("warp request done")
		if currentWarpRequest.highlightSignId then
			_annotate("highlighting " .. tostring(currentWarpRequest.highlightSignId))
			textHighlighting.KillAllExistingHighlights()
			textHighlighting.DoHighlightSingleSignId(currentWarpRequest.highlightSignId)
			textHighlighting.RotateCameraToFaceSignId(currentWarpRequest.highlightSignId)
		else
			_annotate("not highlighting")
		end

		--start a series of events where we force the local scripts to restart themselves in the same order.
		_annotate("kicking of in-order restart of scripts.")
		--unset all of these so that
		racingIsReady = false
		marathonIsReady = false
		morphingIsReady = false
		movementIsReady = false
		fireEvent(mt.avatarEventTypes.WARP_DONE_RESTART_MORPHS, {})
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
	_annotate(
		string.format(
			"handleServerRequestWarpLockEvent received. kind: %s signId: %s highlightSignId: %s position: %s",
			tostring(request.kind),
			tostring(request.signId),
			tostring(request.highlightSignId),
			tostring(request.position)
		)
	)

	if currentWarpRequest ~= nil then
		warn("set new warp request when one was alread set.")
		return
	end
	currentWarpRequest = request
	doingAWarp = true
	fireEvent(mt.avatarEventTypes.GET_READY_FOR_WARP, {})
end

module.Init = function()
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	debounceHandleAvatarEvent = false

	AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
	ServerRequestClientToWarpLockEvent.OnClientEvent:Connect(function(request: tt.serverWarpRequest)
		handleServerRequestWarpLockEvent(request)
	end)
end

_annotate("end")
return module
