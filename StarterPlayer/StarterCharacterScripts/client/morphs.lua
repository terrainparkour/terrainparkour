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
local avatarManipulation = require(game.StarterPlayer.StarterPlayerScripts.avatarManipulation)

----------- GLOBALS -----------

local isMorphBlockedByWarp = false
local activeRunSignModule = nil

----------- FUNCTIONS -----------

local debouncHandleAvatarEvent = false
local function handleAvatarEvent(ev: mt.avatarEvent)
	--- initial section just check for warps.
	while debouncHandleAvatarEvent do
		-- _annotate("waiting to handle avatar event.")
		wait(0.1)
	end
	debouncHandleAvatarEvent = true

	if ev.eventType == mt.avatarEventTypes.GET_READY_FOR_WARP then
		isMorphBlockedByWarp = true
		activeScaleMultiplerAbsolute = 1
		avatarManipulation.ResetPhysicalAvatarMorphs(humanoid, character)
		avatarManipulation.AnchorCharacter(humanoid, character)
		if activeRunSignModule then
			activeRunSignModule.Kill()
		end
		fireEvent(mt.avatarEventTypes.MORPHING_WARPER_READY, {})
		debouncHandleAvatarEvent = false
		return
	elseif ev.eventType == mt.avatarEventTypes.WARP_DONE_RESTART_MORPHS then
		activeScaleMultiplerAbsolute = 1
		avatarManipulation.ResetPhysicalAvatarMorphs(humanoid, character)
		avatarManipulation.ResetMomentum(humanoid, character)
		avatarManipulation.AnchorCharacter(humanoid, character)
		if activeRunSignModule then
			activeRunSignModule.Kill()
		end
		isMorphBlockedByWarp = false
		fireEvent(mt.avatarEventTypes.MORPHING_RESTARTED, {})
		avatarManipulation.UnAnchorCharacter(humanoid, character)
		debouncHandleAvatarEvent = false
		return
	end

	if isMorphBlockedByWarp then
		--_annotate(
		-- 	"rejected utterly incorporating this because blocked by warp. "
		-- 		.. avatarEventFiring.DescribeEvent(ev.eventType, ev.details)
		-- )
		debouncHandleAvatarEvent = false
		return
	end

	-- ROUTE THESE - WHY NOT HAVE THE SIGN ITSELF MONITOR THE SITUATION?
	if ev.eventType == mt.avatarEventTypes.RUN_KILL or ev.eventType == mt.avatarEventTypes.RUN_COMPLETE then
		if activeRunSignModule then
			activeRunSignModule.Kill()
		else
			warn("skipping killing in morph without an active run...")
		end
		avatarManipulation.ResetPhysicalAvatarMorphs(humanoid, character)
		avatarManipulation.ResetMomentum(humanoid, character)
		activeRunSignModule = nil
	elseif ev.eventType == mt.avatarEventTypes.RUN_START then
		if activeRunSignModule then
			warn("how can you start a run again with an existing run ongoing? %s" .. tostring(activeRunSignModule))
			activeRunSignModule.Kill()
		end
		activeRunSignModule = nil
		avatarManipulation.ResetMomentum(humanoid, character)
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
		end
		if activeRunSignModule then
			activeRunSignModule.Init()
		end
		debouncHandleAvatarEvent = false
		return
	elseif ev.eventType == mt.avatarEventTypes.FLOOR_CHANGED then
		if activeRunSignModule then
			activeRunSignModule.SawFloor(ev.details.floorMaterial)
		end
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
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	isMorphBlockedByWarp = false
	AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
end

_annotate("end")
return module
