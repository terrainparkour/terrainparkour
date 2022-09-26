--!strict

--eval 9.24.22

local colors = require(game.ReplicatedStorage.util.colors)

local module = {}

function setupParticleEmitter(localPlayer: Player): ParticleEmitter
	local pe: ParticleEmitter = Instance.new("ParticleEmitter")
	pe.EmissionDirection = Enum.NormalId.Back
	pe.Lifetime = NumberRange.new(1, 1)

	--initially set it to inactive
	pe.Rate = 0
	pe.Size = NumberSequence.new(0.3)
	pe.Name = "PlayerParticleEmitter"
	pe.SpreadAngle = Vector2.new(12, 12)
	pe.Parent = localPlayer.Character.Humanoid.RootPart
	return pe
end

module.EmitParticleBig = function(localplayer: Player, increase: number, color: Color3 | nil)
	if localplayer.Character == nil or localplayer.Character.Humanoid == nil then
		return
	end

	local particleEmitterBig = setupParticleEmitter(localplayer)
	if particleEmitterBig.Parent == nil then
		particleEmitterBig.Parent = localplayer.Character.Humanoid.RootPart
	end

	local particleColor: ColorSequence = ColorSequence.new(colors.redSlowDown)
	if increase > 0 then
		particleColor = ColorSequence.new(colors.greenGo)
	end
	particleEmitterBig.Color = particleColor

	particleEmitterBig.Rate = math.abs(increase) * 2900

	spawn(function()
		wait(0.7)
		particleEmitterBig.Rate = 0
	end)
end

local redParticles: ColorSequence = ColorSequence.new(colors.redSlowDown)
local greenParticles: ColorSequence = ColorSequence.new(colors.greenGo)

--momentarily set emission to show the thing that just happened to the user.
module.EmitParticle = function(localplayer: Player, increase: number, color: Color3 | nil)
	if localplayer.Character == nil or localplayer.Character.Humanoid == nil then
		return
	end

	local particleEmitterSmall = setupParticleEmitter(localplayer)

	if particleEmitterSmall.Parent == nil then
		particleEmitterSmall.Parent = localplayer.Character.Humanoid.RootPart
	end
	local useColor = redParticles
	if increase > 0 then
		useColor = greenParticles
	end

	particleEmitterSmall.Color = useColor

	local rate = math.sqrt(math.abs(increase) * 1800)

	if particleEmitterSmall.Rate ~= rate then
		particleEmitterSmall.Rate = rate
	end

	spawn(function()
		wait(0.7)
		particleEmitterSmall.Rate = 0
	end)
end

return module
