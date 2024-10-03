--!strict

-- okay, new way to do this: by logic, morphs go away when a player gets out of a run in any way.
-- either completing or killing it.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local remotes = require(game.ReplicatedStorage.util.remotes)
local AvatarEventBindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
local aet = require(game.ReplicatedStorage.avatarEventTypes)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent
local tt = require(game.ReplicatedStorage.types.gametypes)

-- this is shared w/terrainTouchMonitor incorrectly now. but let's see how it works out.

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

---------- SIGNS ------------
local angerSign = require(game.ReplicatedStorage.specialSigns.angerSign)
local pulseSign = require(game.ReplicatedStorage.specialSigns.pulseSign)
local bigSign = require(game.ReplicatedStorage.specialSigns.bigSign)
local smallSign = require(game.ReplicatedStorage.specialSigns.smallSign)
local ghostSign = require(game.ReplicatedStorage.specialSigns.ghostSign)
local cowSign = require(game.ReplicatedStorage.specialSigns.cowSign)
local fpsSign = require(game.ReplicatedStorage.specialSigns.fpsSign)
local zoomSign = require(game.ReplicatedStorage.specialSigns.zoomSign)
local elonSign = require(game.ReplicatedStorage.specialSigns.elonSign)
local societySign = require(game.ReplicatedStorage.specialSigns.societySign)
local avatarManipulation = require(game.ReplicatedStorage.avatarManipulation)

----------- GLOBALS -----------

local isMorphBlockedByWarp = false
local activeRunSignModule: tt.ScriptInterface | nil = nil

module.GetActiveRunSignModule = function()
	_annotate("someone asked for active run sign module. ")
	if activeRunSignModule then
		_annotate(string.format("active run sign module: %s", activeRunSignModule.GetName()))
	else
		_annotate("no active run sign module.")
	end
	return activeRunSignModule
end

----------- FUNCTIONS -----------
local eventsWeCareAbout: { number } = {
	aet.avatarEventTypes.GET_READY_FOR_WARP,

	aet.avatarEventTypes.WARP_DONE_RESTART_MORPHS, ------ other people killing our runs.
	aet.avatarEventTypes.RUN_CANCEL,
	aet.avatarEventTypes.RUN_COMPLETE,

	aet.avatarEventTypes.RUN_START,
	aet.avatarEventTypes.RETOUCH_SIGN,
	aet.avatarEventTypes.FLOOR_CHANGED,
}

local debounceHandleAvatarEvent = false
local function handleAvatarEvent(ev: aet.avatarEvent)
	if not avatarEventFiring.EventIsATypeWeCareAbout(ev, eventsWeCareAbout) then
		return
	end

	while debounceHandleAvatarEvent do
		_annotate("waiting to handle avatar event.")
		task.wait(0.1)
	end
	debounceHandleAvatarEvent = true

	--- initial section just check for warps.
	if ev.eventType == aet.avatarEventTypes.GET_READY_FOR_WARP then
		_annotate(string.format("handling: %s", avatarEventFiring.DescribeEvent(ev)))
		isMorphBlockedByWarp = true
		avatarManipulation.ResetPhysicalAvatarMorphs(humanoid, character)
		avatarManipulation.AnchorCharacter(humanoid, character)
		if activeRunSignModule then
			activeRunSignModule.InformRunEnded()
			activeRunSignModule = nil
		end
		_annotate("Done morphing warper ready.")
		fireEvent(aet.avatarEventTypes.MORPHING_WARPER_READY, { sender = "morphs" })
		debounceHandleAvatarEvent = false
		return
	elseif ev.eventType == aet.avatarEventTypes.WARP_DONE_RESTART_MORPHS then
		_annotate(string.format("handling: %s", avatarEventFiring.DescribeEvent(ev)))
		if activeRunSignModule then
			warn("you definitely should not have had an active sign module here.")
			activeRunSignModule.InformRunEnded()
			activeRunSignModule = nil
		end
		isMorphBlockedByWarp = false
		avatarManipulation.UnAnchorCharacter(humanoid, character)
		_annotate("Done morphing restarted.")
		fireEvent(aet.avatarEventTypes.MORPHING_RESTARTED, { sender = "morphs" })
		debounceHandleAvatarEvent = false
		return
	else
		-- its okay we handle it later probably.
	end

	if isMorphBlockedByWarp then
		_annotate(
			string.format(
				"morphs rejected incoming avatarEvent because blocked by warp. %s",
				avatarEventFiring.DescribeEvent(ev)
			)
		)
		debounceHandleAvatarEvent = false
		return
	end

	-- ROUTE THESE - WHY NOT HAVE THE SIGN ITSELF MONITOR THE SITUATION?
	if ev.eventType == aet.avatarEventTypes.RUN_CANCEL or ev.eventType == aet.avatarEventTypes.RUN_COMPLETE then
		_annotate("killing or ending run.")
		if activeRunSignModule then
			activeRunSignModule.InformRunEnded()
		else
			-- warn("skipping killing in morph without an active run...")
		end

		--note: among many other places, the fact that the user can arbitrarily send RUN_CANCEL by hitting z at any time makes this confusing!
		avatarManipulation.ResetPhysicalAvatarMorphs(humanoid, character)
		activeRunSignModule = nil
	elseif ev.eventType == aet.avatarEventTypes.RUN_START then
		if activeRunSignModule then
			warn(
				string.format(
					"how can you start a run again with an existing activeRunSignModule ongoing? %s",
					tostring(activeRunSignModule)
				)
			)
			activeRunSignModule.InformRunEnded()
		end
		activeRunSignModule = nil
		avatarManipulation.ResetPhysicalAvatarMorphs(humanoid, character)
		avatarManipulation.ResetMomentum(humanoid, character)

		_annotate("reset momentum")
		if ev.details.startSignName == "Pulse" then
			activeRunSignModule = pulseSign
		elseif ev.details.startSignName == "Big" then
			activeRunSignModule = bigSign
		elseif ev.details.startSignName == "Small" then
			activeRunSignModule = smallSign
		elseif ev.details.startSignName == "👻" then
			activeRunSignModule = ghostSign
		elseif ev.details.startSignName == "🗯" then
			activeRunSignModule = angerSign
		elseif ev.details.startSignName == "FPS" then
			activeRunSignModule = fpsSign
		elseif ev.details.startSignName == "Zoom" then
			activeRunSignModule = zoomSign
		elseif ev.details.startSignName == "Cow" then
			activeRunSignModule = cowSign
		elseif ev.details.startSignName == "Elon" then
			activeRunSignModule = elonSign
		elseif ev.details.startSignName == "Society" then
			activeRunSignModule = societySign
		end
		if activeRunSignModule then
			_annotate("initting active module.")
			activeRunSignModule.InformRunStarting()
		end
		debounceHandleAvatarEvent = false
		return
	elseif ev.eventType == aet.avatarEventTypes.RETOUCH_SIGN then
		--not all of them have this defined.
		if activeRunSignModule and activeRunSignModule.InformRetouch then
			local s, e = pcall(function()
				activeRunSignModule.InformRetouch()
				_annotate("did retouch.")
			end)
			if not s then
				_annotate(string.format("retouch informing sign failed: %s", e))
			end
		end
		-- avatarManipulation.ResetMomentum(humanoid, character)
		debounceHandleAvatarEvent = false
		return
	elseif ev.eventType == aet.avatarEventTypes.FLOOR_CHANGED then
		if activeRunSignModule then
			_annotate("Telling acitve module about floor.")
			activeRunSignModule.InformSawFloorDuringRunFrom(ev.details.floorMaterial)
		end
	else
		warn("unhandled avatar event in morphs. " .. avatarEventFiring.DescribeEvent(ev))
	end
	debounceHandleAvatarEvent = false
end

----- set player to fast update health. theoretically this survives everywhere?
local hb = game:GetService("RunService").Heartbeat
local healthUpdaterSignal = hb:Connect(function()
	if not humanoid then
		return
	end
	local lastHealTick = humanoid:GetAttribute("LastHeal") or 0
	if tick() - lastHealTick > 0.1 and humanoid.Health < humanoid.MaxHealth and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.Health + 1, humanoid.MaxHealth)
		humanoid:SetAttribute("LastHeal", tick())
	end
end)

local avatarEventConnection = nil
module.Init = function()
	_annotate("init")
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	isMorphBlockedByWarp = false
	if avatarEventConnection then
		avatarEventConnection:Disconnect()
		avatarEventConnection = nil
	end
	avatarEventConnection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
	_annotate("init end.")
end

_annotate("end")
return module
