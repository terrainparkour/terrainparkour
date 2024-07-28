--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)
local AvatarEventBindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
local mt = require(game.ReplicatedStorage.avatarEventTypes)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent
local Players = game:GetService("Players")

local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local movementUtil = require(game.StarterPlayer.StarterPlayerScripts.util.movementUtil)

-- okay, new way to do this: by logic, morphs go away when a player gets out of a run in any way.
-- either completing or killing it.

local originalScale = character:GetScale()
if originalScale ~= 1 then
	_annotate("player entered without initial scale of 1.0")
end
local activeScaleMultiplerAbsolute = originalScale

local deb = false
local ResetPhysicalAvatarMorphs = function()
	if deb then
		return
	end
	_annotate("DEB.resetPhysicalAvatarMorphs")
	deb = true
	-- character:ScaleTo(originalScale / activeScaleMultiplerAbsolute)
	character:ScaleTo(1)
	activeScaleMultiplerAbsolute = 1
	local changedTransparency = movementUtil.SetCharacterTransparency(localPlayer, 0)
	if changedTransparency then
		_annotate("transparency restored.")
	end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
		_annotate("reset state yet char is in ragdoll.")
		--this happens because there is some lag in setting state
		--this can happen after warping
		--we should ban runs from this point, but don't currently.
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
	deb = false
end

local deb2 = false
local DoLaunchForPulse = function()
	if deb2 then
		return
	end
	_annotate("DEB.DoLaunchForPulse")
	deb2 = true

	local daysSince1970 = os.difftime(
		os.time(),
		os.time({ year = 1970, month = 1, day = 1, hour = 0, min = 0, sec = 0, isdst = false })
	) / 86400
	local seed = math.floor(daysSince1970)
	local pulseRandom = Random.new(seed) :: Random
	local verticalAngle = math.rad(pulseRandom:NextInteger(45, 90))
	local horizontalAngle = math.rad(pulseRandom:NextInteger(0, 359))
	local pulsePower = pulseRandom:NextInteger(200, 1300)
	-- print("pulsePower: " .. tostring(pulsePower))
	local y = math.sin(verticalAngle)
	local horizontalComponent = math.cos(verticalAngle)
	local x = horizontalComponent * math.cos(horizontalAngle)
	local z = horizontalComponent * math.sin(horizontalAngle)

	local direction = Vector3.new(x, y, z).Unit
	local thisServerPulseVector = direction * pulsePower
	character.PrimaryPart.AssemblyLinearVelocity = thisServerPulseVector
	deb2 = false
end

-- when a user even touches a sign at all, we reset
local momdeb = false
local ResetMomentum = function()
	if momdeb then
		return
	end
	momdeb = true
	_annotate("\t\tresetMomentum")
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	if rootPart == nil then
		error("fail")
	end
	-- well, this will certainly remove momentum from the user. But it doesn't feel pleasant.
	rootPart.Anchored = true
	rootPart.Anchored = false

	-- 2024 still unclear what this does, too.
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

	-- 2024: is this effectively just the server version of resetting movement states?

	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	while true do
		local state = humanoid:GetState()
		if
			state == Enum.HumanoidStateType.GettingUp
			or state == Enum.HumanoidStateType.Running
			or state == Enum.HumanoidStateType.Freefall
			or state == Enum.HumanoidStateType.Dead
			or state == Enum.HumanoidStateType.Swimming
		then
			_annotate("state passed")
			break
		end

		wait()
		_annotate("waited.in resetMomentum")
	end
	_annotate("movement:\tmomentum has been reset.")
	momdeb = false
end

local isMorphBlockedByWarp = false
AvatarEventBindableEvent.Event:Connect(function(ev: mt.avatarEvent)
	if ev.eventType == mt.avatarEventTypes.GET_READY_FOR_WARP then
		isMorphBlockedByWarp = true
		ResetPhysicalAvatarMorphs()
		ResetMomentum()
		fireEvent(mt.avatarEventTypes.MORPHING_WARPER_READY, {})
		return
	elseif ev.eventType == mt.avatarEventTypes.WARP_DONE then
		ResetPhysicalAvatarMorphs()
		ResetMomentum()
		isMorphBlockedByWarp = false
		return
	end

	if isMorphBlockedByWarp then
		_annotate("morphing warping ignored event:" .. mt.avatarEventTypesReverse[ev.eventType])
		return
	end
	_annotate("morphs accepted: " .. mt.avatarEventTypesReverse[ev.eventType])
	if ev.eventType == mt.avatarEventTypes.RUN_KILL or ev.eventType == mt.avatarEventTypes.RUN_COMPLETE then
		ResetMomentum()
		ResetPhysicalAvatarMorphs()
	elseif ev.eventType == mt.avatarEventTypes.RUN_START then
		ResetMomentum()
		if ev.details.relatedSignName == "Pulse" then
			DoLaunchForPulse()
		elseif ev.details.relatedSignName == "Big" then
			local newMultipler = originalScale * 2 / activeScaleMultiplerAbsolute
			character:ScaleTo(newMultipler)
			activeScaleMultiplerAbsolute = originalScale * 2
		elseif ev.details.relatedSignName == "Small" then
			local newMultipler = originalScale / activeScaleMultiplerAbsolute / 2
			character:ScaleTo(newMultipler)
			activeScaleMultiplerAbsolute = originalScale / 2
		end
	end
end)

_annotate("end")
return {}
