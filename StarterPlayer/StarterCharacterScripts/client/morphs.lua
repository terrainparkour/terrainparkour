--!strict

-- okay, new way to do this: by logic, morphs go away when a player gets out of a run in any way.
-- either completing or killing it.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local remotes = require(game.ReplicatedStorage.util.remotes)
local AvatarEventBindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
local mt = require(game.ReplicatedStorage.avatarEventTypes)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent

-- this is shared w/terrainTouchMonitor incorrectly now. but let's see how it works out.

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

---------- SIGNS ------------
local angerSign = require(game.StarterPlayer.StarterCharacterScripts.specialSigns.angerSign)
local pulseSign = require(game.StarterPlayer.StarterCharacterScripts.specialSigns.pulseSign)
local bigSign = require(game.StarterPlayer.StarterCharacterScripts.specialSigns.bigSign)
local smallSign = require(game.StarterPlayer.StarterCharacterScripts.specialSigns.smallSign)
local ghostSign = require(game.StarterPlayer.StarterCharacterScripts.specialSigns.ghostSign)
local cowSign = require(game.StarterPlayer.StarterCharacterScripts.specialSigns.cowSign)
local avatarManipulation = require(game.StarterPlayer.StarterPlayerScripts.avatarManipulation)

----------- GLOBALS -----------

local isMorphBlockedByWarp = false
local activeRunSignModule = nil

----------- FUNCTIONS -----------

local debouncHandleAvatarEvent = false
local function handleAvatarEvent(ev: mt.avatarEvent)
	--- initial section just check for warps.
	_annotate(string.format("handling afvatar event. %s", avatarEventFiring.DescribeEvent(ev.eventType, ev.details)))
	while debouncHandleAvatarEvent do
		-- _annotate("waiting to handle avatar event.")
		wait(0.1)
	end
	debouncHandleAvatarEvent = true

	if ev.eventType == mt.avatarEventTypes.GET_READY_FOR_WARP then
		_annotate("getign ready for warp.)")
		isMorphBlockedByWarp = true
		activeScaleMultiplerAbsolute = 1
		avatarManipulation.ResetPhysicalAvatarMorphs(humanoid, character)
		avatarManipulation.AnchorCharacter(humanoid, character)
		if activeRunSignModule then
			activeRunSignModule.InformRunEnded()
			activeRunSignModule = nil
		end
		fireEvent(mt.avatarEventTypes.MORPHING_WARPER_READY, {})
		debouncHandleAvatarEvent = false
		_annotate("Done morphing warper ready.")
		return
	elseif ev.eventType == mt.avatarEventTypes.WARP_DONE_RESTART_MORPHS then
		_annotate("restarting morphs.")
		activeScaleMultiplerAbsolute = 1
		avatarManipulation.ResetPhysicalAvatarMorphs(humanoid, character)
		avatarManipulation.ResetMomentum(humanoid, character)
		avatarManipulation.AnchorCharacter(humanoid, character)
		if activeRunSignModule then
			warn("you definitely should not have had an active sign module here.")
			activeRunSignModule.InformRunEnded()
			activeRunSignModule = nil
		end
		isMorphBlockedByWarp = false
		fireEvent(mt.avatarEventTypes.MORPHING_RESTARTED, {})
		avatarManipulation.UnAnchorCharacter(humanoid, character)
		debouncHandleAvatarEvent = false
		_annotate("Done morphing restarted.")
		return
	end

	if isMorphBlockedByWarp then
		_annotate(
			"rejected utterly incorporating this because blocked by warp. "
				.. avatarEventFiring.DescribeEvent(ev.eventType, ev.details)
		)
		debouncHandleAvatarEvent = false
		return
	end

	-- ROUTE THESE - WHY NOT HAVE THE SIGN ITSELF MONITOR THE SITUATION?
	if ev.eventType == mt.avatarEventTypes.RUN_CANCEL or ev.eventType == mt.avatarEventTypes.RUN_COMPLETE then
		_annotate("killing or ending run.")
		if activeRunSignModule then
			activeRunSignModule.InformRunEnded()
		else
			-- warn("skipping killing in morph without an active run...")
		end

		--note: among many other places, the fact that the user can arbitrarily send RUN_CANCEL by hitting z at any time makes this confusing!
		avatarManipulation.ResetPhysicalAvatarMorphs(humanoid, character)
		activeRunSignModule = nil
	elseif ev.eventType == mt.avatarEventTypes.RUN_START then
		if activeRunSignModule then
			warn(
				"how can you start a run again with an existing activeRunSignModule ongoing? %s"
					.. tostring(activeRunSignModule)
			)
			activeRunSignModule.InformRunEnded()
		end
		activeRunSignModule = nil
		if ev.details.relatedSignName == "Pulse" then
			activeRunSignModule = pulseSign
		elseif ev.details.relatedSignName == "Big" then
			activeRunSignModule = bigSign
		elseif ev.details.relatedSignName == "Small" then
			activeRunSignModule = smallSign
		elseif ev.details.relatedSignName == "👻" then
			activeRunSignModule = ghostSign
		elseif ev.details.relatedSignName == "🗯" then
			activeRunSignModule = angerSign
		elseif ev.details.relatedSignName == "Cow" then
			activeRunSignModule = cowSign
		end
		if activeRunSignModule then
			_annotate("initting active module.")
			activeRunSignModule.InformRunStarting()
		end
		debouncHandleAvatarEvent = false
		return
	elseif ev.eventType == mt.avatarEventTypes.FLOOR_CHANGED then
		if activeRunSignModule then
			_annotate("Telling acitve module about floor.")
			activeRunSignModule.InformSawFloorDuringRunFrom(ev.details.floorMaterial)
		end
	end

	if 
		ev.eventType == mt.avatarEventTypes.RUN_START
		or ev.eventType == mt.avatarEventTypes.RUN_CANCEL
		or ev.eventType == mt.avatarEventTypes.RUN_COMPLETE
		or ev.eventType == mt.avatarEventTypes.RETOUCH_SIGN
	then
		avatarManipulation.ResetAbnormalMomentum(humanoid, character)
	end
	debouncHandleAvatarEvent = false
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

module.Init = function()
	_annotate("init")
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	isMorphBlockedByWarp = false
	AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
	_annotate("init end.")
end

_annotate("end")
return module
