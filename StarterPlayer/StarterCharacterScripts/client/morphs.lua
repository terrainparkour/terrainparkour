--!strict

-- okay, new way to do this: by logic, morphs go away when a player gets out of a run in any way.
-- either completing or killing it.

local annotater = require(game.ReplicatedStorage.util.annotater)

local function emitMorphLog(message: string)
	print(message)
end

local _annotate = annotater.getAnnotater(script, emitMorphLog)

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
local activeRunSignModule: tt.SpecialSignInterface | nil = nil

local function describeMorphState(): string
	local activeName = if activeRunSignModule then activeRunSignModule.GetName() else "none"
	return string.format("morphState{blocked=%s,active=%s}", tostring(isMorphBlockedByWarp), activeName)
end

local function logMorphState(context: string)
	_annotate(string.format("%s %s", context, describeMorphState()))
end

local function setMorphWarpBlocked(nextValue: boolean, context: string)
	if isMorphBlockedByWarp == nextValue then
		return
	end
	isMorphBlockedByWarp = nextValue
	logMorphState(string.format("isMorphBlockedByWarp -> %s (%s)", tostring(nextValue), context))
end

local function setActiveRunSignModule(nextModule: tt.SpecialSignInterface | nil, context: string)
	if activeRunSignModule == nextModule then
		return
	end
	activeRunSignModule = nextModule
	local name = if nextModule then nextModule.GetName() else "none"
	logMorphState(string.format("activeRunSignModule -> %s (%s)", name, context))
end

module.GetActiveRunSignModule = function()
	_annotate("someone asked for active run sign module. ")
	if activeRunSignModule then
		_annotate(string.format("active run sign module: %s", activeRunSignModule.GetName()))
	else
		_annotate("no active run sign module.")
	end
	return activeRunSignModule
end

module.Reset = function()
	_annotate("Reset")
	setMorphWarpBlocked(false, "module.Reset")
	-- Ensure character is up to date on reset
	if localPlayer.Character then
		character = localPlayer.Character
		humanoid = character:FindFirstChild("Humanoid") :: Humanoid
	end

	if activeRunSignModule then
		_annotate("Reset: cleaning up active run sign module.")
		activeRunSignModule.InformRunEnded()
		setActiveRunSignModule(nil, "module.Reset cleanup")
	end

	if humanoid and character then
		avatarManipulation.ResetPhysicalAvatarMorphs(humanoid, character)
		avatarManipulation.ResetMomentum(humanoid, character)
	end
	logMorphState("Reset complete")
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

	-- Added for explicit cleanup on death
	aet.avatarEventTypes.AVATAR_DIED,
	aet.avatarEventTypes.AVATAR_RESET,
	aet.avatarEventTypes.CHARACTER_REMOVING,
}

local debounceHandleAvatarEvent = false
local function handleAvatarEvent(ev: aet.avatarEvent)
	if not avatarEventFiring.EventIsATypeWeCareAbout(ev, eventsWeCareAbout) then
		return
	end
	_annotate(string.format("handling: %s %s", avatarEventFiring.DescribeEvent(ev), describeMorphState()))

	while debounceHandleAvatarEvent do
		_annotate("waiting to handle avatar event.")
		task.wait(0.1)
	end
	debounceHandleAvatarEvent = true

	--- initial section just check for warps.
	if ev.eventType == aet.avatarEventTypes.GET_READY_FOR_WARP then
		_annotate(string.format("handling: %s", avatarEventFiring.DescribeEvent(ev)))
		setMorphWarpBlocked(true, "GET_READY_FOR_WARP")
		avatarManipulation.ResetPhysicalAvatarMorphs(humanoid, character)
		avatarManipulation.AnchorCharacter(humanoid, character)
		if activeRunSignModule then
			activeRunSignModule.InformRunEnded()
			setActiveRunSignModule(nil, "GET_READY_FOR_WARP")
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
			setActiveRunSignModule(nil, "WARP_DONE_RESTART_MORPHS cleanup")
		end
		setMorphWarpBlocked(false, "WARP_DONE_RESTART_MORPHS")
		avatarManipulation.UnAnchorCharacter(humanoid, character)
		_annotate("Done morphing restarted.")
		fireEvent(aet.avatarEventTypes.MORPHING_RESTARTED, { sender = "morphs" })
		debounceHandleAvatarEvent = false
		return
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
	if
		ev.eventType == aet.avatarEventTypes.RUN_CANCEL
		or ev.eventType == aet.avatarEventTypes.RUN_COMPLETE
		or ev.eventType == aet.avatarEventTypes.AVATAR_DIED
		or ev.eventType == aet.avatarEventTypes.AVATAR_RESET
		or ev.eventType == aet.avatarEventTypes.CHARACTER_REMOVING
	then
		_annotate(string.format("killing or ending run due to: %s", aet.avatarEventTypesReverse[ev.eventType]))
		if activeRunSignModule then
			activeRunSignModule.InformRunEnded()
		end

		--note: among many other places, the fact that the user can arbitrarily send RUN_CANCEL by hitting z at any time makes this confusing!
		avatarManipulation.ResetPhysicalAvatarMorphs(humanoid, character)
		setActiveRunSignModule(nil, "RUN_END")
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
		setActiveRunSignModule(nil, "RUN_START reset")
		avatarManipulation.ResetPhysicalAvatarMorphs(humanoid, character)
		avatarManipulation.ResetMomentum(humanoid, character)

		_annotate("reset momentum")
		local chosenModule: tt.SpecialSignInterface | nil = nil
		if ev.details.startSignName == "Pulse" then
			chosenModule = pulseSign
		elseif ev.details.startSignName == "Big" then
			chosenModule = bigSign
		elseif ev.details.startSignName == "Small" then
			chosenModule = smallSign
		elseif ev.details.startSignName == "👻" then
			chosenModule = ghostSign
		elseif ev.details.startSignName == "🗯" then
			chosenModule = angerSign
		elseif ev.details.startSignName == "FPS" then
			chosenModule = fpsSign
		elseif ev.details.startSignName == "Zoom" then
			chosenModule = zoomSign
		elseif ev.details.startSignName == "Cow" then
			chosenModule = cowSign
		elseif ev.details.startSignName == "Elon" then
			chosenModule = elonSign
		elseif ev.details.startSignName == "Society" then
			chosenModule = societySign
		end
		setActiveRunSignModule(chosenModule, "RUN_START")
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
		if activeRunSignModule and ev.details then
			local floorMatValue: Enum.Material? = ev.details.floorMaterial
			if floorMatValue then
				local floorMat: Enum.Material = floorMatValue
				_annotate("Telling acitve module about floor.")
				activeRunSignModule.InformSawFloorDuringRunFrom(floorMat)
			end
		end
	else
		warn("unhandled avatar event in morphs. " .. avatarEventFiring.DescribeEvent(ev))
	end
	debounceHandleAvatarEvent = false
end

----- set player to fast update health. theoretically this survives everywhere?
local hb = game:GetService("RunService").Heartbeat
hb:Connect(function()
	if not humanoid then
		return
	end
	local lastHealTickValue = humanoid:GetAttribute("LastHeal")
	local lastHealTick: number = if typeof(lastHealTickValue) == "number" then lastHealTickValue :: number else 0
	if tick() - lastHealTick > 0.1 and humanoid.Health < humanoid.MaxHealth and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.Health + 1, humanoid.MaxHealth)
		humanoid:SetAttribute("LastHeal", tick())
	end
end)

local avatarEventConnection = nil
local characterAddedConnection = nil

local function ensureCharacterLifecycleHooks()
	if characterAddedConnection then
		return
	end
	characterAddedConnection = localPlayer.CharacterAdded:Connect(function()
		logMorphState("Player.CharacterAdded received; resetting state")
		module.Reset()
	end)
end

module.Init = function()
	_annotate("init")
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	setMorphWarpBlocked(false, "module.Init")

	-- Connect only if not connected (Singleton pattern)
	if avatarEventConnection then
		avatarEventConnection:Disconnect()
	end
	avatarEventConnection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)

	ensureCharacterLifecycleHooks()

	-- Ensure we reset state for the new life cycle
	module.Reset()

	_annotate("init end.")
end

_annotate("end")

return module
