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

local mt = require(game.ReplicatedStorage.avatarEventTypes)

---------- CHARACTER -------------
local localPlayer: Player = game.Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

local WarpRequestFunction = remotes.getRemoteFunction("WarpRequestFunction")
local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
local HighlightSignIdEvent: RemoteEvent = remotes.getRemoteEvent("HighlightSignIdEvent")

local module = {}

------------------ GLOBAL STATE VARS------------------
local doingAWarp = false
local movementIsReady = false
local racingIsReady = false
local morphingIsReady = false
local marathonIsReady = false
local warpTargetSignId: number? = nil
local highlightTargetSignId: number? = nil
local debounceHandleAvatarEvent = false

--------------- FUNCTIONS ------------------

local function LockEveryoneForWarp()
	_annotate("locking everyone for warp")
	fireEvent(mt.avatarEventTypes.GET_READY_FOR_WARP, {})
end

local function TeardownWarpSetup()
	_annotate("teardown warp setup")
	movementIsReady = false
	racingIsReady = false
	morphingIsReady = false
	marathonIsReady = false
	warpTargetSignId = nil
	highlightTargetSignId = nil
	doingAWarp = false
end

local function HaveServerDoWarp()
	_annotate("have server do warp, my local highlightSignId is: " .. tostring(highlightTargetSignId))
	if not movementIsReady or not racingIsReady or not morphingIsReady then
		error("somebody was not ready?")
		return
	end
	if not doingAWarp then
		error("somehow was not doing a warp?")
	end

	--tell everyone who cares that warping is happening now.
	WarpRequestFunction:InvokeServer(warpTargetSignId)
	_annotate("warp request done")
	if highlightTargetSignId and highlightTargetSignId ~= 0 then
		_annotate("highlighting " .. tostring(highlightTargetSignId))
		textHighlighting.KillAllExistingHighlights()
		textHighlighting.DoHighlightSingleSignId(highlightTargetSignId)
	else
		_annotate("not highlighting")
	end
end

module.WarpToSign = function(warpToSignId: number, highlightSignId: number?)
	_annotate("warp to sign" .. tostring(warpToSignId) .. " highlight " .. tostring(highlightSignId))
	if doingAWarp then
		warn("already doing a warp")
		return
	end
	doingAWarp = true
	warpTargetSignId = warpToSignId
	highlightTargetSignId = highlightSignId
	LockEveryoneForWarp()
end

-- when asked to warp we get everybody ready.
-- when the last ready person tells me they are good to go, we do the warp and clear everything.

local function handleAvatarEvent(ev: mt.avatarEvent)
	while debounceHandleAvatarEvent do
		_annotate("handleAvatarEvent in warper" .. tostring(ev.eventType))
		task.wait() -- Wait until the lock is released
	end

	debounceHandleAvatarEvent = true
	if ev.eventType == mt.avatarEventTypes.MOVEMENT_WARPER_READY then
		movementIsReady = true
	elseif ev.eventType == mt.avatarEventTypes.RACING_WARPER_READY then
		racingIsReady = true
	elseif ev.eventType == mt.avatarEventTypes.MORPHING_WARPER_READY then
		morphingIsReady = true
	elseif ev.eventType == mt.avatarEventTypes.MARATHON_WARPER_READY then
		marathonIsReady = true
	end
	if movementIsReady and racingIsReady and morphingIsReady and marathonIsReady then
		_annotate("ready to warp")
		HaveServerDoWarp()
		TeardownWarpSetup()
		fireEvent(mt.avatarEventTypes.WARP_DONE, {})
		_annotate("warp done")
	end
	debounceHandleAvatarEvent = false
end

module.Init = function()
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	debounceHandleAvatarEvent = false

	AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
end

_annotate("end")
return module
