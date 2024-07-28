--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local mt = require(game.ReplicatedStorage.avatarEventTypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local colors = require(game.ReplicatedStorage.util.colors)
local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
-- local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
-- local fireEvent = avatarEventFiring.FireEvent

local particleEmitter

local createParticleEmitter = function()
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.EmissionDirection = Enum.NormalId.Back
	particleEmitter.Lifetime = NumberRange.new(1, 1)

	--initially set it to inactive
	particleEmitter.Rate = 0
	particleEmitter.Size = NumberSequence.new(0.3)
	particleEmitter.Name = "PlayerParticleEmitter"
	particleEmitter.SpreadAngle = Vector2.new(12, 12)

	particleEmitter.Parent = humanoid.RootPart
end

local emitParticle = function(color: Color3)
	if particleEmitter == nil then
		createParticleEmitter()
	end
	local particleColor: ColorSequence = ColorSequence.new(color)
	particleEmitter.Color = particleColor
	particleEmitter.Rate = 50

	task.spawn(function()
		wait(0.7)
		particleEmitter.Rate = 0
	end)
end

local eventsWeCareAbout = {
	mt.avatarEventTypes.DO_SPEED_CHANGE,

	mt.avatarEventTypes.RUN_START,
	mt.avatarEventTypes.RUN_COMPLETE,
	mt.avatarEventTypes.RUN_KILL,
	mt.avatarEventTypes.RETOUCH_SIGN,

	mt.avatarEventTypes.RESET_CHARACTER,
	mt.avatarEventTypes.CHARACTER_ADDED,

	mt.avatarEventTypes.FLOOR_CHANGED,
	mt.avatarEventTypes.STATE_CHANGED,
}

local eventIsOkay = function(ev: mt.avatarEvent): boolean
	if table.find(eventsWeCareAbout, ev.eventType) then
		return true
	end
	return false
end

-- 2024: we monitor all incoming events and store ones which are relevant to movement per se.
local handleAvatarEvent = function(ev: mt.avatarEvent)
	-- warn("particles received: " .. mt.avatarEventTypesReverse[ev.eventType])
	if not eventIsOkay(ev) then
		return
	end
	-- _annotate(string.format("\tAccepted event: %s", mt.avatarEventTypesReverse[ev.eventType]))

	if ev.eventType == mt.avatarEventTypes.DO_SPEED_CHANGE then
		if ev.details.newSpeed > ev.details.oldSpeed then
			emitParticle(colors.greenGo)
		else
			emitParticle(colors.redSlowDown)
		end
	elseif ev.eventType == mt.avatarEventTypes.CHARACTER_ADDED then
		emitParticle(colors.lightOrange)
	elseif ev.eventType == mt.avatarEventTypes.RETOUCH_SIGN then
		emitParticle(colors.black)
	elseif ev.eventType == mt.avatarEventTypes.TOUCH_SIGN then
		emitParticle(colors.lightGreen)
	elseif ev.eventType == mt.avatarEventTypes.RUN_COMPLETE then
		emitParticle(colors.lightBlue)
	elseif ev.eventType == mt.avatarEventTypes.RUN_KILL then
		emitParticle(colors.lightGreenPlush)
	elseif ev.eventType == mt.avatarEventTypes.RESET_CHARACTER then
		emitParticle(colors.lightOrange)
	elseif ev.eventType == mt.avatarEventTypes.RUN_START then
		emitParticle(colors.brouText)
	elseif ev.eventType == mt.avatarEventTypes.FLOOR_CHANGED then
		emitParticle(colors.white)
	elseif ev.eventType == mt.avatarEventTypes.STATE_CHANGED then
		if not ev.details then
			error("no details.?")
		end
		if ev.details.newState == Enum.HumanoidStateType.FallingDown then
			emitParticle(colors.magenta)
		elseif ev.details.newState == Enum.HumanoidStateType.Ragdoll then
			emitParticle(colors.subtlePink)
		elseif ev.details.newState == Enum.HumanoidStateType.Jumping then
			emitParticle(colors.brown)
		elseif ev.details.newState == Enum.HumanoidStateType.PlatformStanding then
			emitParticle(colors.turquoise)
		elseif ev.details.newState == Enum.HumanoidStateType.Dead then
			emitParticle(colors.redSlowDown)
		elseif ev.details.newState == Enum.HumanoidStateType.Running then
			emitParticle(colors.lightGreenPlush)
		elseif ev.details.newState == Enum.HumanoidStateType.Swimming then
			emitParticle(colors.lightBlueGreen)
		elseif ev.details.newState == Enum.HumanoidStateType.Freefall then
			emitParticle(colors.pastel)
		end
	end
end

local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)

_annotate("end")
return {}
