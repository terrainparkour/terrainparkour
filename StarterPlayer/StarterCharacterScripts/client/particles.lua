--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local mt = require(game.ReplicatedStorage.avatarEventTypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local colors = require(game.ReplicatedStorage.util.colors)
local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local emitters: { [Color3]: ParticleEmitter } = {}

local createParticleEmitter = function(color3)
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	local particleEmitter: ParticleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.EmissionDirection = Enum.NormalId.Back
	particleEmitter.Lifetime = NumberRange.new(0, 10)

	--initially set it to inactive
	particleEmitter.Rate = 0
	particleEmitter.Size = NumberSequence.new(0.3)
	particleEmitter.Name = "PlayerParticleEmitter." .. color3.r .. color3.g .. color3.b
	particleEmitter.SpreadAngle = Vector2.new(22, 12)
	particleEmitter.Parent = humanoid.RootPart
	emitters[color3] = particleEmitter
end

local function getOrCreateEmitter(color: Color3): ParticleEmitter
	if not emitters[color] then
		createParticleEmitter(color)
	end
	return emitters[color]
end

local emitParticle = function(color: Color3, rate: number?)
	local particleEmitter: ParticleEmitter = getOrCreateEmitter(color)
	local particleColor: ColorSequence = ColorSequence.new(color)
	particleEmitter.Color = particleColor

	if rate then
		particleEmitter.Rate = rate
	else
		particleEmitter.Rate = 50
	end

	task.spawn(function()
		local startTime = tick()
		local duration = 3
		local initialRate = particleEmitter.Rate

		while tick() - startTime < duration do
			local elapsedTime = tick() - startTime
			local t = elapsedTime / duration
			local newRate = initialRate * (1 - t)
			particleEmitter.Rate = newRate
			task.wait(0.1) -- Update rate every 0.1 seconds
		end

		particleEmitter.Rate = 0
	end)
end

local eventsWeCareAbout = {
	mt.avatarEventTypes.DO_SPEED_CHANGE,

	mt.avatarEventTypes.RUN_START,
	mt.avatarEventTypes.RUN_COMPLETE,
	mt.avatarEventTypes.RUN_KILL,
	mt.avatarEventTypes.RETOUCH_SIGN,
	mt.avatarEventTypes.TOUCH_SIGN,

	mt.avatarEventTypes.RESET_CHARACTER,
	mt.avatarEventTypes.CHARACTER_ADDED,

	mt.avatarEventTypes.FLOOR_CHANGED,
	mt.avatarEventTypes.STATE_CHANGED,
	mt.avatarEventTypes.AVATAR_CHANGED_DIRECTION,
	mt.avatarEventTypes.AVATAR_STARTED_MOVING,
	mt.avatarEventTypes.AVATAR_STOPPED_MOVING,
}

local eventIsATypeWeCareAbout = function(ev: mt.avatarEvent): boolean
	for _, value in pairs(eventsWeCareAbout) do
		if value == ev.eventType then
			return true
		end
	end
	return false
end

-- 2024: we monitor all incoming events and store ones which are relevant to movement per se.
local handleAvatarEvent = function(ev: mt.avatarEvent)
	if not eventIsATypeWeCareAbout(ev) then
		return
	end

	if ev.eventType == mt.avatarEventTypes.DO_SPEED_CHANGE then
		if ev.details.newSpeed > ev.details.oldSpeed then
			emitParticle(colors.greenGo)
		else
			emitParticle(colors.redSlowDown)
		end
	elseif ev.eventType == mt.avatarEventTypes.CHARACTER_ADDED then
		emitParticle(colors.lightOrange)
	elseif ev.eventType == mt.avatarEventTypes.RETOUCH_SIGN then
		emitParticle(colors.darkGreen, 1200)
	elseif ev.eventType == mt.avatarEventTypes.TOUCH_SIGN then
		emitParticle(colors.lightGreen, 2000)
	elseif ev.eventType == mt.avatarEventTypes.RUN_COMPLETE then
		emitParticle(colors.lightBlue)
	elseif ev.eventType == mt.avatarEventTypes.RUN_KILL then
		emitParticle(colors.lightGreenPlush)
	elseif ev.eventType == mt.avatarEventTypes.AVATAR_RESET then
		emitParticle(colors.lightOrange)
	elseif ev.eventType == mt.avatarEventTypes.RUN_START then
		emitParticle(colors.brouText)
	elseif ev.eventType == mt.avatarEventTypes.FLOOR_CHANGED then
		emitParticle(colors.white)
	elseif ev.eventType == mt.avatarEventTypes.AVATAR_CHANGED_DIRECTION then
		emitParticle(colors.blueDone, 1000)
	elseif ev.eventType == mt.avatarEventTypes.AVATAR_STARTED_MOVING then
		emitParticle(colors.greenGo, 1000)
	elseif ev.eventType == mt.avatarEventTypes.AVATAR_STOPPED_MOVING then
		emitParticle(colors.redStop, 1000)
	elseif ev.eventType == mt.avatarEventTypes.STATE_CHANGED then
		if ev.details.newState == Enum.HumanoidStateType.FallingDown then
			emitParticle(colors.magenta)
		elseif ev.details.newState == Enum.HumanoidStateType.Ragdoll then
			emitParticle(colors.subtlePink)
		elseif ev.details.newState == Enum.HumanoidStateType.Jumping then
			emitParticle(colors.brown)
		elseif ev.details.newState == Enum.HumanoidStateType.PlatformStanding then
			emitParticle(colors.turquoise, 10)
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

module.Init = function()
	local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
	AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
end

_annotate("end")
return module
